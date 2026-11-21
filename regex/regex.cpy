# regex 2.1.0 - production regex engine (PCRE2), loaded at runtime
#
# The backend is the prebuilt PCRE2 shared library, discovered with dlopen()
# on POSIX and LoadLibraryA() on Windows. No link-time dependency is added,
# so the same source package works for both the JIT and native AOT builds.
#
# PCRE2 is compiled in UTF + UCP mode: patterns and subjects are UTF-8, and
# \d / \w / \s use Unicode properties.

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
    typedef rx_pcre2_size* (*rx_get_ovector_fn)(pcre2_match_data*);
    typedef int (*rx_pattern_info_fn)(const pcre2_code*, uint32_t, void*);
    typedef int (*rx_get_error_message_fn)(int, unsigned char*, rx_pcre2_size);
    typedef int (*rx_config_fn)(uint32_t, void*);
    typedef int (*rx_name_number_fn)(const pcre2_code*, rx_pcre2_sptr);

    /* PCRE2 constants used below (from pcre2.h). */
    #define RX_PCRE2_CASELESS       0x00000008u
    #define RX_PCRE2_DOLLAR_ENDONLY 0x00000010u
    #define RX_PCRE2_DOTALL         0x00000020u
    #define RX_PCRE2_EXTENDED       0x00000080u
    #define RX_PCRE2_MULTILINE      0x00000400u
    #define RX_PCRE2_UCP            0x00020000u
    #define RX_PCRE2_UTF            0x00080000u
    #define RX_PCRE2_ENDANCHORED    0x20000000u
    #define RX_PCRE2_ANCHORED       0x80000000u
    #define RX_PCRE2_ERROR_NOMATCH  (-1)
    #define RX_PCRE2_INFO_CAPTURECOUNT 4
    #define RX_PCRE2_INFO_NAMECOUNT 17
    #define RX_PCRE2_INFO_NAMEENTRYSIZE 18
    #define RX_PCRE2_INFO_NAMETABLE 19
    #define RX_PCRE2_CONFIG_VERSION 11
    #define RX_PCRE2_UNSET ((rx_pcre2_size)-1)

    /* cpy-level flags. */
    #define RX_FLAG_CASELESS    1
    #define RX_FLAG_MULTILINE   2
    #define RX_FLAG_DOTALL      4
    #define RX_FLAG_EXTENDED    8
    #define RX_FLAG_ANCHORED    16
    #define RX_FLAG_ENDANCHORED 32

    static void* rx_lib = NULL;
    static int rx_load_state = 0;
    static rx_compile_fn rx_compile = NULL;
    static rx_create_md_fn rx_create_md = NULL;
    static rx_match_fn rx_match = NULL;
    static rx_code_free_fn rx_code_free = NULL;
    static rx_md_free_fn rx_md_free = NULL;
    static rx_get_ovector_fn rx_get_ovector = NULL;
    static rx_pattern_info_fn rx_pattern_info = NULL;
    static rx_get_error_message_fn rx_get_error_message = NULL;
    static rx_config_fn rx_config = NULL;
    static rx_name_number_fn rx_name_number = NULL;

    static int rx_last_code = 0;
    static int64_t rx_last_offset = -1;
    static char rx_last_message[256] = "";

    typedef struct {
        pcre2_code* code;
        int capture_count;
        int named_count;
        char* pattern;
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
        int ok = 1;
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

        ok &= rx_bind(&rx_compile, sizeof(rx_compile), rx_lib, "pcre2_compile_8");
        ok &= rx_bind(&rx_create_md, sizeof(rx_create_md), rx_lib,
                      "pcre2_match_data_create_from_pattern_8");
        ok &= rx_bind(&rx_match, sizeof(rx_match), rx_lib, "pcre2_match_8");
        ok &= rx_bind(&rx_code_free, sizeof(rx_code_free), rx_lib, "pcre2_code_free_8");
        ok &= rx_bind(&rx_md_free, sizeof(rx_md_free), rx_lib, "pcre2_match_data_free_8");
        ok &= rx_bind(&rx_get_ovector, sizeof(rx_get_ovector), rx_lib,
                      "pcre2_get_ovector_pointer_8");
        ok &= rx_bind(&rx_pattern_info, sizeof(rx_pattern_info), rx_lib,
                      "pcre2_pattern_info_8");
        ok &= rx_bind(&rx_get_error_message, sizeof(rx_get_error_message), rx_lib,
                      "pcre2_get_error_message_8");
        ok &= rx_bind(&rx_config, sizeof(rx_config), rx_lib, "pcre2_config_8");
        ok &= rx_bind(&rx_name_number, sizeof(rx_name_number), rx_lib,
                      "pcre2_substring_number_from_name_8");

        if (!ok) {
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

    static void rx_clear_error(void) {
        rx_last_code = 0;
        rx_last_offset = -1;
        rx_last_message[0] = 0;
    }

    static void rx_set_error(int code, rx_pcre2_size offset) {
        unsigned char buf[256];
        rx_last_code = code;
        rx_last_offset = (int64_t)offset;
        buf[0] = 0;
        if (rx_get_error_message && code != RX_PCRE2_ERROR_NOMATCH) {
            rx_get_error_message(code, buf, (rx_pcre2_size)sizeof(buf));
        }
        if (buf[0]) {
            size_t n = strlen((const char*)buf);
            if (n >= sizeof(rx_last_message)) n = sizeof(rx_last_message) - 1;
            memcpy(rx_last_message, buf, n);
            rx_last_message[n] = 0;
        } else if (code == RX_PCRE2_ERROR_NOMATCH) {
            strcpy(rx_last_message, "no match");
        } else {
            snprintf(rx_last_message, sizeof(rx_last_message), "PCRE2 error %d", code);
        }
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
        pcre2_code* code;
        rx_clear_error();
        if (!pat) {
            rx_set_error(-100, 0);
            return NULL;
        }
        if (!rx_load_pcre2()) {
            rx_set_error(-101, 0);
            return NULL;
        }
        code = rx_compile((rx_pcre2_sptr)pat, (rx_pcre2_size)strlen(pat),
                          rx_options(flags), &errcode, &erroffset, NULL);
        if (!code) rx_set_error(errcode, erroffset);
        return code;
    }

    static rx_entry* rx_handle_lookup(size_t handle) {
        if (!handle || handle > rx_count) return NULL;
        return rx_entries[handle - 1].code ? &rx_entries[handle - 1] : NULL;
    }

    static int rx_info_int(pcre2_code* code, uint32_t what) {
        int value = 0;
        if (!code || !rx_pattern_info) return 0;
        rx_pattern_info(code, what, &value);
        return value;
    }

    static size_t rx_clamp_start(const char* text, int64_t start) {
        size_t tlen = strlen(text);
        if (start <= 0) return 0;
        if ((uint64_t)start > (uint64_t)tlen) return tlen;
        return (size_t)start;
    }

    /* Returns 1 on match, 0 on no match, -1 on error. Caller frees *out_md. */
    static int rx_exec_match(size_t handle, const char* text, int64_t start,
                             int64_t* out_start, int64_t* out_end,
                             rx_pcre2_size** out_ovector,
                             pcre2_match_data** out_md) {
        rx_entry* ent = rx_handle_lookup(handle);
        pcre2_match_data* md;
        rx_pcre2_size* ov;
        int rc;
        if (!ent || !text) return -1;
        md = rx_create_md(ent->code, NULL);
        if (!md) {
            rx_set_error(-102, 0);
            return -1;
        }
        rc = rx_match(ent->code, (rx_pcre2_sptr)text,
                      (rx_pcre2_size)strlen(text), rx_clamp_start(text, start),
                      0, md, NULL);
        if (rc == RX_PCRE2_ERROR_NOMATCH) {
            rx_md_free(md);
            return 0;
        }
        if (rc < 0) {
            rx_set_error(rc, 0);
            rx_md_free(md);
            return -1;
        }
        ov = rx_get_ovector(md);
        if (out_start) *out_start = (int64_t)ov[0];
        if (out_end) *out_end = (int64_t)ov[1];
        if (out_ovector) *out_ovector = ov;
        if (out_md) *out_md = md;
        else rx_md_free(md);
        return 1;
    }

    static int rx_group_span(const rx_entry* ent, rx_pcre2_size* ov, int group,
                             int64_t* out_start, int64_t* out_end) {
        if (!ent || !ov || group < 0 || group > ent->capture_count) return 0;
        if (ov[2 * (size_t)group] == RX_PCRE2_UNSET ||
            ov[2 * (size_t)group + 1] == RX_PCRE2_UNSET) return 0;
        *out_start = (int64_t)ov[2 * (size_t)group];
        *out_end = (int64_t)ov[2 * (size_t)group + 1];
        return 1;
    }

    static size_t rx_next_utf8(const char* text, size_t tlen, size_t pos) {
        unsigned char c;
        size_t n;
        if (pos >= tlen) return tlen;
        c = (unsigned char)text[pos];
        if (c < 0x80) n = 1;
        else if ((c & 0xE0) == 0xC0) n = 2;
        else if ((c & 0xF0) == 0xE0) n = 3;
        else if ((c & 0xF8) == 0xF0) n = 4;
        else n = 1;
        if (n > tlen - pos) n = 1;
        return pos + n;
    }

    static const char* rx_group_name(pcre2_code* code, int group, int named_count) {
        uint32_t entry_size = 0;
        const unsigned char* table = NULL;
        int count = 0;
        int i;
        if (!code || group <= 0 || named_count <= 0) return "";
        rx_pattern_info(code, RX_PCRE2_INFO_NAMECOUNT, &count);
        rx_pattern_info(code, RX_PCRE2_INFO_NAMEENTRYSIZE, &entry_size);
        rx_pattern_info(code, RX_PCRE2_INFO_NAMETABLE, &table);
        if (!table || count <= 0 || entry_size < 3) return "";
        for (i = 0; i < count; i++) {
            const unsigned char* e = table + (size_t)i * entry_size;
            int num = (e[0] << 8) | e[1];
            if (num == group) return (const char*)(e + 2);
        }
        return "";
    }

    /* ---------- replacement expansion ---------- */

    typedef struct {
        char* dst;
        size_t remaining;
        size_t total;
    } rx_sink;

    static void rx_sink_write(rx_sink* sink, const char* src, size_t n) {
        sink->total += n;
        if (sink->dst && sink->remaining) {
            size_t take = n < sink->remaining ? n : sink->remaining;
            memcpy(sink->dst, src, take);
            sink->dst += take;
            sink->remaining -= take;
        }
    }

    static void rx_sink_char(rx_sink* sink, char c) {
        rx_sink_write(sink, &c, 1);
    }

    static void rx_append_group(rx_sink* sink, const char* text,
                                rx_pcre2_size* ov, const rx_entry* ent, int group) {
        int64_t s = 0, e = 0;
        if (!rx_group_span(ent, ov, group, &s, &e)) return;
        rx_sink_write(sink, text + (size_t)s, (size_t)(e - s));
    }

    static void rx_append_expansion(rx_sink* sink, const char* rep,
                                    const char* text, rx_pcre2_size* ov,
                                    const rx_entry* ent) {
        size_t i = 0, n = strlen(rep);
        while (i < n) {
            if (rep[i] != '$') {
                rx_sink_char(sink, rep[i++]);
                continue;
            }
            if (i + 1 >= n) {
                rx_sink_char(sink, '$');
                i++;
                continue;
            }
            if (rep[i + 1] == '$') {
                rx_sink_char(sink, '$');
                i += 2;
                continue;
            }
            if (rep[i + 1] == '{') {
                size_t close = i + 2;
                while (close < n && rep[close] != '}') close++;
                if (close < n) {
                    char name[128];
                    size_t len = close - (i + 2);
                    int group;
                    if (len >= sizeof(name)) len = sizeof(name) - 1;
                    memcpy(name, rep + i + 2, len);
                    name[len] = 0;
                    group = rx_name_number ? rx_name_number(ent->code,
                                            (rx_pcre2_sptr)name) : -1;
                    if (group > 0) {
                        rx_append_group(sink, text, ov, ent, group);
                    } else {
                        rx_sink_write(sink, rep + i, close - i + 1);
                    }
                    i = close + 1;
                    continue;
                }
            }
            if (rep[i + 1] >= '0' && rep[i + 1] <= '9') {
                int group = rep[i + 1] - '0';
                i += 2;
                if (i < n && rep[i] >= '0' && rep[i] <= '9' &&
                    group * 10 + (rep[i] - '0') <= ent->capture_count) {
                    group = group * 10 + (rep[i] - '0');
                    i++;
                }
                rx_append_group(sink, text, ov, ent, group);
                continue;
            }
            rx_sink_char(sink, '$');
            i++;
        }
    }

    /* dst may be NULL: then this only computes the output length. */
    static int64_t rx_build_replacement(size_t handle, const char* text,
                                        const char* replacement, int64_t start,
                                        int all, char* dst, size_t cap) {
        rx_entry* ent = rx_handle_lookup(handle);
        rx_sink sink;
        size_t tlen, pos;
        if (!ent || !text || !replacement) return -1;
        tlen = strlen(text);
        pos = rx_clamp_start(text, start);
        sink.dst = dst;
        sink.remaining = dst ? cap : 0;
        sink.total = 0;
        /* Copy the untouched prefix before `start`. */
        if (pos > 0) rx_sink_write(&sink, text, pos);

        for (;;) {
            int64_t ms = 0, me = 0;
            rx_pcre2_size* ov = NULL;
            pcre2_match_data* md = NULL;
            int rc = rx_exec_match(handle, text, (int64_t)pos, &ms, &me, &ov, &md);
            if (rc <= 0) {
                rx_sink_write(&sink, text + pos, tlen - pos);
                break;
            }
            if ((uint64_t)ms > (uint64_t)tlen || (uint64_t)me > (uint64_t)tlen ||
                (uint64_t)ms < (uint64_t)pos || me < ms) {
                rx_md_free(md);
                rx_sink_write(&sink, text + pos, tlen - pos);
                break;
            }
            if (pos < (size_t)ms) rx_sink_write(&sink, text + pos, (size_t)ms - pos);
            rx_append_expansion(&sink, replacement, text, ov, ent);
            rx_md_free(md);
            if (!all) {
                pos = (size_t)me;
                rx_sink_write(&sink, text + pos, tlen - pos);
                break;
            }
            if (me == ms) {
                size_t next = rx_next_utf8(text, tlen, (size_t)me);
                if (next <= (size_t)me) {
                    rx_sink_write(&sink, text + pos, tlen - pos);
                    break;
                }
                pos = next;
            } else {
                pos = (size_t)me;
            }
            if (pos > tlen) pos = tlen;
        }
        if (dst) dst[sink.total] = 0;
        return (int64_t)sink.total;
    }

    /* ---------- public C wrappers ---------- */

    const char* cpy_regex_backend_c(void) {
        return rx_load_pcre2() ? "pcre2" : "";
    }

    const char* cpy_regex_version_c(void) {
        static char buf[64];
        if (!rx_load_pcre2()) return "";
        buf[0] = 0;
        if (rx_config) rx_config(RX_PCRE2_CONFIG_VERSION, buf);
        return buf[0] ? buf : "unknown";
    }

    const char* cpy_regex_last_error_c(void) {
        return rx_last_message;
    }

    int cpy_regex_error_code_c(void) {
        return rx_last_code;
    }

    int64_t cpy_regex_error_offset_c(void) {
        return rx_last_offset;
    }

    int64_t cpy_regex_text_len_c(const char* text) {
        return text ? (int64_t)strlen(text) : (int64_t)-1;
    }

    int64_t cpy_regex_next_utf8_c(const char* text, int64_t pos) {
        size_t tlen, p;
        if (!text) return pos;
        tlen = strlen(text);
        if (pos < 0) return 0;
        if ((uint64_t)pos >= (uint64_t)tlen) return (int64_t)tlen;
        p = rx_next_utf8(text, tlen, (size_t)pos);
        if (p <= (size_t)pos) p = (size_t)pos + 1;
        return (int64_t)p;
    }

    void cpy_regex_copy_slice_c(const char* text, int64_t start, int64_t end, void* dst) {
        char* out = (char*)dst;
        int64_t n;
        if (!text || !out) return;
        if (start < 0) start = 0;
        if (end > (int64_t)strlen(text)) end = (int64_t)strlen(text);
        if (end <= start) {
            out[0] = 0;
            return;
        }
        n = end - start;
        memcpy(out, text + (size_t)start, (size_t)n);
        out[n] = 0;
    }

    int64_t cpy_regex_match_flags_c(const char* pat, const char* text, int flags) {
        pcre2_code* code;
        pcre2_match_data* md;
        int64_t result = (int64_t)-1;
        int rc;
        if (!text) {
            rx_clear_error();
            rx_set_error(-100, 0);
            return (int64_t)-1;
        }
        code = rx_compile_pattern(pat, flags);
        if (!code) return (int64_t)-1;
        md = rx_create_md(code, NULL);
        if (!md) {
            rx_set_error(-102, 0);
            rx_code_free(code);
            return (int64_t)-1;
        }
        rc = rx_match(code, (rx_pcre2_sptr)text,
                      (rx_pcre2_size)strlen(text), 0, 0, md, NULL);
        if (rc == RX_PCRE2_ERROR_NOMATCH) result = 0;
        else if (rc < 0) { rx_set_error(rc, 0); result = -1; }
        else result = 1;
        rx_md_free(md);
        rx_code_free(code);
        return result;
    }

    int64_t cpy_regex_match_c(const char* pat, const char* text) {
        return cpy_regex_match_flags_c(pat, text, 0);
    }

    size_t cpy_regex_compile_c(const char* pat, int flags) {
        pcre2_code* code;
        char* copy = NULL;
        size_t n;
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
        n = strlen(pat);
        copy = (char*)malloc(n + 1);
        if (!copy) {
            rx_code_free(code);
            return (size_t)0;
        }
        memcpy(copy, pat, n + 1);
        rx_entries[rx_count].code = code;
        rx_entries[rx_count].capture_count = rx_info_int(code, RX_PCRE2_INFO_CAPTURECOUNT);
        rx_entries[rx_count].named_count = rx_info_int(code, RX_PCRE2_INFO_NAMECOUNT);
        rx_entries[rx_count].pattern = copy;
        rx_count++;
        return rx_count;
    }

    int cpy_regex_is_compiled_c(size_t handle) {
        return rx_handle_lookup(handle) != NULL ? 1 : 0;
    }

    const char* cpy_regex_pattern_c(size_t handle) {
        rx_entry* ent = rx_handle_lookup(handle);
        return ent && ent->pattern ? ent->pattern : "";
    }

    int cpy_regex_capture_count_c(size_t handle) {
        rx_entry* ent = rx_handle_lookup(handle);
        return ent ? ent->capture_count : 0;
    }

    int cpy_regex_named_count_c(size_t handle) {
        rx_entry* ent = rx_handle_lookup(handle);
        return ent ? ent->named_count : 0;
    }

    const char* cpy_regex_group_name_c(size_t handle, int group) {
        rx_entry* ent = rx_handle_lookup(handle);
        if (!ent) return "";
        return rx_group_name(ent->code, group, ent->named_count);
    }

    int cpy_regex_group_index_c(size_t handle, const char* name) {
        rx_entry* ent = rx_handle_lookup(handle);
        if (!ent || !name || !rx_name_number) return -1;
        return rx_name_number(ent->code, (rx_pcre2_sptr)name);
    }

    void cpy_regex_free_c(size_t handle) {
        rx_entry* ent = rx_handle_lookup(handle);
        if (!ent) return;
        if (ent->code && rx_code_free) rx_code_free(ent->code);
        free(ent->pattern);
        ent->code = NULL;
        ent->pattern = NULL;
        ent->capture_count = 0;
        ent->named_count = 0;
    }

    int cpy_regex_find_span_c(size_t handle, const char* text, int64_t start,
                              int64_t* out_start, int64_t* out_end) {
        return rx_exec_match(handle, text, start, out_start, out_end, NULL, NULL);
    }

    int cpy_regex_group_span_c(size_t handle, const char* text, int64_t start,
                               int group, int64_t* out_start, int64_t* out_end) {
        rx_pcre2_size* ov = NULL;
        pcre2_match_data* md = NULL;
        rx_entry* ent = rx_handle_lookup(handle);
        int result;
        if (!ent || !out_start || !out_end) return -1;
        result = rx_exec_match(handle, text, start, NULL, NULL, &ov, &md);
        if (result != 1) return result;
        result = rx_group_span(ent, ov, group, out_start, out_end) ? 1 : 0;
        rx_md_free(md);
        return result;
    }

    int64_t cpy_regex_count_c(size_t handle, const char* text, int64_t start) {
        rx_entry* ent = rx_handle_lookup(handle);
        size_t tlen, pos;
        int64_t count = 0;
        if (!ent || !text) return -1;
        tlen = strlen(text);
        pos = rx_clamp_start(text, start);
        for (;;) {
            int64_t ms = 0, me = 0;
            pcre2_match_data* md = NULL;
            int rc = rx_exec_match(handle, text, (int64_t)pos, &ms, &me, NULL, &md);
            if (rc <= 0) break;
            rx_md_free(md);
            count++;
            if (me == ms) {
                size_t next = rx_next_utf8(text, tlen, (size_t)me);
                if (next <= (size_t)me) break;
                pos = next;
            } else {
                pos = (size_t)me;
            }
            if (pos > tlen) pos = tlen;
        }
        return count;
    }

    int64_t cpy_regex_replace_len_c(size_t handle, const char* text,
                                    const char* replacement, int64_t start, int all) {
        return rx_build_replacement(handle, text, replacement, start, all, NULL, 0);
    }

    void cpy_regex_replace_into_c(size_t handle, const char* text,
                                  const char* replacement, int64_t start, int all,
                                  void* dst, int64_t cap) {
        if (!dst || cap <= 0) return;
        rx_build_replacement(handle, text, replacement, start, all,
                             (char*)dst, (size_t)cap);
    }

    int64_t cpy_regex_escape_len_c(const char* s) {
        static const char* meta = "\\.^$|?*+()[]{}";
        int64_t n = 0;
        if (!s) return 0;
        while (*s) {
            if (strchr(meta, *s)) n++;
            n++;
            s++;
        }
        return n;
    }

    void cpy_regex_escape_into_c(const char* s, void* dst) {
        static const char* meta = "\\.^$|?*+()[]{}";
        char* out = (char*)dst;
        if (!s || !out) return;
        while (*s) {
            if (strchr(meta, *s)) *out++ = '\\';
            *out++ = *s++;
        }
        *out = 0;
    }

# ── engine information ────────────────────────────────────────────

public def regex_backend() -> str:
    return cpy_regex_backend_c()

public def regex_version() -> str:
    return cpy_regex_version_c()

public def regex_last_error() -> str:
    return cpy_regex_last_error_c()

public def regex_error_code() -> int:
    return cpy_regex_error_code_c()

public def regex_error_offset() -> int64:
    return cpy_regex_error_offset_c()

public def regex_len(text str) -> int64:
    return cpy_regex_text_len_c(text)

public def regex_next(text str, pos int64) -> int64:
    return cpy_regex_next_utf8_c(text, pos)

# ── compile / pattern objects ─────────────────────────────────────

public def regex_compile(pat str, flags int) -> size_t:
    return (size_t)cpy_regex_compile_c(pat, flags)

public def regex_is_compiled(handle size_t) -> bool:
    return cpy_regex_is_compiled_c(handle) != 0

public def regex_pattern(handle size_t) -> str:
    return cpy_regex_pattern_c(handle)

public def regex_capture_count(handle size_t) -> int:
    return cpy_regex_capture_count_c(handle)

public def regex_named_count(handle size_t) -> int:
    return cpy_regex_named_count_c(handle)

public def regex_group_name(handle size_t, group int) -> str:
    return cpy_regex_group_name_c(handle, group)

public def regex_group_index(handle size_t, name str) -> int:
    return cpy_regex_group_index_c(handle, name)

public def regex_free(handle size_t) -> void:
    cpy_regex_free_c(handle)

public def regex_valid(pat str, flags int) -> bool:
    size_t h = regex_compile(pat, flags)
    if h == (size_t)0:
        return false
    regex_free(h)
    return true

# ── one-shot and boolean matching ─────────────────────────────────

public def regex_match(pat str, text str) -> int:
    return (int)cpy_regex_match_c(pat, text)

public def regex_match_flags(pat str, text str, flags int) -> int:
    return (int)cpy_regex_match_flags_c(pat, text, flags)

public def regex_search(pat str, text str, flags int) -> int:
    return regex_match_flags(pat, text, flags)

public def regex_fullmatch(pat str, text str, flags int) -> int:
    return regex_match_flags(pat, text, flags | 16 | 32)

public def regex_is_match(pat str, text str) -> bool:
    return regex_match(pat, text) == 1

# ── spans, captures, search ───────────────────────────────────────

public def regex_find_span(handle size_t, text str, start int64) -> int64[]:
    int64 s = 0
    int64 e = 0
    int rc = cpy_regex_find_span_c(handle, text, start, &s, &e)
    if rc != 1:
        return new int64[0]
    int64[] out = new int64[2]
    out[0] = s
    out[1] = e
    return out

public def regex_group_span(handle size_t, text str, group int, start int64) -> int64[]:
    int64 s = 0
    int64 e = 0
    int rc = cpy_regex_group_span_c(handle, text, start, group, &s, &e)
    if rc != 1:
        return new int64[0]
    int64[] out = new int64[2]
    out[0] = s
    out[1] = e
    return out

public def regex_find(handle size_t, text str, start int64) -> int64:
    int64[] span = regex_find_span(handle, text, start)
    if len(span) == (int64)0:
        return (int64)-1
    return span[0]

public def regex_match_compiled(handle size_t, text str) -> int:
    int64[] span = regex_find_span(handle, text, (int64)0)
    if len(span) == (int64)0:
        return 0
    return 1

public def regex_test(handle size_t, text str) -> bool:
    return regex_match_compiled(handle, text) == 1

public def regex_named_span(handle size_t, text str, name str, start int64) -> int64[]:
    int group = regex_group_index(handle, name)
    if group < 0:
        return new int64[0]
    return regex_group_span(handle, text, group, start)

public def regex_group_matched(handle size_t, text str, group int, start int64) -> bool:
    return len(regex_group_span(handle, text, group, start)) > 0

public def regex_substr(text str, start int64, end int64) -> str:
    int64 n = regex_len(text)
    if start < (int64)0:
        start = (int64)0
    if end > n:
        end = n
    if end <= start:
        return ""
    char[] buf = new char[end - start + (int64)1]
    cpy_regex_copy_slice_c(text, start, end, (void*)buf)
    return (str)buf

public def regex_group_text(handle size_t, text str, group int, start int64) -> str:
    int64[] span = regex_group_span(handle, text, group, start)
    if len(span) == (int64)0:
        return ""
    return regex_substr(text, span[0], span[1])

public def regex_named_text(handle size_t, text str, name str, start int64) -> str:
    int group = regex_group_index(handle, name)
    if group < 0:
        return ""
    return regex_group_text(handle, text, group, start)

public def regex_match_spans(handle size_t, text str, start int64) -> int64[]:
    int64[] out = new int64[0]
    int count = regex_capture_count(handle)
    int i = 0
    while i <= count:
        int64[] span = regex_group_span(handle, text, i, start)
        if len(span) == (int64)0:
            append(out, (int64)-1)
            append(out, (int64)-1)
        else:
            append(out, span[0])
            append(out, span[1])
        i += 1
    return out

public def regex_captures(handle size_t, text str, start int64) -> str[]:
    str[] out = new str[0]
    int count = regex_capture_count(handle)
    int i = 1
    while i <= count:
        append(out, regex_group_text(handle, text, i, start))
        i += 1
    return out

public def regex_count(handle size_t, text str, start int64) -> int64:
    return cpy_regex_count_c(handle, text, start)

public def regex_find_all(handle size_t, text str, start int64) -> int64[]:
    int64[] out = new int64[0]
    int64 tlen = regex_len(text)
    int64 pos = start
    if pos < (int64)0:
        pos = (int64)0
    while pos <= tlen:
        int64[] span = regex_find_span(handle, text, pos)
        if len(span) == (int64)0:
            break
        append(out, span[0])
        append(out, span[1])
        if span[1] == span[0]:
            pos = regex_next(text, span[0])
        else:
            pos = span[1]
        if pos <= span[0] or pos > tlen:
            break
    return out

public def regex_find_all_strings(handle size_t, text str, start int64) -> str[]:
    str[] out = new str[0]
    int64[] spans = regex_find_all(handle, text, start)
    int64 i = 0
    while i + (int64)1 < len(spans):
        append(out, regex_substr(text, spans[i], spans[i + 1]))
        i += (int64)2
    return out

# ── split / replace / quote ───────────────────────────────────────

public def regex_split(handle size_t, text str, start int64) -> str[]:
    str[] parts = new str[0]
    int64 tlen = regex_len(text)
    int64 pos = start
    if pos < (int64)0:
        pos = (int64)0
    if pos > tlen:
        pos = tlen
    while pos < tlen:
        int64[] span = regex_find_span(handle, text, pos)
        if len(span) == (int64)0:
            break
        append(parts, regex_substr(text, pos, span[0]))
        if span[1] == span[0]:
            pos = regex_next(text, span[0])
        else:
            pos = span[1]
        if pos <= span[0] or pos > tlen:
            break
    append(parts, regex_substr(text, pos, tlen))
    return parts

public def regex_replace_ex(handle size_t, text str, replacement str, start int64, replace_all bool) -> str:
    int flag = 0
    if replace_all:
        flag = 1
    int64 n = cpy_regex_replace_len_c(handle, text, replacement, start, flag)
    if n < (int64)0:
        return ""
    char[] buf = new char[n + (int64)1]
    cpy_regex_replace_into_c(handle, text, replacement, start, flag, (void*)buf, n + (int64)1)
    return (str)buf

public def regex_replace(handle size_t, text str, replacement str, start int64) -> str:
    return regex_replace_ex(handle, text, replacement, start, false)

public def regex_replace_all(handle size_t, text str, replacement str, start int64) -> str:
    return regex_replace_ex(handle, text, replacement, start, true)

public def regex_quote(s str) -> str:
    int64 n = cpy_regex_escape_len_c(s)
    char[] buf = new char[n + (int64)1]
    cpy_regex_escape_into_c(s, (void*)buf)
    return (str)buf

public def regex_escape(s str) -> str:
    return regex_quote(s)

# ── one-shot convenience wrappers ─────────────────────────────────

public def regex_replace_text(pat str, text str, replacement str, flags int, replace_all bool) -> str:
    size_t h = regex_compile(pat, flags)
    if h == (size_t)0:
        return text
    str result = regex_replace_ex(h, text, replacement, (int64)0, replace_all)
    regex_free(h)
    return result

public def regex_split_text(pat str, text str, flags int, start int64) -> str[]:
    size_t h = regex_compile(pat, flags)
    if h == (size_t)0:
        str[] one = new str[0]
        append(one, text)
        return one
    str[] parts = regex_split(h, text, start)
    regex_free(h)
    return parts

public def regex_find_all_text(pat str, text str, flags int, start int64) -> int64[]:
    size_t h = regex_compile(pat, flags)
    if h == (size_t)0:
        return new int64[0]
    int64[] spans = regex_find_all(h, text, start)
    regex_free(h)
    return spans
