# @std/random — seeded pseudo-random number generators.
#
# Six well-known PRNGs, all implemented in one self-contained C block. Every
# generator is deterministic for a given algorithm + 64-bit seed, which makes
# it suitable for simulations, procedural content and reproducible tests.
# These are NOT cryptographically secure — use csprng.cpy or drbg.cpy for keys,
# tokens and secrets.
#
#   alg 1  SplitMix64         (64-bit, 1 word, very fast)
#   alg 2  PCG32              (32-bit, 2 words, good statistical quality)
#   alg 3  xoshiro256**       (64-bit, 4 words, modern default)
#   alg 4  MT19937            (32-bit, classic, 624-word state)
#   alg 5  Philox2x32-10      (counter-based, 64-bit counter / 32-bit key)
#   alg 6  Philox4x32-10      (counter-based, 128-bit counter / 64-bit key)
#
# The Philox algorithms are a family: rounds are configurable (1..16, default
# 10), and exact counter/key constructors are provided for known-answer tests.

import "csprng.cpy"

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>

    enum {
        CPY_PRNG_SPLITMIX64 = 1,
        CPY_PRNG_PCG32 = 2,
        CPY_PRNG_XOSHIRO256SS = 3,
        CPY_PRNG_MT19937 = 4,
        CPY_PRNG_PHILOX2X32 = 5,
        CPY_PRNG_PHILOX4X32 = 6
    };

    typedef struct {
        int alg;
        uint64_t s[4];
        uint32_t mt[624];
        int idx;
        uint32_t ph_c[4];
        uint32_t ph_k[2];
        uint32_t ph_buf[4];
        int ph_pos;
        int ph_rounds;
    } cpy_prng_state;

    static uint64_t cpy_prng_splitmix(uint64_t* x) {
        uint64_t z = (*x += 0x9E3779B97F4A7C15ULL);
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
        return z ^ (z >> 31);
    }

    static int cpy_prng_rounds_clamp(int rounds) {
        if (rounds < 1) return 10;
        if (rounds > 16) return 16;
        return rounds;
    }

    static uint32_t cpy_prng_mulhi32(uint32_t a, uint32_t b, uint32_t* lo) {
        uint64_t p = (uint64_t)a * (uint64_t)b;
        *lo = (uint32_t)p;
        return (uint32_t)(p >> 32);
    }

    static void cpy_prng_philox2_rounds(uint32_t c[2], uint32_t k[2], int rounds) {
        for (int r = 0; r < rounds; r++) {
            uint32_t lo;
            uint32_t hi = cpy_prng_mulhi32(0xD2511F53u, c[0], &lo);
            uint32_t n0 = hi ^ c[1] ^ k[0];
            c[1] = lo;
            c[0] = n0;
            k[0] += 0x9E3779B9u;
        }
    }

    static void cpy_prng_philox4_rounds(uint32_t c[4], uint32_t k[2], int rounds) {
        for (int r = 0; r < rounds; r++) {
            uint32_t lo0, lo1;
            uint32_t hi0 = cpy_prng_mulhi32(0xD2511F53u, c[0], &lo0);
            uint32_t hi1 = cpy_prng_mulhi32(0xCD9E8D57u, c[2], &lo1);
            uint32_t n0 = hi1 ^ c[1] ^ k[0];
            uint32_t n1 = lo1;
            uint32_t n2 = hi0 ^ c[3] ^ k[1];
            uint32_t n3 = lo0;
            c[0] = n0;
            c[1] = n1;
            c[2] = n2;
            c[3] = n3;
            k[0] += 0x9E3779B9u;
            k[1] += 0xBB67AE85u;
        }
    }

    static void cpy_prng_philox_seed(cpy_prng_state* p, uint64_t seed, int rounds) {
        uint64_t x = seed;
        p->ph_rounds = cpy_prng_rounds_clamp(rounds);
        if (p->alg == CPY_PRNG_PHILOX2X32) {
            p->ph_c[0] = (uint32_t)x;
            p->ph_c[1] = (uint32_t)(x >> 32);
            p->ph_k[0] = (uint32_t)(x ^ (x >> 32) ^ 0x9E3779B97F4A7C15ULL);
            p->ph_k[1] = 0;
        } else {
            p->ph_c[0] = (uint32_t)cpy_prng_splitmix(&x);
            p->ph_c[1] = (uint32_t)(cpy_prng_splitmix(&x) >> 32);
            p->ph_c[2] = (uint32_t)cpy_prng_splitmix(&x);
            p->ph_c[3] = (uint32_t)(cpy_prng_splitmix(&x) >> 32);
            p->ph_k[0] = (uint32_t)cpy_prng_splitmix(&x);
            p->ph_k[1] = (uint32_t)(cpy_prng_splitmix(&x) >> 32);
        }
        p->ph_pos = 99;
    }

    static uint32_t cpy_prng_philox_next32(cpy_prng_state* p) {
        int words = (p->alg == CPY_PRNG_PHILOX2X32) ? 2 : 4;
        if (p->ph_pos >= words) {
            uint32_t c[4] = {p->ph_c[0], p->ph_c[1], p->ph_c[2], p->ph_c[3]};
            uint32_t k[2] = {p->ph_k[0], p->ph_k[1]};
            if (p->alg == CPY_PRNG_PHILOX2X32) {
                cpy_prng_philox2_rounds(c, k, p->ph_rounds);
                p->ph_buf[0] = c[0];
                p->ph_buf[1] = c[1];
                p->ph_c[0]++;
                if (p->ph_c[0] == 0) p->ph_c[1]++;
            } else {
                cpy_prng_philox4_rounds(c, k, p->ph_rounds);
                for (int i = 0; i < 4; i++) p->ph_buf[i] = c[i];
                for (int i = 0; i < 4; i++) {
                    p->ph_c[i]++;
                    if (p->ph_c[i] != 0) break;
                }
            }
            p->ph_pos = 0;
        }
        return p->ph_buf[p->ph_pos++];
    }

    static uint32_t cpy_prng_pcg32(cpy_prng_state* p) {
        uint64_t old = p->s[0];
        p->s[0] = old * 6364136223846793005ULL + (p->s[1] | 1ULL);
        uint32_t xorshifted = (uint32_t)(((old >> 18u) ^ old) >> 27u);
        uint32_t rot = (uint32_t)(old >> 59u);
        return (xorshifted >> rot) | (xorshifted << ((-rot) & 31u));
    }

    static uint64_t cpy_prng_rotl64(uint64_t x, int k) {
        return (x << k) | (x >> (64 - k));
    }

    static uint64_t cpy_prng_xoshiro(cpy_prng_state* p) {
        uint64_t result = cpy_prng_rotl64(p->s[1] * 5ULL, 7) * 9ULL;
        uint64_t t = p->s[1] << 17;
        p->s[2] ^= p->s[0];
        p->s[3] ^= p->s[1];
        p->s[1] ^= p->s[2];
        p->s[0] ^= p->s[3];
        p->s[2] ^= t;
        p->s[3] = cpy_prng_rotl64(p->s[3], 45);
        return result;
    }

    static void cpy_prng_mt_init(cpy_prng_state* p, uint32_t seed) {
        p->mt[0] = seed;
        for (int i = 1; i < 624; i++) {
            uint32_t prev = p->mt[i - 1];
            p->mt[i] = 1812433253u * (prev ^ (prev >> 30)) + (uint32_t)i;
        }
        p->idx = 624;
    }

    static uint32_t cpy_prng_mt_next(cpy_prng_state* p) {
        if (p->idx >= 624) {
            for (int i = 0; i < 624; i++) {
                uint32_t y = (p->mt[i] & 0x80000000u) |
                             (p->mt[(i + 1) % 624] & 0x7fffffffu);
                p->mt[i] = p->mt[(i + 397) % 624] ^ (y >> 1);
                if (y & 1u) p->mt[i] ^= 0x9908b0dfu;
            }
            p->idx = 0;
        }
        uint32_t y = p->mt[p->idx++];
        y ^= y >> 11;
        y ^= (y << 7) & 0x9d2c5680u;
        y ^= (y << 15) & 0xefc60000u;
        y ^= y >> 18;
        return y;
    }

    void* cpy_prng_new_rounds(int alg, uint64_t seed, int rounds) {
        if (alg < 1 || alg > 6) return NULL;
        cpy_prng_state* p = (cpy_prng_state*)calloc(1, sizeof(cpy_prng_state));
        if (p == NULL) return NULL;
        p->alg = alg;
        p->idx = 624;
        p->ph_pos = 99;
        p->ph_rounds = cpy_prng_rounds_clamp(rounds);
        if (alg == CPY_PRNG_SPLITMIX64) {
            p->s[0] = seed;
        } else if (alg == CPY_PRNG_PCG32) {
            p->s[0] = 0;
            p->s[1] = ((seed & 0xFFFFFFFFULL) << 1) | 1ULL;
            (void)cpy_prng_pcg32(p);
            p->s[0] += seed;
            (void)cpy_prng_pcg32(p);
        } else if (alg == CPY_PRNG_XOSHIRO256SS) {
            uint64_t x = seed;
            for (int i = 0; i < 4; i++) p->s[i] = cpy_prng_splitmix(&x);
        } else if (alg == CPY_PRNG_MT19937) {
            cpy_prng_mt_init(p, (uint32_t)seed);
        } else {
            cpy_prng_philox_seed(p, seed, rounds);
        }
        return (void*)p;
    }

    void* cpy_prng_new(int alg, uint64_t seed) {
        return cpy_prng_new_rounds(alg, seed, 10);
    }

    void* cpy_prng_philox_new_exact(int alg, uint32_t key0, uint32_t key1,
                                    uint32_t c0, uint32_t c1,
                                    uint32_t c2, uint32_t c3, int rounds) {
        if (alg != CPY_PRNG_PHILOX2X32 && alg != CPY_PRNG_PHILOX4X32) return NULL;
        cpy_prng_state* p = (cpy_prng_state*)calloc(1, sizeof(cpy_prng_state));
        if (p == NULL) return NULL;
        p->alg = alg;
        p->idx = 624;
        p->ph_c[0] = c0;
        p->ph_c[1] = c1;
        p->ph_c[2] = c2;
        p->ph_c[3] = c3;
        p->ph_k[0] = key0;
        p->ph_k[1] = key1;
        p->ph_rounds = cpy_prng_rounds_clamp(rounds);
        p->ph_pos = 99;
        return (void*)p;
    }

    uint64_t cpy_prng_next_u64(void* handle) {
        if (handle == NULL) return 0;
        cpy_prng_state* p = (cpy_prng_state*)handle;
        switch (p->alg) {
            case CPY_PRNG_SPLITMIX64: return cpy_prng_splitmix(&p->s[0]);
            case CPY_PRNG_PCG32: return ((uint64_t)cpy_prng_pcg32(p) << 32) | cpy_prng_pcg32(p);
            case CPY_PRNG_XOSHIRO256SS: return cpy_prng_xoshiro(p);
            case CPY_PRNG_MT19937: return ((uint64_t)cpy_prng_mt_next(p) << 32) | cpy_prng_mt_next(p);
            case CPY_PRNG_PHILOX2X32:
            case CPY_PRNG_PHILOX4X32: {
                uint32_t lo = cpy_prng_philox_next32(p);
                uint32_t hi = cpy_prng_philox_next32(p);
                return ((uint64_t)hi << 32) | lo;
            }
            default: return 0;
        }
    }

    uint32_t cpy_prng_next_u32(void* handle) {
        if (handle == NULL) return 0;
        cpy_prng_state* p = (cpy_prng_state*)handle;
        switch (p->alg) {
            case CPY_PRNG_SPLITMIX64: return (uint32_t)cpy_prng_splitmix(&p->s[0]);
            case CPY_PRNG_PCG32: return cpy_prng_pcg32(p);
            case CPY_PRNG_XOSHIRO256SS: return (uint32_t)cpy_prng_xoshiro(p);
            case CPY_PRNG_MT19937: return cpy_prng_mt_next(p);
            case CPY_PRNG_PHILOX2X32:
            case CPY_PRNG_PHILOX4X32: return cpy_prng_philox_next32(p);
            default: return 0;
        }
    }

    double cpy_prng_next_double(void* handle) {
        return (double)(cpy_prng_next_u64(handle) >> 11) * (1.0 / 9007199254740992.0);
    }

    uint64_t cpy_prng_below(void* handle, uint64_t bound) {
        if (bound == 0) return 0;
        uint64_t threshold = (uint64_t)(0 - bound) % bound;
        uint64_t r = 0;
        do { r = cpy_prng_next_u64(handle); } while (r < threshold);
        return r % bound;
    }

    int cpy_prng_alg(void* handle) {
        return handle ? ((cpy_prng_state*)handle)->alg : 0;
    }

    int cpy_prng_rounds(void* handle) {
        return handle ? ((cpy_prng_state*)handle)->ph_rounds : 0;
    }

    const char* cpy_prng_name(int alg) {
        switch (alg) {
            case 1: return "splitmix64";
            case 2: return "pcg32";
            case 3: return "xoshiro256**";
            case 4: return "mt19937";
            case 5: return "philox2x32";
            case 6: return "philox4x32";
            default: return "unknown";
        }
    }

    void cpy_prng_free(void* handle) {
        if (handle == NULL) return;
        memset(handle, 0, sizeof(cpy_prng_state));
        free(handle);
    }

