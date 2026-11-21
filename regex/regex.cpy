# regex 2.0.0 - production regex engine (PCRE2), loaded at runtime
#
# The backend is the prebuilt PCRE2 shared library, discovered with dlopen()
# on POSIX and LoadLibraryA() on Windows.  No link-time dependency is added,
# so the same source package works for both the JIT and native AOT builds.
#
# PCRE2 is compiled in UTF + UCP mode: patterns and subjects are UTF-8, and
# \d / \w / \s use Unicode properties.  `regex_match` returns 1 for a match,
# 0 for no match, and -1 for an invalid pattern/subject or a missing engine.

ccode:
    #include <stdint.h>
    #include <stddef.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #if defined(_WIN32) || defined(_WIN64)
    #define RX_ON_WINDOWS 1
    #include <windows.h>
    #else
    #define RX_ON_WINDOWS 0
    #include <dlfcn.h>
    #endif

    /* Minimal PCRE2 ABI declarations: we load the prebuilt library by name,
       so no pcre2.h include (or -lpcre2-8 link flag) is required. */
    typedef struct pcre2_real_code_8 pcre2_code;
    typedef struct pcre2_real_match_data_8 pcre2_match_data;
    typedef size_t rx_pcre2_size;
    typedef const unsigned char* rx_pcre2_sptr;

    typedef pcre2_code* (*rx_compile_fn)(rx_pcre2_sptr, rx_pcre2_size,
                                         uint32_t, int*, rx_pcre2_size*, void*);
    typedef pcre2_match_data* (*rx_create_md_fn)(const pcre2_code*, void*);
    typedef int (*rx_match_fn)(const pcre2_code*, rx_pcre2_sptr, rx_pcre2_size,
                               rx_pcre2_size, uint32_t, pcre2_match_data*, void*);
    typedef void (*rx_code_free_fn)(pcre2_code*);
    typedef void (*rx_md_free_fn)(pcre2_match_data*);

    /* PCRE2 option bits used below (from pcre2.h). */
    #define RX_PCRE2_CASELESS     0x00000008u
    #define RX_PCRE2_DOLLAR_ENDONLY 0x00000010u
    #define RX_PCRE2_DOTALL       0x00000020u
    #define RX_PCRE2_EXTENDED     0x00000080u
    #define RX_PCRE2_MULTILINE    0x00000400u
    #define RX_PCRE2_UCP          0x00020000u
    #define RX_PCRE2_UTF          0x00080000u
    #define RX_PCRE2_ENDANCHORED  0x20000000u
    #define RX_PCRE2_ANCHORED     0x80000000u
    #define RX_PCRE2_ERROR_NOMATCH (-1)

    /* cpy-level flags for regex_compile()/regex_match_flags(). */
    #define RX_FLAG_CASELESS   1
    #define RX_FLAG_MULTILINE  2
    #define RX_FLAG_DOTALL     4
    #define RX_FLAG_EXTENDED   8
    #define RX_FLAG_ANCHORED   16
    #define RX_FLAG_ENDANCHORED 32

    static void* rx_lib = NULL;
    static int rx_load_state = 0;  /* 0 = not tried, 1 = loaded, -1 = failed */
    static rx_compile_fn rx_compile = NULL;
    static rx_create_md_fn rx_create_md = NULL;
    static rx_match_fn rx_match = NULL;
    static rx_code_free_fn rx_code_free = NULL;
    static rx_md_free_fn rx_md_free = NULL;

    typedef struct {
        pcre2_code* code;
    } rx_entry;

    static rx_entry* rx_entries = NULL;
    static size_t rx_count = 0;
    static size_t rx_capacity = 0;

    static void* rx_open_library(const char* path) {
        if (!path || !*path) return NULL;
        #if RX_ON_WINDOWS
        return (void*)LoadLibraryA(path);
        #else
        return dlopen(path, RTLD_LAZY | RTLD_LOCAL);
        #endif
    }

    static void* rx_library_symbol(void* lib, const char* name) {
        if (!lib || !name) return NULL;
        #if RX_ON_WINDOWS
        FARPROC proc = GetProcAddress((HMODULE)lib, name);
        union { FARPROC proc; void* ptr; } u;
        u.proc = proc;
        return u.ptr;
        #else
        return dlsym(lib, name);
        #endif
    }

    static int rx_bind(void* dst, size_t dst_size, void* lib, const char* name) {
        void* sym = rx_library_symbol(lib, name);
        if (!sym) return 0;
        memcpy(dst, &sym, dst_size < sizeof(sym) ? dst_size : sizeof(sym));
        return 1;
    }

    static void rx_try_path(const char* path) {
        if (!rx_lib) rx_lib = rx_open_library(path);
    }

    static void rx_try_library_name(const char* name) {
        char path[1024];
        const char* dir;
        if (!name || !*name) return;
        rx_try_path(name);
        if (rx_lib) return;
        dir = getenv("CPYTE_REGEX_PCRE2_LIBDIR");
        if (dir && *dir) {
            int n = snprintf(path, sizeof(path), "%s/%s", dir, name);
            if (n > 0 && (size_t)n < sizeof(path)) rx_try_path(path);
        }
        if (rx_lib) return;
        #if !RX_ON_WINDOWS
        /* Homebrew and common Linux multiarch locations. */
        rx_try_path("/opt/homebrew/lib/libpcre2-8.dylib");
        rx_try_path("/usr/local/lib/libpcre2-8.dylib");
        rx_try_path("/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0");
        rx_try_path("/usr/lib/aarch64-linux-gnu/libpcre2-8.so.0");
        rx_try_path("/usr/lib64/libpcre2-8.so.0");
        rx_try_path("/usr/local/lib/libpcre2-8.so.0");
        #endif
    }

    static int rx_load_pcre2(void) {
        const char* exact;
        if (rx_load_state == 1) return 1;
        if (rx_load_state == -1) return 0;

        exact = getenv("CPYTE_REGEX_PCRE2_LIBRARY");
        if (exact && *exact) rx_try_path(exact);

        #if RX_ON_WINDOWS
        if (!rx_lib) rx_try_library_name("pcre2-8.dll");
        #else
        if (!rx_lib) rx_try_library_name("libpcre2-8.so.0");
        if (!rx_lib) rx_try_library_name("libpcre2-8.dylib");
        if (!rx_lib) rx_try_library_name("libpcre2-8.so");
        #endif

        if (!rx_lib) {
            rx_load_state = -1;
            return 0;
        }

        if (!rx_bind(&rx_compile, sizeof(rx_compile), rx_lib, "pcre2_compile_8") ||
            !rx_bind(&rx_create_md, sizeof(rx_create_md), rx_lib,
                     "pcre2_match_data_create_from_pattern_8") ||
            !rx_bind(&rx_match, sizeof(rx_match), rx_lib, "pcre2_match_8") ||
            !rx_bind(&rx_code_free, sizeof(rx_code_free), rx_lib, "pcre2_code_free_8") ||
            !rx_bind(&rx_md_free, sizeof(rx_md_free), rx_lib,
                     "pcre2_match_data_free_8")) {
            #if RX_ON_WINDOWS
            FreeLibrary((HMODULE)rx_lib);
            #else
            dlclose(rx_lib);
            #endif
            rx_lib = NULL;
            rx_load_state = -1;
            return 0;
        }

        rx_load_state = 1;
        return 1;
    }

    static uint32_t rx_options(int flags) {
        uint32_t opt = RX_PCRE2_UTF | RX_PCRE2_UCP | RX_PCRE2_DOLLAR_ENDONLY;
        if (flags & RX_FLAG_CASELESS) opt |= RX_PCRE2_CASELESS;
        if (flags & RX_FLAG_MULTILINE) opt |= RX_PCRE2_MULTILINE;
        if (flags & RX_FLAG_DOTALL) opt |= RX_PCRE2_DOTALL;
        if (flags & RX_FLAG_EXTENDED) opt |= RX_PCRE2_EXTENDED;
        if (flags & RX_FLAG_ANCHORED) opt |= RX_PCRE2_ANCHORED;
        if (flags & RX_FLAG_ENDANCHORED) opt |= RX_PCRE2_ENDANCHORED;
        return opt;
    }

    static pcre2_code* rx_compile_pattern(const char* pat, int flags) {
        int errcode = 0;
        rx_pcre2_size erroffset = 0;
        if (!pat || !rx_load_pcre2()) return NULL;
        return rx_compile((rx_pcre2_sptr)pat, (rx_pcre2_size)strlen(pat),
                          rx_options(flags), &errcode, &erroffset, NULL);
    }

    static int rx_exec(pcre2_code* code, const char* text) {
        pcre2_match_data* md;
        int rc;
        if (!code || !text) return -1;
        md = rx_create_md(code, NULL);
        if (!md) return -1;
        rc = rx_match(code, (rx_pcre2_sptr)text, (rx_pcre2_size)strlen(text),
                      0, 0, md, NULL);
        rx_md_free(md);
        if (rc == RX_PCRE2_ERROR_NOMATCH) return 0;
        return rc >= 0 ? 1 : -1;
    }

    static pcre2_code* rx_handle_lookup(size_t handle) {
        if (!handle || handle > rx_count) return NULL;
        return rx_entries[handle - 1].code;
    }

    const char* cpy_regex_backend_c(void) {
        return rx_load_pcre2() ? "pcre2" : "";
    }

    int64_t cpy_regex_match_flags_c(const char* pat, const char* text, int flags) {
        pcre2_code* code;
        int result;
        if (!pat || !text) return (int64_t)-1;
        code = rx_compile_pattern(pat, flags);
        if (!code) return (int64_t)-1;
        result = rx_exec(code, text);
        rx_code_free(code);
        return (int64_t)result;
    }

    int64_t cpy_regex_match_c(const char* pat, const char* text) {
        return cpy_regex_match_flags_c(pat, text, 0);
    }

    size_t cpy_regex_compile_c(const char* pat, int flags) {
        pcre2_code* code;
        if (!pat) return (size_t)0;
        if (rx_count == rx_capacity) {
            size_t new_cap = rx_capacity ? rx_capacity * 2 : 8;
            rx_entry* grown = (rx_entry*)realloc(rx_entries, new_cap * sizeof(rx_entry));
            if (!grown) return (size_t)0;
            memset(grown + rx_capacity, 0, (new_cap - rx_capacity) * sizeof(rx_entry));
            rx_entries = grown;
            rx_capacity = new_cap;
        }
        code = rx_compile_pattern(pat, flags);
        if (!code) return (size_t)0;
        rx_entries[rx_count].code = code;
        rx_count++;
        return rx_count;
    }

    int64_t cpy_regex_match_compiled_c(size_t handle, const char* text) {
        return (int64_t)rx_exec(rx_handle_lookup(handle), text);
    }

    int cpy_regex_is_compiled_c(size_t handle) {
        return rx_handle_lookup(handle) != NULL ? 1 : 0;
    }

    void cpy_regex_free_c(size_t handle) {
        pcre2_code* code = rx_handle_lookup(handle);
        if (!code) return;
        if (rx_code_free) rx_code_free(code);
        rx_entries[handle - 1].code = NULL;
    }

public def regex_backend() -> str:
    return cpy_regex_backend_c()

public def regex_match(pat str, text str) -> int:
    return (int)cpy_regex_match_c(pat, text)

public def regex_match_flags(pat str, text str, flags int) -> int:
    return (int)cpy_regex_match_flags_c(pat, text, flags)

public def regex_compile(pat str, flags int) -> size_t:
    return (size_t)cpy_regex_compile_c(pat, flags)

public def regex_match_compiled(handle size_t, text str) -> int:
    return (int)cpy_regex_match_compiled_c(handle, text)

public def regex_is_compiled(handle size_t) -> bool:
    return cpy_regex_is_compiled_c(handle) != 0

public def regex_free(handle size_t) -> void:
    cpy_regex_free_c(handle)
