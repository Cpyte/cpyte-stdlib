# @std/random — NIST SP 800-90A HMAC-DRBG using SHA-256.
#
# Self-contained: SHA-256 (FIPS 180-4), HMAC-SHA-256 (RFC 2104) and the
# HMAC_DRBG state machine (SP 800-90A, Section 10.1.2) are implemented in the
# embedded C block. No OpenSSL dependency, so the package links everywhere the
# base compiler runs.
#
# The DRBG is always instantiated from fresh OS entropy via csprng.cpy. It is
# intended for key/token derivation where a long-running process needs many
# values without an OS RNG syscall per value; reseed explicitly for long-lived
# state.

import "csprng.cpy"

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>

    #define CPY_DRBG_MAX_INPUT 1024
    #define CPY_DRBG_MAX_REQUEST 65536

    /* ---------------- SHA-256 (FIPS 180-4) ---------------- */

    typedef struct {
        uint32_t h[8];
        uint64_t bitlen;
        unsigned char buf[64];
        size_t buflen;
    } cpy_drbg_sha256;

    static const uint32_t cpy_drbg_k[64] = {
        0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,
        0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
        0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,
        0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
        0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,
        0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
        0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,
        0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
        0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,
        0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
        0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,
        0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
        0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,
        0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
        0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,
        0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u
    };

    static uint32_t cpy_drbg_rotr(uint32_t x, int n) {
        return (x >> n) | (x << (32 - n));
    }

    static void cpy_drbg_compress(cpy_drbg_sha256* c, const unsigned char* b) {
        uint32_t w[64];
        for (int i = 0; i < 16; i++) {
            w[i] = ((uint32_t)b[4*i] << 24) | ((uint32_t)b[4*i+1] << 16) |
                   ((uint32_t)b[4*i+2] << 8) | (uint32_t)b[4*i+3];
        }
        for (int i = 16; i < 64; i++) {
            uint32_t s0 = cpy_drbg_rotr(w[i-15], 7) ^ cpy_drbg_rotr(w[i-15], 18) ^ (w[i-15] >> 3);
            uint32_t s1 = cpy_drbg_rotr(w[i-2], 17) ^ cpy_drbg_rotr(w[i-2], 19) ^ (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }
        uint32_t a=c->h[0], bb=c->h[1], cc=c->h[2], d=c->h[3];
        uint32_t e=c->h[4], f=c->h[5], g=c->h[6], h=c->h[7];
        for (int i = 0; i < 64; i++) {
            uint32_t S1 = cpy_drbg_rotr(e,6) ^ cpy_drbg_rotr(e,11) ^ cpy_drbg_rotr(e,25);
            uint32_t ch = (e & f) ^ ((~e) & g);
            uint32_t t1 = h + S1 + ch + cpy_drbg_k[i] + w[i];
            uint32_t S0 = cpy_drbg_rotr(a,2) ^ cpy_drbg_rotr(a,13) ^ cpy_drbg_rotr(a,22);
            uint32_t maj = (a & bb) ^ (a & cc) ^ (bb & cc);
            uint32_t t2 = S0 + maj;
            h=g; g=f; f=e; e=d+t1; d=cc; cc=bb; bb=a; a=t1+t2;
        }
        c->h[0]+=a; c->h[1]+=bb; c->h[2]+=cc; c->h[3]+=d;
        c->h[4]+=e; c->h[5]+=f; c->h[6]+=g; c->h[7]+=h;
    }

    static void cpy_drbg_sha_init(cpy_drbg_sha256* c) {
        c->h[0]=0x6a09e667u; c->h[1]=0xbb67ae85u; c->h[2]=0x3c6ef372u;
        c->h[3]=0xa54ff53au; c->h[4]=0x510e527fu; c->h[5]=0x9b05688cu;
        c->h[6]=0x1f83d9abu; c->h[7]=0x5be0cd19u;
        c->bitlen = 0; c->buflen = 0;
    }

    static void cpy_drbg_sha_update(cpy_drbg_sha256* c, const void* data, size_t n) {
        const unsigned char* p = (const unsigned char*)data;
        c->bitlen += (uint64_t)n * 8;
        if (c->buflen > 0) {
            size_t take = 64 - c->buflen;
            if (take > n) take = n;
            memcpy(c->buf + c->buflen, p, take);
            c->buflen += take; p += take; n -= take;
            if (c->buflen == 64) {
                cpy_drbg_compress(c, c->buf);
                c->buflen = 0;
            }
        }
        while (n >= 64) {
            cpy_drbg_compress(c, p);
            p += 64; n -= 64;
        }
        if (n > 0) {
            memcpy(c->buf, p, n);
            c->buflen = n;
        }
    }

    static void cpy_drbg_sha_final(cpy_drbg_sha256* c, unsigned char out[32]) {
        uint64_t bits = c->bitlen;
        c->buf[c->buflen++] = 0x80;
        if (c->buflen > 56) {
            memset(c->buf + c->buflen, 0, 64 - c->buflen);
            cpy_drbg_compress(c, c->buf);
            c->buflen = 0;
        }
        memset(c->buf + c->buflen, 0, 56 - c->buflen);
        for (int i = 0; i < 8; i++) c->buf[56+i] = (unsigned char)(bits >> (56 - 8*i));
        cpy_drbg_compress(c, c->buf);
        for (int i = 0; i < 8; i++) {
            out[4*i]   = (unsigned char)(c->h[i] >> 24);
            out[4*i+1] = (unsigned char)(c->h[i] >> 16);
            out[4*i+2] = (unsigned char)(c->h[i] >> 8);
            out[4*i+3] = (unsigned char)c->h[i];
        }
    }

    static void cpy_drbg_sha256_digest(const void* data, size_t n, unsigned char out[32]) {
        cpy_drbg_sha256 c;
        cpy_drbg_sha_init(&c);
        cpy_drbg_sha_update(&c, data, n);
        cpy_drbg_sha_final(&c, out);
    }

    /* ---------------- HMAC-SHA-256 (RFC 2104) ---------------- */

    static void cpy_drbg_hmac(const unsigned char* key, size_t klen,
                              const unsigned char* msg, size_t mlen,
                              unsigned char out[32]) {
        unsigned char k[64], ipad[64], opad[64], inner[32];
        cpy_drbg_sha256 ctx;
        memset(k, 0, sizeof(k));
        if (klen > 64) {
            cpy_drbg_sha256_digest(key, klen, k);
            klen = 32;
        }
        if (klen > 0) memcpy(k, key, klen);
        for (int i = 0; i < 64; i++) {
            ipad[i] = (unsigned char)(k[i] ^ 0x36);
            opad[i] = (unsigned char)(k[i] ^ 0x5c);
        }
        cpy_drbg_sha_init(&ctx);
        cpy_drbg_sha_update(&ctx, ipad, 64);
        if (mlen > 0) cpy_drbg_sha_update(&ctx, msg, mlen);
        cpy_drbg_sha_final(&ctx, inner);
        cpy_drbg_sha_init(&ctx);
        cpy_drbg_sha_update(&ctx, opad, 64);
        cpy_drbg_sha_update(&ctx, inner, 32);
        cpy_drbg_sha_final(&ctx, out);
    }

    /* ---------------- HMAC_DRBG (SP 800-90A 10.1.2) ---------------- */

    typedef struct {
        unsigned char k[32];
        unsigned char v[32];
        uint64_t reseed_counter;
    } cpy_hmac_drbg;

    static void cpy_drbg_wipe(void* p, size_t n) {
        volatile unsigned char* q = (volatile unsigned char*)p;
        while (n-- > 0) *q++ = 0;
    }

    static int cpy_drbg_update(cpy_hmac_drbg* st,
                               const unsigned char* provided, size_t plen) {
        unsigned char msg[32 + 1 + CPY_DRBG_MAX_INPUT];
        if (plen > CPY_DRBG_MAX_INPUT) return -1;
        memcpy(msg, st->v, 32);
        msg[32] = 0x00;
        if (plen > 0) memcpy(msg + 33, provided, plen);
        cpy_drbg_hmac(st->k, 32, msg, 33 + plen, st->k);
        cpy_drbg_hmac(st->k, 32, st->v, 32, st->v);
        if (plen > 0) {
            memcpy(msg, st->v, 32);
            msg[32] = 0x01;
            memcpy(msg + 33, provided, plen);
            cpy_drbg_hmac(st->k, 32, msg, 33 + plen, st->k);
            cpy_drbg_hmac(st->k, 32, st->v, 32, st->v);
        }
        return 0;
    }

    void* cpy_drbg_new(const void* entropy, size_t ent_len,
                       const void* personalization, size_t pers_len) {
        if (entropy == NULL || ent_len == 0) return NULL;
        cpy_hmac_drbg* st = (cpy_hmac_drbg*)calloc(1, sizeof(cpy_hmac_drbg));
        if (st == NULL) return NULL;
        memset(st->k, 0, 32);
        memset(st->v, 1, 32);
        unsigned char seed[CPY_DRBG_MAX_INPUT];
        size_t n = 0;
        if (ent_len > sizeof(seed)) { free(st); return NULL; }
        memcpy(seed, entropy, ent_len); n += ent_len;
        if (pers_len > sizeof(seed) - n) { cpy_drbg_wipe(seed, sizeof(seed)); free(st); return NULL; }
        if (pers_len > 0) { memcpy(seed + n, personalization, pers_len); n += pers_len; }
        if (cpy_drbg_update(st, seed, n) != 0) {
            cpy_drbg_wipe(seed, sizeof(seed)); free(st); return NULL;
        }
        cpy_drbg_wipe(seed, sizeof(seed));
        st->reseed_counter = 1;
        return (void*)st;
    }

    int cpy_drbg_generate(void* handle, void* out, size_t outlen,
                          const void* addin, size_t addinlen) {
        if (handle == NULL || out == NULL) return -1;
        if (outlen == 0 || outlen > CPY_DRBG_MAX_REQUEST) return -1;
        if (addin == NULL) addinlen = 0;
        if (addinlen > CPY_DRBG_MAX_INPUT) return -1;
        cpy_hmac_drbg* st = (cpy_hmac_drbg*)handle;
        if (st->reseed_counter >= 0x800000000000ULL) return -1;
        if (addinlen > 0 && cpy_drbg_update(st, (const unsigned char*)addin, addinlen) != 0)
            return -1;
        unsigned char* p = (unsigned char*)out;
        size_t left = outlen;
        while (left > 0) {
            cpy_drbg_hmac(st->k, 32, st->v, 32, st->v);
            size_t take = left < 32 ? left : 32;
            memcpy(p, st->v, take);
            p += take; left -= take;
        }
        if (cpy_drbg_update(st, (const unsigned char*)addin, addinlen) != 0) return -1;
        st->reseed_counter++;
        return 0;
    }

    int cpy_drbg_reseed(void* handle, const void* entropy, size_t ent_len,
                        const void* addin, size_t addinlen) {
        if (handle == NULL || entropy == NULL || ent_len == 0) return -1;
        if (addin == NULL) addinlen = 0;
        if (ent_len + addinlen > CPY_DRBG_MAX_INPUT) return -1;
        cpy_hmac_drbg* st = (cpy_hmac_drbg*)handle;
        unsigned char seed[CPY_DRBG_MAX_INPUT];
        memcpy(seed, entropy, ent_len);
        if (addinlen > 0) memcpy(seed + ent_len, addin, addinlen);
        int rc = cpy_drbg_update(st, seed, ent_len + addinlen);
        cpy_drbg_wipe(seed, sizeof(seed));
        if (rc == 0) st->reseed_counter = 1;
        return rc;
    }

    uint64_t cpy_drbg_below(void* handle, uint64_t bound) {
        if (bound == 0) return 0;
        uint64_t threshold = (uint64_t)(0 - bound) % bound;
        uint64_t r = 0;
        do {
            if (cpy_drbg_generate(handle, &r, 8, NULL, 0) != 0) return 0;
        } while (r < threshold);
        return r % bound;
    }

    uint64_t cpy_drbg_counter(void* handle) {
        if (handle == NULL) return 0;
        return ((cpy_hmac_drbg*)handle)->reseed_counter;
    }

    void cpy_drbg_free(void* handle) {
        if (handle == NULL) return;
        cpy_hmac_drbg* st = (cpy_hmac_drbg*)handle;
        cpy_drbg_wipe(st, sizeof(*st));
        free(st);
    }

# ---------------------------------------------------------------------------
# cpy surface
# ---------------------------------------------------------------------------

# Create a DRBG seeded with 48 fresh OS-entropy bytes and an optional
# personalization string. Returns NULL on failure.
public def drbg_new(personalization str) -> void*:
    char[] ent = bytes(48)
    void* st = cpy_drbg_new((void*)ent, 48, (void*)personalization,
                            (size_t)len(personalization))
    wipe((void*)ent, 48)
    return st

# Create a DRBG from caller-supplied entropy (deterministic; for tests).
public def drbg_from_entropy(entropy void*, n size_t, personalization str) -> void*:
    return cpy_drbg_new(entropy, n, (void*)personalization,
                        (size_t)len(personalization))

# Generate `n` bytes. Returns -1 on failure, 0 on success.
public def drbg_fill(state void*, dst void*, n size_t) -> int:
    return cpy_drbg_generate(state, dst, n, 0, 0)

# Generate `n` bytes into a fresh array.
public def drbg_bytes(state void*, n int64) -> char[]:
    char[] out = new char[(int)n]
    if n > 0:
        cpy_drbg_generate(state, (void*)out, (size_t)n, 0, 0)
    return out

# Uniform 64-bit value.
public def drbg_u64(state void*) -> uint64:
    uint64 v = 0
    cpy_drbg_generate(state, (void*)&v, 8, 0, 0)
    return v

# Uniform integer in [0, bound), without modulo bias.
public def drbg_below(state void*, bound uint64) -> uint64:
    return cpy_drbg_below(state, bound)

# Uniform integer in [lo, hi], inclusive.
public def drbg_int_range(state void*, lo int64, hi int64) -> int64:
    if hi < lo:
        return lo
    uint64 span = (uint64)(hi - lo) + 1
    if span == 0:
        return lo
    return lo + (int64)cpy_drbg_below(state, span)

# Inject fresh entropy into an existing state.
public def drbg_reseed(state void*) -> int:
    char[] ent = bytes(48)
    int rc = cpy_drbg_reseed(state, (void*)ent, 48, 0, 0)
    wipe((void*)ent, 48)
    return rc

# Number of generate requests since instantiation/reseed.
public def drbg_counter(state void*) -> uint64:
    return cpy_drbg_counter(state)

# Wipe and release the state.
public def drbg_free(state void*) -> void:
    cpy_drbg_free(state)