# ---------------------------------------------------------------------------
# cpy surface
# ---------------------------------------------------------------------------

public def alg_splitmix64() -> int:
    return 1

public def alg_pcg32() -> int:
    return 2

public def alg_xoshiro256ss() -> int:
    return 3

public def alg_mt19937() -> int:
    return 4

public def alg_philox2x32() -> int:
    return 5

public def alg_philox4x32() -> int:
    return 6

# Create a generator with an explicit seed (fully reproducible).
public def prng_new(alg int, seed uint64) -> void*:
    return cpy_prng_new(alg, seed)

# Philox family: rounds are configurable (1..16, clamped; default is 10).
public def prng_new_philox(alg int, seed uint64, rounds int) -> void*:
    return cpy_prng_new_rounds(alg, seed, rounds)

public def prng_new_philox2x32(key uint32, ctr uint64, rounds int) -> void*:
    return cpy_prng_philox_new_exact(
        alg_philox2x32(), key, 0,
        (uint32)ctr, (uint32)(ctr >> 32), 0, 0, rounds)

public def prng_new_philox4x32(key0 uint32, key1 uint32,
                               ctr0 uint32, ctr1 uint32,
                               ctr2 uint32, ctr3 uint32,
                               rounds int) -> void*:
    return cpy_prng_philox_new_exact(
        alg_philox4x32(), key0, key1,
        ctr0, ctr1, ctr2, ctr3, rounds)

