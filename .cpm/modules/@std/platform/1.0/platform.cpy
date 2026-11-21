# Platform detection and utilities

import "stdio"
import "string"

ccode:
    #include <sys/utsname.h>
    #include <stdlib.h>
    
    const char* cpyte_get_platform() {
        #ifdef _WIN32
            return "win32";
        #elif __APPLE__
            return "darwin";
        #elif __linux__
            return "linux";
        #elif __FreeBSD__
            return "freebsd";
        #elif __OpenBSD__
            return "openbsd";
        #elif __NetBSD__
            return "netbsd";
        #else
            return "unknown";
        #endif
    }
    
    const char* cpyte_get_machine() {
        struct utsname u;
        if (uname(&u) == 0) {
            return u.machine;
        }
        #ifdef __x86_64__
            return "x86_64";
        #elif __aarch64__
            return "aarch64";
        #elif __arm__
            return "arm";
        #else
            return "unknown";
        #endif
    }
    
    const char* cpyte_get_release() {
        struct utsname u;
        if (uname(&u) == 0) {
            return u.release;
        }
        return "unknown";
    }
    
    const char* cpyte_get_version() {
        struct utsname u;
        if (uname(&u) == 0) {
            return u.version;
        }
        return "unknown";
    }
    
    const char* cpyte_get_node() {
        struct utsname u;
        if (uname(&u) == 0) {
            return u.nodename;
        }
        return "unknown";
    }
    
    extern const char* cpyte_get_platform(void);
    extern const char* cpyte_get_machine(void);
    extern const char* cpyte_get_release(void);
    extern const char* cpyte_get_version(void);
    extern const char* cpyte_get_node(void);

public def platform() -> str:
    return cpyte_get_platform()

public def system() -> str:
    return cpyte_get_platform()

public def machine() -> str:
    return cpyte_get_machine()

public def arch() -> str:
    return cpyte_get_machine()

public def os_name() -> str:
    return cpyte_get_platform()

public def processor() -> str:
    return arch()

public def python_implementation() -> str:
    return "cpyte"

public def python_version() -> str:
    return "0.0.0"

public def release() -> str:
    return cpyte_get_release()

public def version() -> str:
    return cpyte_get_version()

public def node() -> str:
    return cpyte_get_node()

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
