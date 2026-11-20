# args 1.0.0 - command line argument helpers
#
# Notes (cross-platform, best-effort):
# - Linux: reads /proc/self/cmdline. macOS: uses sysctl KERN_PROCARGS2. Windows: CommandLineToArgvW.
# - In some embedded/JIT launch setups the “current process” argv may not match the logical
#   program arguments; this is a pragmatic fallback, not a guaranteed CLI-injection API.


ccode:
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>

    #ifdef _WIN32
        #ifndef WIN32_LEAN_AND_MEAN
        #define WIN32_LEAN_AND_MEAN
        #endif
        #include <windows.h>
        #include <shellapi.h>
        #if defined(_MSC_VER)
        #pragma comment(lib, "shell32.lib")
        #endif
    #else
        #include <unistd.h>
        #ifdef __APPLE__
            #include <sys/sysctl.h>
            #include <sys/types.h>
        #endif
        #include <stdio.h>
    #endif

    typedef struct {
        int count;
        char** argv;
        int owns;
    } cpy_args_state_t;

    static cpy_args_state_t g_args = {0, NULL, 0};

    static char* cpy_strdup_local(const char* s) {
        if (!s) return NULL;
        size_t n = strlen(s);
        char* d = (char*)malloc(n + 1);
        if (!d) return NULL;
        memcpy(d, s, n + 1);
        return d;
    }

    static void cpy_args_set(char** argv, int count, int owns);
    static void cpy_args_clear(void) {
        if (g_args.owns && g_args.argv != NULL) {
            int i;
            for (i = 0; i < g_args.count; i++) {
                if (g_args.argv[i]) free(g_args.argv[i]);
            }
            free(g_args.argv);
        }
        g_args.count = 0;
        g_args.argv = NULL;
        g_args.owns = 0;
    }

    static void cpy_args_set(char** argv, int count, int owns) {
        cpy_args_clear();
        g_args.count = count;
        g_args.argv = argv;
        g_args.owns = owns;
    }

    #ifdef _WIN32
    static void cpy_args_load_win32(void) {
        if (g_args.argv != NULL && g_args.count > 0) return;
        LPWSTR* wargv;
        int n = 0;
        wargv = CommandLineToArgvW(GetCommandLineW(), &n);
        if (!wargv || n <= 0) {
            cpy_args_set(NULL, 0, 1);
            if (wargv) LocalFree(wargv);
            return;
        }
        char** arr = (char**)malloc((size_t)n * sizeof(char*));
        if (!arr) {
            LocalFree(wargv);
            cpy_args_set(NULL, 0, 1);
            return;
        }
        int i;
        for (i = 0; i < n; i++) {
            int len = WideCharToMultiByte(CP_UTF8, 0, wargv[i], -1, NULL, 0, NULL, NULL);
            if (len <= 0) { arr[i] = cpy_strdup_local(""); continue; }
            arr[i] = (char*)malloc((size_t)len);
            if (!arr[i]) arr[i] = cpy_strdup_local("");
            else WideCharToMultiByte(CP_UTF8, 0, wargv[i], -1, arr[i], len, NULL, NULL);
        }
        LocalFree(wargv);
        cpy_args_set(arr, n, 1);
    }
    #endif

    #if defined(__APPLE__)
    static void cpy_args_load_macos(void) {
        if (g_args.argv != NULL && g_args.count > 0) return;
        int mib[3];
        size_t size = 0;
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = getpid();
        if (sysctl(mib, 3, NULL, &size, NULL, 0) != 0 || size == 0) {
            cpy_args_set(NULL, 0, 1);
            return;
        }
        char* procargs = (char*)malloc(size);
        if (!procargs) { cpy_args_set(NULL, 0, 1); return; }
        if (sysctl(mib, 3, procargs, &size, NULL, 0) != 0) {
            free(procargs);
            cpy_args_set(NULL, 0, 1);
            return;
        }
        if (size < (size_t)sizeof(int)) { free(procargs); cpy_args_set(NULL, 0, 1); return; }
        int argc = 0;
        memcpy(&argc, procargs, sizeof(int));
        char* ptr = procargs + sizeof(int);
        char* endp = procargs + size;
        while (ptr < endp && *ptr != '\0') ptr++;
        while (ptr < endp && *ptr == '\0') ptr++;
        if (argc <= 0) { free(procargs); cpy_args_set(NULL, 0, 1); return; }
        char** arr = (char**)malloc((size_t)argc * sizeof(char*));
        if (!arr) { free(procargs); cpy_args_set(NULL, 0, 1); return; }
        int ai = 0;
        while (ptr < endp && ai < argc) {
            char* start = ptr;
            while (ptr < endp && *ptr != '\0') ptr++;
            arr[ai++] = cpy_strdup_local(start);
            if (ptr < endp) ptr++;
        }
        free(procargs);
        cpy_args_set(arr, argc, 1);
    }
    #endif

    #if defined(__linux__) || defined(__linux) || defined(__gnu_linux__)
    static void cpy_args_load_linux(void) {
        if (g_args.argv != NULL && g_args.count > 0) return;
        FILE* f = fopen("/proc/self/cmdline", "rb");
        if (!f) { cpy_args_set(NULL, 0, 1); return; }
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        fseek(f, 0, SEEK_SET);
        if (sz <= 0) { fclose(f); cpy_args_set(NULL, 0, 1); return; }
        char* buf = (char*)malloc((size_t)sz + 1);
        if (!buf) { fclose(f); cpy_args_set(NULL, 0, 1); return; }
        size_t rd = fread(buf, 1, (size_t)sz, f);
        fclose(f);
        buf[rd] = '\0';
        int argcnt = 0;
        size_t i = 0;
        for (i = 0; i < rd; i++) {
            if (buf[i] == '\0') continue;
            argcnt++;
            while (i < rd && buf[i] != '\0') i++;
        }
        if (argcnt <= 0) { free(buf); cpy_args_set(NULL, 0, 1); return; }
        char** arr = (char**)malloc((size_t)argcnt * sizeof(char*));
        if (!arr) { free(buf); cpy_args_set(NULL, 0, 1); return; }
        int ai = 0;
        i = 0;
        while (i < rd && ai < argcnt) {
            while (i < rd && buf[i] == '\0') i++;
            if (i >= rd) break;
            char* start = buf + i;
            arr[ai++] = cpy_strdup_local(start);
            while (i < rd && buf[i] != '\0') i++;
        }
        free(buf);
        cpy_args_set(arr, argcnt, 1);
    }
    #endif

    static void cpy_args_ensure_loaded(void) {
        if (g_args.argv != NULL) return;
        #ifdef _WIN32
            cpy_args_load_win32();
        #elif defined(__APPLE__)
            cpy_args_load_macos();
        #elif defined(__linux__) || defined(__linux) || defined(__gnu_linux__)
            cpy_args_load_linux();
        #else
            cpy_args_set(NULL, 0, 1);
        #endif
    }

    int64_t cpy_args_count(void) {
        cpy_args_ensure_loaded();
        return (int64_t)g_args.count;
    }

    const char* cpy_args_get(int64_t i) {
        cpy_args_ensure_loaded();
        if (i < 0 || i >= g_args.count) return "";
        if (g_args.argv == NULL) return "";
        return g_args.argv[(int)i] ? g_args.argv[(int)i] : "";
    }

    const char* cpy_args_program(void) {
        cpy_args_ensure_loaded();
        if (g_args.count <= 0 || g_args.argv == NULL) return "";
        return g_args.argv[0] ? g_args.argv[0] : "";
    }

public def args_count() -> int:
    return (int)cpy_args_count()

public def args_get(i int) -> str:
    return cpy_args_get((int64)i)

public def args_program() -> str:
    return cpy_args_program()
