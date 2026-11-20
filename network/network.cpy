# network 1.1.0 - minimal HTTP helpers (blocking HTTP/1.0)
# HTTPS: compiles only when the consumer builds with -DCPYTE_NET_HAVE_OPENSSL and links OpenSSL
# (libssl/libcrypto). Without it, https:// URLs return an error from net_last_error().

ccode:
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdio.h>

    #ifdef _WIN32
        #ifndef WIN32_LEAN_AND_MEAN
        #define WIN32_LEAN_AND_MEAN
        #endif
        #include <winsock2.h>
        #include <ws2tcpip.h>
        #if defined(_MSC_VER)
        #pragma comment(lib, "ws2_32.lib")
        #endif
        typedef SOCKET cpy_sock_t;
        #define CPY_SOCK_INVALID INVALID_SOCKET
        static int cpy_net_wsa_inited = 0;
        static void cpy_net_wsa_init(void) {
            if (!cpy_net_wsa_inited) {
                WSADATA wsa;
                if (WSAStartup(MAKEWORD(2,2), &wsa) == 0) cpy_net_wsa_inited = 1;
            }
        }
        static void cpy_net_close_sock(cpy_sock_t s) { closesocket(s); }
    #else
        #include <sys/types.h>
        #include <sys/socket.h>
        #include <netdb.h>
        #include <netinet/in.h>
        #include <arpa/inet.h>
        #include <unistd.h>
        #include <errno.h>
        typedef int cpy_sock_t;
        #define CPY_SOCK_INVALID (-1)
        static void cpy_net_wsa_init(void) {}
        static void cpy_net_close_sock(cpy_sock_t s) { close(s); }
    #endif

    /* Optional OpenSSL for HTTPS. If headers/libs not available at compile time,
       HTTPS requests will return an error message. */
    #if defined(CPYTE_NET_HAVE_OPENSSL)
    #include <openssl/ssl.h>
    #include <openssl/err.h>
    #include <openssl/x509v3.h>
    static int cpy_ssl_inited = 0;
    static void cpy_ssl_ensure(void) {
        if (!cpy_ssl_inited) {
            SSL_load_error_strings();
            OpenSSL_add_ssl_algorithms();
            cpy_ssl_inited = 1;
        }
    }
    #endif

    static int g_net_status = 0;
    static char g_net_err[256] = {0};

    static void set_err(const char* m) {
        g_net_status = 0;
        if (!m) m = "unknown error";
        strncpy(g_net_err, m, sizeof(g_net_err)-1);
        g_net_err[sizeof(g_net_err)-1] = 0;
    }

    static void clear_err(void) {
        g_net_status = 0;
        g_net_err[0] = 0;
    }

    static int parse_http_url(const char* url, int* is_https, char* host, size_t hostsz, int* port, char* path, size_t pathsz) {
        const char* p = url;
        if (strncmp(p, "http://", 7) == 0) { *is_https = 0; p += 7; }
        else if (strncmp(p, "https://", 8) == 0) { *is_https = 1; p += 8; }
        else { set_err("url must start with http:// or https://"); return -1; }
        const char* slash = strchr(p, '/');
        const char* hostport = p;
        size_t hlen = slash ? (size_t)(slash - p) : strlen(p);
        if (hlen == 0 || hlen >= hostsz) { set_err("bad url host"); return -1; }
        const char* colon = memchr(hostport, ':', hlen);
        if (colon) {
            size_t hn = (size_t)(colon - hostport);
            if (hn == 0 || hn >= hostsz) { set_err("bad url host"); return -1; }
            memcpy(host, hostport, hn);
            host[hn] = 0;
            *port = atoi(colon + 1);
            if (*port <= 0) *port = (*is_https ? 443 : 80);
        } else {
            memcpy(host, hostport, hlen);
            host[hlen] = 0;
            *port = (*is_https ? 443 : 80);
        }
        if (slash) {
            strncpy(path, slash, pathsz - 1);
            path[pathsz - 1] = 0;
        } else {
            strncpy(path, "/", pathsz - 1);
            path[pathsz - 1] = 0;
        }
        return 0;
    }

    static void apply_timeouts(cpy_sock_t sock) {
        #ifdef _WIN32
            DWORD tv = 15000;
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&tv, sizeof(tv));
        #else
            struct timeval tv;
            tv.tv_sec = 15;
            tv.tv_usec = 0;
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        #endif
    }

    static char* cpy_net_http_do(const char* url, const char* method, const char* body, const char* content_type) {
        cpy_net_wsa_init();
        clear_err();
        if (!url || url[0] == 0) { set_err("empty url"); return NULL; }
        if (!method || method[0] == 0) method = "GET";
        int is_https = 0;
        char host[512];
        char path[2048];
        int port = 80;
        if (parse_http_url(url, &is_https, host, sizeof(host), &port, path, sizeof(path)) != 0) return NULL;

        #if !defined(CPYTE_NET_HAVE_OPENSSL)
        if (is_https) { set_err("HTTPS not built-in (OpenSSL not available at compile time). Use http://"); return NULL; }
        #endif

        struct addrinfo hints;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        struct addrinfo* res = NULL;
        char portstr[16];
        snprintf(portstr, sizeof(portstr), "%d", port);
        if (getaddrinfo(host, portstr, &hints, &res) != 0 || res == NULL) {
            set_err("getaddrinfo failed");
            return NULL;
        }
        cpy_sock_t sock = CPY_SOCK_INVALID;
        struct addrinfo* rp;
        for (rp = res; rp != NULL; rp = rp->ai_next) {
            sock = (cpy_sock_t)socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
            if (sock == CPY_SOCK_INVALID) continue;
            apply_timeouts(sock);
            if (connect(sock, rp->ai_addr, (int)rp->ai_addrlen) == 0) break;
            cpy_net_close_sock(sock);
            sock = CPY_SOCK_INVALID;
        }
        freeaddrinfo(res);
        if (sock == CPY_SOCK_INVALID) { set_err("connect failed"); return NULL; }

        size_t body_len = (body && body[0]) ? strlen(body) : 0;
        char req[8192];
        int rn;
        if (body_len > 0) {
            const char* ct = (content_type && content_type[0]) ? content_type : "application/octet-stream";
            rn = snprintf(req, sizeof(req),
                "%s %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: cpyte-stdlib/1.0\r\nConnection: close\r\nContent-Type: %s\r\nContent-Length: %zu\r\n\r\n",
                method, path, host, ct, body_len);
        } else {
            rn = snprintf(req, sizeof(req),
                "%s %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: cpyte-stdlib/1.0\r\nConnection: close\r\n\r\n",
                method, path, host);
        }
        if (rn <= 0 || rn >= (int)sizeof(req)) { cpy_net_close_sock(sock); set_err("request header too large"); return NULL; }

        #if defined(CPYTE_NET_HAVE_OPENSSL)
        SSL_CTX* ctx = NULL;
        SSL* ssl = NULL;
        if (is_https) {
            cpy_ssl_ensure();
            const SSL_METHOD* method_ssl = TLS_client_method();
            ctx = SSL_CTX_new(method_ssl);
            if (!ctx) { cpy_net_close_sock(sock); set_err("SSL_CTX_new failed"); return NULL; }
            SSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, NULL); /* minimal: no cert verification for now */
            ssl = SSL_new(ctx);
            if (!ssl) { SSL_CTX_free(ctx); cpy_net_close_sock(sock); set_err("SSL_new failed"); return NULL; }
            SSL_set_tlsext_host_name(ssl, host);
            SSL_set_fd(ssl, (int)sock);
            if (SSL_connect(ssl) != 1) {
                SSL_free(ssl); SSL_CTX_free(ctx); cpy_net_close_sock(sock); set_err("SSL_connect failed"); return NULL;
            }
        }
        #define NET_SEND(d,l) (is_https ? SSL_write(ssl,d,(int)(l)) : send(sock,d,(l),0))
        #define NET_RECV(d,l) (is_https ? SSL_read(ssl,d,(int)(l)) : recv(sock,d,(l),0))
        #else
        #define NET_SEND(d,l) send(sock,d,(l),0)
        #define NET_RECV(d,l) recv(sock,d,(l),0)
        #endif

        #ifdef _WIN32
        if (NET_SEND(req, (size_t)rn) < 0) {
        #else
        if (NET_SEND(req, (size_t)rn) < 0) {
        #endif
            #if defined(CPYTE_NET_HAVE_OPENSSL)
            if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
            #endif
            cpy_net_close_sock(sock); set_err("send failed"); return NULL;
        }
        if (body_len > 0) {
            if (NET_SEND(body, body_len) < 0) {
                #if defined(CPYTE_NET_HAVE_OPENSSL)
                if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
                #endif
                cpy_net_close_sock(sock); set_err("send body failed"); return NULL;
            }
        }

        size_t cap = 16384;
        size_t len = 0;
        char* buf = (char*)malloc(cap + 1);
        if (!buf) {
            #if defined(CPYTE_NET_HAVE_OPENSSL)
            if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
            #endif
            cpy_net_close_sock(sock); set_err("oom"); return NULL;
        }
        for (;;) {
            char tmp[4096];
            int n = NET_RECV(tmp, sizeof(tmp));
            if (n < 0) { free(buf);
                #if defined(CPYTE_NET_HAVE_OPENSSL)
                if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
                #endif
                cpy_net_close_sock(sock); set_err("recv failed (timeout?)"); return NULL;
            }
            if (n == 0) break;
            if (len + (size_t)n + 1 > cap) {
                cap = cap * 2 + (size_t)n + 1024;
                char* nb = (char*)realloc(buf, cap + 1);
                if (!nb) { free(buf);
                    #if defined(CPYTE_NET_HAVE_OPENSSL)
                    if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
                    #endif
                    cpy_net_close_sock(sock); set_err("oom"); return NULL;
                }
                buf = nb;
            }
            memcpy(buf + len, tmp, (size_t)n);
            len += (size_t)n;
        }
        buf[len] = 0;
        #if defined(CPYTE_NET_HAVE_OPENSSL)
        if (is_https) { SSL_free(ssl); SSL_CTX_free(ctx); }
        #endif
        cpy_net_close_sock(sock);

        g_net_status = 0;
        if (len >= 5 && strncmp(buf, "HTTP/", 5) == 0) {
            const char* sp = strchr(buf, ' ');
            if (sp) g_net_status = atoi(sp + 1);
        }
        char* bodyp = strstr(buf, "\r\n\r\n");
        if (bodyp) bodyp += 4;
        else {
            bodyp = strstr(buf, "\n\n");
            if (bodyp) bodyp += 2;
            else bodyp = buf;
        }
        size_t blen = strlen(bodyp);
        char* out = (char*)malloc(blen + 1);
        if (!out) { free(buf); set_err("oom"); return NULL; }
        memcpy(out, bodyp, blen + 1);
        free(buf);
        return out;
    }

    #undef NET_SEND
    #undef NET_RECV

    char* cpy_net_http_get(const char* url) {
        return cpy_net_http_do(url, "GET", NULL, NULL);
    }

    char* cpy_net_http_post(const char* url, const char* body, const char* content_type) {
        return cpy_net_http_do(url, "POST", body ? body : "", content_type);
    }

    int64_t cpy_net_last_status(void) { return (int64_t)g_net_status; }
    const char* cpy_net_last_error(void) { return g_net_err[0] ? g_net_err : ""; }

public def net_http_get(url str) -> str:
    return cpy_net_http_get(url)

public def net_http_post(url str, body str, content_type str) -> str:
    return cpy_net_http_post(url, body, content_type)

public def net_last_status() -> int:
    return (int)cpy_net_last_status()

public def net_last_error() -> str:
    return cpy_net_last_error()
