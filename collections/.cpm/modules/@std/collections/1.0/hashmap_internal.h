#ifndef WEW_COLLECTIONS_HASHMAP_INTERNAL_H
#define WEW_COLLECTIONS_HASHMAP_INTERNAL_H

/*
 * Private internals shared between hashmap.c and the module tests.
 * Not part of the public API; do not include from application code.
 */

#include <stddef.h>
#include <stdint.h>

#include "hashmap.h"

#if !defined(HASHMAP_DISABLE_SIMD) && \
    (defined(__AVX2__) || \
     (defined(HASHMAP_MULTIARCH) && (defined(__x86_64__) || defined(_M_X64))))
#  define GROUP_SIZE 32
#else
#  define GROUP_SIZE 16
#endif

#ifndef MIN
#  define MIN(a, b) (((a) < (b)) ? (a) : (b))
#endif

uint32_t match_fingerprint(const uint8_t *control, uint8_t fingerprint);

static inline uint32_t
match_fp_scalar(const uint8_t *control, uint8_t fingerprint, size_t width)
{
    uint32_t mask = 0;

    for (size_t i = 0; i < width; i++) {
        mask |= (uint32_t)(control[i] == fingerprint) << i;
    }

    return mask;
}

static inline size_t
round_up_pow2(size_t n)
{
    const size_t max = (size_t)1 << (sizeof(size_t) * 8 - 1);

    if (n <= GROUP_SIZE)
        return GROUP_SIZE;

    if (n >= max)
        return max;

    size_t p = GROUP_SIZE;
    while (p < n)
        p <<= 1;

    return p;
}

#endif
