# Platform detection and utilities

ccode:
    #include <stdlib.h>
    #include <string.h>

    #ifdef _WIN32
        #ifndef WIN32_LEAN_AND_MEAN
        #define WIN32_LEAN_AND_MEAN
        #endif
        #include <windows.h>
    #else
        #include <sys/utsname.h>
    #endif

    const char* cpyte_g_platform(void) {
        #ifdef _WIN32
            return "win32";
        #elif defined(__APPLE__)
            return "darwin";
        #elif defined(__linux__)
            return "linux";
        #elif defined(__FreeBSD__)
            return "freebsd";
        #elif defined(__OpenBSD__)
            return "openbsd";
        #elif defined(__NetBSD__)
            return "netbsd";
        #else
            return "unknown";
        #endif
    }

    const char* cpyte_g_machine(void) {
        #ifdef _WIN32
            SYSTEM_INFO si;
            GetNativeSystemInfo(&si);
            switch (si.wProcessorArchitecture) {
                case PROCESSOR_ARCHITECTURE_AMD64: return "x86_64";
                case PROCESSOR_ARCHITECTURE_ARM64: return "aarch64";
                case PROCESSOR_ARCHITECTURE_INTEL: return "x86";
                case PROCESSOR_ARCHITECTURE_ARM: return "arm";
                default: break;
            }
            #if defined(_M_X64) || defined(__x86_64__)
                return "x86_64";
            #elif defined(_M_ARM64) || defined(__aarch64__)
                return "aarch64";
            #elif defined(_M_IX86) || defined(__i386__)
                return "x86";
            #elif defined(_M_ARM) || defined(__arm__)
                return "arm";
            #else
                return "unknown";
            #endif
        #else
            struct utsname u;
            if (uname(&u) == 0) {
                return u.machine;
            }
            #if defined(__x86_64__)
                return "x86_64";
            #elif defined(__aarch64__)
                return "aarch64";
            #elif defined(__arm__)
                return "arm";
            #else
                return "unknown";
            #endif
        #endif
    }

    const char* cpyte_g_release(void) {
        #ifdef _WIN32
            return "unknown";
        #else
            struct utsname u;
            if (uname(&u) == 0) return u.release;
            return "unknown";
        #endif
    }

    const char* cpyte_g_version(void) {
        #ifdef _WIN32
            return "unknown";
        #else
            struct utsname u;
            if (uname(&u) == 0) return u.version;
            return "unknown";
        #endif
    }

    const char* cpyte_g_node(void) {
        #ifdef _WIN32
            static char nodebuf[256];
            DWORD n = (DWORD)sizeof(nodebuf);
            if (GetComputerNameA(nodebuf, &n)) return nodebuf;
            return "unknown";
        #else
            struct utsname u;
            if (uname(&u) == 0) return u.nodename;
            return "unknown";
        #endif
    }

public def platform() -> str:
    return cpyte_g_platform()

public def system() -> str:
    return cpyte_g_platform()

public def machine() -> str:
    return cpyte_g_machine()

public def arch() -> str:
    return cpyte_g_machine()

public def os_name() -> str:
    return cpyte_g_platform()

public def processor() -> str:
    return arch()

public def python_implementation() -> str:
    return "cpyte"

public def python_version() -> str:
    return "0.0.0"

public def release() -> str:
    return cpyte_g_release()

public def version() -> str:
    return cpyte_g_version()

public def node() -> str:
    return cpyte_g_node()

public def is_windows() -> bool:
    return platform() == "win32"

public def is_macos() -> bool:
    return platform() == "darwin"

public def is_linux() -> bool:
    return platform() == "linux"

public def is_bsd() -> bool:
    s = platform()
    return s == "freebsd" or s == "openbsd" or s == "netbsd"

public def is_unix() -> bool:
    s = platform()
    return s != "win32"

public def libc_ver() -> str:
    return "unknown"

public def mac_ver() -> str:
    return "unknown"

public def win32_ver() -> str:
    return "unknown"

public def linux_distribution() -> str:
    return "unknown"
