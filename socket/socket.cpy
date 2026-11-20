# socket 1.0.0 - cross-platform socket helpers

ccode:
    #include <stdint.h>
    #include <string.h>

    #ifdef _WIN32
        #ifndef WIN32_LEAN_AND_MEAN
        #define WIN32_LEAN_AND_MEAN
        #endif
        #include <winsock2.h>
        #include <ws2tcpip.h>
        typedef SOCKET cpy_sock_fd_t;
        #define CPY_SOCK_BAD INVALID_SOCKET
        static int cpy_sock_wsa_inited = 0;
        static void cpy_sock_ensure_wsa(void) {
            if (!cpy_sock_wsa_inited) {
                WSADATA wsa;
                if (WSAStartup(MAKEWORD(2,2), &wsa) == 0) cpy_sock_wsa_inited = 1;
            }
        }
        static int64_t cpy_sock_errret(void) { return (int64_t)-1; }
    #else
        #include <sys/types.h>
        #include <sys/socket.h>
        #include <netinet/in.h>
        #include <arpa/inet.h>
        #include <unistd.h>
        typedef int cpy_sock_fd_t;
        #define CPY_SOCK_BAD (-1)
        static void cpy_sock_ensure_wsa(void) {}
        static int64_t cpy_sock_errret(void) { return (int64_t)-1; }
    #endif

    int64_t cpy_sock_tcp(void) {
        cpy_sock_ensure_wsa();
        cpy_sock_fd_t fd = socket(AF_INET, SOCK_STREAM, 0);
        #ifdef _WIN32
            if (fd == INVALID_SOCKET) return (int64_t)-1;
        #else
            if (fd < 0) return (int64_t)-1;
        #endif
        return (int64_t)(intptr_t)fd;
    }

    int64_t cpy_sock_close(int64_t fd) {
        if (fd < 0) return (int64_t)-1;
        #ifdef _WIN32
            int r = closesocket((SOCKET)(intptr_t)fd);
        #else
            int r = close((int)fd);
        #endif
        return (int64_t)r;
    }

    int64_t cpy_sock_bind(int64_t fd, int64_t port) {
        if (fd < 0) return (int64_t)-1;
        struct sockaddr_in a;
        memset(&a, 0, sizeof(a));
        a.sin_family = AF_INET;
        a.sin_port = htons((uint16_t)port);
        a.sin_addr.s_addr = htonl(INADDR_ANY);
        int r = bind((cpy_sock_fd_t)(intptr_t)fd, (struct sockaddr*)&a, sizeof(a));
        return (int64_t)r;
    }

    int64_t cpy_sock_listen(int64_t fd, int64_t backlog) {
        if (fd < 0) return (int64_t)-1;
        int r = listen((cpy_sock_fd_t)(intptr_t)fd, (int)backlog);
        return (int64_t)r;
    }

    int64_t cpy_sock_connect(int64_t fd, const char* host, int64_t port) {
        if (fd < 0) return (int64_t)-1;
        struct sockaddr_in a;
        memset(&a, 0, sizeof(a));
        a.sin_family = AF_INET;
        a.sin_port = htons((uint16_t)port);
        if (inet_pton(AF_INET, host, &a.sin_addr) <= 0) return (int64_t)-1;
        int r = connect((cpy_sock_fd_t)(intptr_t)fd, (struct sockaddr*)&a, sizeof(a));
        return (int64_t)r;
    }

    int64_t cpy_sock_send(int64_t fd, const char* buf, int64_t len) {
        if (fd < 0) return (int64_t)-1;
        #ifdef _WIN32
            int r = send((SOCKET)(intptr_t)fd, buf, (int)len, 0);
        #else
            ssize_t r = send((int)fd, buf, (size_t)len, 0);
        #endif
        return (int64_t)r;
    }

    int64_t cpy_sock_recv(int64_t fd, char* buf, int64_t len) {
        if (fd < 0) return (int64_t)-1;
        #ifdef _WIN32
            int r = recv((SOCKET)(intptr_t)fd, buf, (int)len, 0);
        #else
            ssize_t r = recv((int)fd, buf, (size_t)len, 0);
        #endif
        return (int64_t)r;
    }

public def sock_tcp() -> int:
    return (int)cpy_sock_tcp()

public def sock_close(fd int) -> int:
    return (int)cpy_sock_close((int64)fd)

public def sock_bind(fd int, port int) -> int:
    return (int)cpy_sock_bind((int64)fd, (int64)port)

public def sock_listen(fd int, backlog int) -> int:
    return (int)cpy_sock_listen((int64)fd, (int64)backlog)

public def sock_connect(fd int, host str, port int) -> int:
    return (int)cpy_sock_connect((int64)fd, host, (int64)port)

public def sock_send(fd int, data str) -> int:
    return (int)cpy_sock_send((int64)fd, data, (int64)len(data))

public def sock_recv(fd int, buf char[], n int) -> int:
    return (int)cpy_sock_recv((int64)fd, (void*)buf, (int64)n)
