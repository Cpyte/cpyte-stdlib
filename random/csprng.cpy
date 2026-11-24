# @std/random — operating-system CSPRNG and secret-buffer helpers.
#
# This module is the entropy root of the package. It never implements its own
# randomness: every byte comes from the platform's cryptographic RNG.
#
#   Windows  : RtlGenRandom (SystemFunction036), resolved dynamically so no
#              extra import library is needed at link time.
#   Apple/BSD: arc4random_buf()
#   Linux/other POSIX: /dev/urandom (read fully, EINTR-safe).
#
# All C symbols are prefixed `cpy_rng_` so this file can coexist with the
# cryptography package's `cpy_fill_random` and with the other random modules.

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <string.h>

    #if defined(_WIN32)
        #define WIN32_LEAN_AND_MEAN
        #include <windows.h>

        int cpy_rng_os_bytes(void* buf, size_t n) {
            if (n == 0) return 0;
            if (buf == NULL) return -1;
            HMODULE h = GetModuleHandleA("advapi32.dll");
            if (h == NULL) return -1;
            typedef BOOLEAN (WINAPI *cpy_rng_rtl_fn)(PVOID, ULONG);
            cpy_rng_rtl_fn fn = (cpy_rng_rtl_fn)GetProcAddress(h, "SystemFunction036");
            if (fn == NULL) return -1;
            unsigned char* p = (unsigned char*)buf;
            while (n > 0) {
                ULONG chunk = (n > (size_t)0xFFFFFFFFu) ? (ULONG)0xFFFFFFFFu : (ULONG)n;
                if (!fn(p, chunk)) return -1;
                p += chunk;
                n -= (size_t)chunk;
            }
            return 0;
        }
    #elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || \
          defined(__NetBSD__) || defined(__DragonFly__)
        #include <stdlib.h>

        int cpy_rng_os_bytes(void* buf, size_t n) {
            if (n == 0) return 0;
            if (buf == NULL) return -1;
            arc4random_buf(buf, n);
            return 0;
        }
    #else
        #include <errno.h>
        #include <fcntl.h>
        #include <unistd.h>

        int cpy_rng_os_bytes(void* buf, size_t n) {
            if (n == 0) return 0;
            if (buf == NULL) return -1;
            int fd = open("/dev/urandom", O_RDONLY);
            if (fd < 0) return -1;
            unsigned char* p = (unsigned char*)buf;
            while (n > 0) {
                ssize_t got = read(fd, p, n);
                if (got > 0) {
                    p += got;
                    n -= (size_t)got;
                    continue;
                }
                if (got < 0 && errno == EINTR) continue;
                close(fd);
                return -1;
            }
            close(fd);
            return 0;
        }
    #endif

    /* Volatile store: the compiler is not allowed to optimize this away. */
    void cpy_rng_zero(void* buf, size_t n) {
        volatile unsigned char* p = (volatile unsigned char*)buf;
        if (p == NULL) return;
        while (n-- > 0) *p++ = 0;
    }

    uint64_t cpy_rng_os_u64(void) {
        uint64_t v = 0;
        if (cpy_rng_os_bytes(&v, sizeof(v)) != 0) return 0;
        return v;
    }

    /* Unbiased integer in [0, bound). Rejection sampling on the full 64-bit
     * domain; threshold = 2**64 % bound, computed without a 128-bit type. */
    uint64_t cpy_rng_below(uint64_t bound) {
        if (bound == 0) return 0;
        uint64_t threshold = (uint64_t)(0 - bound) % bound;
        uint64_t r = 0;
        do {
            if (cpy_rng_os_bytes(&r, sizeof(r)) != 0) return 0;
        } while (r < threshold);
        return r % bound;
    }

    static const char cpy_rng_hex_digits[] = "0123456789abcdef";

    /* out must hold 2*n + 1 bytes; a final NUL is written. */
    void cpy_rng_hex(const void* data, size_t n, char* out) {
        const unsigned char* p = (const unsigned char*)data;
        for (size_t i = 0; i < n; i++) {
            out[2 * i]     = cpy_rng_hex_digits[p[i] >> 4];
            out[2 * i + 1] = cpy_rng_hex_digits[p[i] & 0x0f];
        }
        out[2 * n] = '\0';
    }

    static const char cpy_rng_b64_digits[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    /* RFC 4648 unpadded base64url. out must hold ceil(n*4/3) + 1 bytes. */
    size_t cpy_rng_b64url(const void* data, size_t n, char* out) {
        const unsigned char* p = (const unsigned char*)data;
        size_t j = 0;
        size_t i = 0;
        while (i + 3 <= n) {
            uint32_t v = ((uint32_t)p[i] << 16) | ((uint32_t)p[i + 1] << 8) |
                         (uint32_t)p[i + 2];
            out[j++] = cpy_rng_b64_digits[(v >> 18) & 63];
            out[j++] = cpy_rng_b64_digits[(v >> 12) & 63];
            out[j++] = cpy_rng_b64_digits[(v >> 6) & 63];
            out[j++] = cpy_rng_b64_digits[v & 63];
            i += 3;
        }
        if (n - i == 1) {
            uint32_t v = (uint32_t)p[i] << 16;
            out[j++] = cpy_rng_b64_digits[(v >> 18) & 63];
            out[j++] = cpy_rng_b64_digits[(v >> 12) & 63];
        } else if (n - i == 2) {
            uint32_t v = ((uint32_t)p[i] << 16) | ((uint32_t)p[i + 1] << 8);
            out[j++] = cpy_rng_b64_digits[(v >> 18) & 63];
            out[j++] = cpy_rng_b64_digits[(v >> 12) & 63];
            out[j++] = cpy_rng_b64_digits[(v >> 6) & 63];
        }
        out[j] = '\0';
        return j;
    }

    void cpy_rng_uuid4(const void* data, char* out) {
        unsigned char b[16];
        if (data != NULL) memcpy(b, data, 16);
        else if (cpy_rng_os_bytes(b, 16) != 0) memset(b, 0, 16);
        b[6] = (unsigned char)((b[6] & 0x0f) | 0x40);
        b[8] = (unsigned char)((b[8] & 0x3f) | 0x80);
        static const char* hx = "0123456789abcdef";
        size_t j = 0;
        for (size_t i = 0; i < 16; i++) {
            if (i == 4 || i == 6 || i == 8 || i == 10) out[j++] = '-';
            out[j++] = hx[b[i] >> 4];
            out[j++] = hx[b[i] & 0x0f];
        }
        out[j] = '\0';
    }

    int cpy_rng_ct_equal(const void* a, const void* b, size_t n) {
        if (a == NULL || b == NULL) return 0;
        const volatile unsigned char* x = (const volatile unsigned char*)a;
        const volatile unsigned char* y = (const volatile unsigned char*)b;
        unsigned char diff = 0;
        for (size_t i = 0; i < n; i++) diff |= (unsigned char)(x[i] ^ y[i]);
        return diff == 0 ? 1 : 0;
    }

# ---------------------------------------------------------------------------
# cpy surface
# ---------------------------------------------------------------------------

# Fill `dst` with `n` bytes from the OS CSPRNG. Returns 0 on success, -1 on
# failure (the caller must not use the buffer in that case).
public def os_bytes(dst void*, n size_t) -> int:
    return cpy_rng_os_bytes(dst, n)

# Overwrite a secret buffer with zeros in a way the optimizer cannot remove.
public def wipe(dst void*, n size_t) -> void:
    cpy_rng_zero(dst, n)

# Fresh cryptographic random bytes as a Cpyte array.
public def bytes(n int64) -> char[]:
    if n < 0:
        n = 0
    char[] out = new char[(int)n]
    if n > 0:
        cpy_rng_os_bytes((void*)out, (size_t)n)
    return out

# One uniform 64-bit value.
public def u64() -> uint64:
    return cpy_rng_os_u64()

# Uniform integer in [0, bound), rejection-sampled (no modulo bias).
public def below(bound uint64) -> uint64:
    return cpy_rng_below(bound)

# Uniform integer in [lo, hi], inclusive.
public def int_range(lo int64, hi int64) -> int64:
    if hi < lo:
        return lo
    uint64 span = (uint64)(hi - lo) + 1
    if span == 0:
        return lo
    uint64 r = cpy_rng_below(span)
    return lo + (int64)r

# Hex encoding (lowercase, NUL-terminated) of `n` bytes at `src`.
public def hex(src void*, n size_t) -> char[]:
    char[] out = new char[(int)(n * 2 + 1)]
    cpy_rng_hex(src, n, (char*)out)
    return out

# Unpadded base64url encoding (RFC 4648) of `n` bytes at `src`.
public def b64url(src void*, n size_t) -> char[]:
    char[] out = new char[(int)((n * 4 + 2) / 3 + 1)]
    cpy_rng_b64url(src, n, (char*)out)
    return out

# RFC 4122 version-4 UUID from OS entropy (36 chars + NUL).
public def uuid4() -> char[]:
    char[] out = new char[37]
    cpy_rng_uuid4(0, (char*)out)
    return out

# Constant-time equality over `n` bytes; 1 when equal, 0 otherwise.
public def ct_equal(a void*, b void*, n size_t) -> int:
    return cpy_rng_ct_equal(a, b, n)
