#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "hashmap.h"
#include "hashmap_internal.h"

static uint32_t rng_state = 0x12345678u;

static uint32_t
rng(void)
{
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state >> 8;
}

/*
 * Differential test: whatever SIMD backend match_fingerprint dispatches
 * to (NEON on arm64, SSE2/AVX2 elsewhere) must agree bit-for-bit with
 * the scalar reference mask.
 */
static void
test_mask_equivalence(void)
{
    uint8_t buf[GROUP_SIZE];

    for (int iter = 0; iter < 200000; iter++) {
        for (size_t i = 0; i < GROUP_SIZE; i++)
            buf[i] = (uint8_t)rng();

        uint8_t fp = (uint8_t)(rng() & 0x7F);
        if ((rng() & 3u) == 0)
            buf[rng() % GROUP_SIZE] = fp;

        uint32_t fast = match_fingerprint(buf, fp);
        uint32_t slow = match_fp_scalar(buf, fp, GROUP_SIZE);

        assert(fast == slow);
    }
}

static void
test_boundaries(void)
{
    assert(round_up_pow2(0) == GROUP_SIZE);
    assert(round_up_pow2(1) == GROUP_SIZE);
    assert(round_up_pow2(GROUP_SIZE - 1) == GROUP_SIZE);
    assert(round_up_pow2(GROUP_SIZE + 1) == GROUP_SIZE * 2);
    assert(round_up_pow2((size_t)1 << (sizeof(size_t) * 8 - 1)) ==
           (size_t)1 << (sizeof(size_t) * 8 - 1));

    HashMap empty = create_hashmap(0);
    assert(empty.capacity == GROUP_SIZE);
    void *v;
    assert(hashmap_get(&empty, "anything", &v) == -1);
    hashmap_destroy(&empty);

    HashMap nullmap = { 0 };
    assert(hashmap_get(&nullmap, "x", &v) == -1);
}

static void
test_system(void)
{
    HashMap m = create_hashmap(64);
    assert(m.capacity == 64);
    assert(m.control[0] == HASHMAP_EMPTY && m.control[63] == HASHMAP_EMPTY);

    enum { N = 5000 };
    static char keys[N][16];
    static char values[N];

    for (int i = 0; i < N; i++) {
        snprintf(keys[i], sizeof(keys[i]), "k%d", i);
        values[i] = (char)i;
    }

    for (int i = 0; i < N; i++) {
        size_t at = hashmap_insert(&m, keys[i], &values[i]);
        assert(at != HASHMAP_NOT_FOUND);
    }
    assert(m.capacity >= (size_t)N && m.length == N);

    for (int i = 0; i < N; i++) {
        void *v;
        assert(hashmap_get(&m, keys[i], &v) == 0 && v == &values[i]);
    }

    void *v;
    assert(hashmap_get(&m, "nope", &v) == -1);

    static char updated = 'X';
    size_t before = m.length;
    hashmap_insert(&m, "k7", &updated);
    assert(m.length == before);
    assert(hashmap_get(&m, "k7", &v) == 0 && v == &updated);

    /* stored NULL is not a missing key */
    assert(hashmap_get(&m, "k9", &v) == 0 && v != NULL);
    assert(hashmap_insert(&m, "nullkey", NULL) != HASHMAP_NOT_FOUND);
    assert(hashmap_get(&m, "nullkey", &v) == 0 && v == NULL);
    assert(hashmap_erase(&m, "nullkey") == 0);
    assert(hashmap_get(&m, "nullkey", &v) == -1);

    int erased = 0;
    for (int i = 0; i < N; i += 2) {
        assert(hashmap_erase(&m, keys[i]) == 0);
        erased++;
    }
    assert(m.length == (size_t)(N - erased));
    assert(hashmap_erase(&m, "k0") == -1);

    for (int i = 0; i < N; i += 2)
        assert(hashmap_get(&m, keys[i], &v) == -1);
    for (int i = 1; i < N; i += 2)
        assert(hashmap_get(&m, keys[i], &v) == 0 &&
               v == (i == 7 ? &updated : &values[i]));

    for (int i = 0; i < N; i += 4) {
        size_t at = hashmap_insert(&m, keys[i], &values[i]);
        assert(at != HASHMAP_NOT_FOUND);
        assert(hashmap_get(&m, keys[i], &v) == 0 && v == &values[i]);
    }

    HashMap tiny = create_hashmap(1);
    assert(tiny.capacity == GROUP_SIZE);
    hashmap_destroy(&tiny);

    hashmap_destroy(&m);
}

int
main(void)
{
    test_mask_equivalence();
    test_boundaries();
    test_system();
    printf("all tests passed\n");
    return 0;
}