# Create a generator seeded from the OS CSPRNG.
public def prng_new_auto(alg int) -> void*:
    return cpy_prng_new(alg, u64())

# Next 64-bit value.
public def prng_next_u64(state void*) -> uint64:
    return cpy_prng_next_u64(state)

# Next 32-bit value.
public def prng_next_u32(state void*) -> uint32:
    return cpy_prng_next_u32(state)

# Next value in [0, 1) with 53 bits of precision.
public def prng_next_double(state void*) -> double:
    return cpy_prng_next_double(state)

# Uniform integer in [0, bound), without modulo bias.
public def prng_below(state void*, bound uint64) -> uint64:
    return cpy_prng_below(state, bound)

# Uniform integer in [lo, hi], inclusive.
public def prng_int_range(state void*, lo int64, hi int64) -> int64:
    if hi < lo:
        return lo
    uint64 span = (uint64)(hi - lo) + 1
    if span == 0:
        return lo
    return lo + (int64)cpy_prng_below(state, span)

# Algorithm id and human-readable name.
public def prng_alg(state void*) -> int:
    return cpy_prng_alg(state)

# Round count for Philox states (10 for other algorithms).
public def prng_rounds(state void*) -> int:
    return cpy_prng_rounds(state)

public def prng_name(alg int) -> str:
    return cpy_prng_name(alg)

# Release the generator state.
public def prng_destroy(state void*) -> void:
    cpy_prng_free(state)
