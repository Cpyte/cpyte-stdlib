# ffi 1.1.0 - foreign function interface helpers

ccode:
    #include <stdint.h>
    #include <stddef.h>
    #include <stdio.h>

    #ifdef _WIN32
        #ifndef WIN32_LEAN_AND_MEAN
        #define WIN32_LEAN_AND_MEAN
        #endif
        #include <windows.h>
        static char g_ffi_err[256] = {0};
        void* cpy_ffi_open(const char* lib) {
            if (!lib || lib[0] == 0) {
                HMODULE hm = GetModuleHandleA(NULL);
                return (void*)hm;
            }
            HMODULE hm = LoadLibraryA(lib);
            if (!hm) {
                DWORD e = GetLastError();
                snprintf(g_ffi_err, sizeof(g_ffi_err), "LoadLibraryA failed: %lu", (unsigned long)e);
            } else {
                g_ffi_err[0] = 0;
            }
            return (void*)hm;
        }
        void* cpy_ffi_sym(void* h, const char* name) {
            if (!h || !name) return NULL;
            FARPROC p = GetProcAddress((HMODULE)h, name);
            if (!p) {
                DWORD e = GetLastError();
                snprintf(g_ffi_err, sizeof(g_ffi_err), "GetProcAddress failed: %lu", (unsigned long)e);
            } else {
                g_ffi_err[0] = 0;
            }
            return (void*)(intptr_t)p;
        }
        const char* cpy_ffi_err(void) {
            if (g_ffi_err[0]) return g_ffi_err;
            return "";
        }
    #else
        #include <dlfcn.h>
        void* cpy_ffi_open(const char* lib) {
            if (!lib || lib[0] == 0) return dlopen(NULL, RTLD_NOW);
            return dlopen(lib, RTLD_NOW);
        }
        void* cpy_ffi_sym(void* h, const char* name) {
            return dlsym(h, name);
        }
        const char* cpy_ffi_err(void) {
            const char* e = dlerror();
            return e ? e : "";
        }
    #endif

    typedef int64_t (*ffi_fn0)(void);
    typedef int64_t (*ffi_fn1)(int64_t);
    int64_t cpy_ffi_call0(void* fn) {
        if (!fn) return (int64_t)0;
        return ((ffi_fn0)(intptr_t)fn)();
    }
    int64_t cpy_ffi_call1(void* fn, int64_t a) {
        if (!fn) return (int64_t)0;
        return ((ffi_fn1)(intptr_t)fn)(a);
    }

public def ffi_open(lib str) -> int:
    return (int)(intptr_t)cpy_ffi_open(lib)

public def ffi_sym(handle int, name str) -> int:
    return (int)(intptr_t)cpy_ffi_sym((void*)(intptr_t)handle, name)

public def ffi_call0(fn int) -> int:
    return (int)cpy_ffi_call0((void*)(intptr_t)fn)

public def ffi_call1(fn int, a int) -> int:
    return (int)cpy_ffi_call1((void*)(intptr_t)fn, (int64)a)

public def ffi_err() -> str:
    return cpy_ffi_err()
