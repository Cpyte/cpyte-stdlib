#include "hashmap.h"
#include "hashmap_internal.h"

#include <stdlib.h>
#include <string.h>

#if !defined(HASHMAP_DISABLE_SIMD)

#  if defined(__aarch64__)
#    include <arm_neon.h>
#  elif defined(__x86_64__) || defined(__i386__) || defined(_M_X64) || defined(_M_IX86)
#    include <emmintrin.h>
#    if defined(__GNUC__) || defined(__clang__)
#      include <immintrin.h>
#    endif
#  endif

#endif

#if defined(__GNUC__) || defined(__clang__)
#  define HASHMAP_MAYBE_UNUSED __attribute__((unused))
#else
#  define HASHMAP_MAYBE_UNUSED
#endif

#if defined(__GNUC__) || defined(__clang__)
#  define HASHMAP_TARGET_SSE2 __attribute__((target("sse2")))
#  define HASHMAP_TARGET_AVX2 __attribute__((target("avx2")))
#else
#  define HASHMAP_TARGET_SSE2
#  define HASHMAP_TARGET_AVX2
#endif

HASHMAP_MAYBE_UNUSED
static uint32_t
fnv1a(const char *s, size_t len)
{
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        h ^= (unsigned char)s[i];
        h *= 16777619u;
    }
    return h;
}

static inline uint64_t
hash_key(const char *key)
{
    uint64_t h = 14695981039346656037ULL;

    for (const unsigned char *p = (const unsigned char *)key; *p != '\0'; p++) {
        h ^= (uint64_t)*p;
        h *= 1099511628211ULL;
    }

    return h;
}

static inline uint8_t
hash_fingerprint(uint64_t hash)
{
    return (uint8_t)((hash >> 57) & 0x7F);
}

static inline size_t
home_group(uint64_t hash, size_t capacity)
{
    size_t h1 = (size_t)(hash >> 7);

    size_t slot = (capacity != 0 && (capacity & (capacity - 1)) == 0)
                      ? h1 & (capacity - 1)
                      : h1 % capacity;

    return slot & ~((size_t)GROUP_SIZE - 1);
}

static inline unsigned
lowest_set_bit(uint32_t mask)
{
#if defined(__GNUC__) || defined(__clang__)
    return (unsigned)__builtin_ctz(mask);
#else
    unsigned bit = 0;
    while (((mask >> bit) & 1u) == 0)
        bit++;
    return bit;
#endif
}

HashMap
create_hashmap(size_t cap)
{
    cap = round_up_pow2(cap);

    HashMap map = {
        .control = calloc(cap, sizeof(uint8_t)),
        .entries = calloc(cap, sizeof(HashEntry)),
        .capacity = cap,
        .length = 0
    };

    if (!map.control || !map.entries) {
        free(map.control);
        free(map.entries);

        map.control = NULL;
        map.entries = NULL;
        map.capacity = 0;

        return map;
    }

    memset(map.control, HASHMAP_EMPTY, cap);

    return map;
}

void
hashmap_destroy(HashMap *map)
{
    free(map->control);
    free(map->entries);

    map->control = NULL;
    map->entries = NULL;
    map->capacity = 0;
    map->length = 0;
}

#if !defined(HASHMAP_DISABLE_SIMD) && (defined(__SSE2__) || defined(_M_X64))

HASHMAP_MAYBE_UNUSED
HASHMAP_TARGET_SSE2
static uint32_t
match_fp_sse2(const uint8_t *control, uint8_t fingerprint)
{
    __m128i group  = _mm_loadu_si128((const __m128i *)control);
    __m128i target = _mm_set1_epi8((char)fingerprint);

    return (uint32_t)_mm_movemask_epi8(_mm_cmpeq_epi8(group, target));
}

#  if GROUP_SIZE == 32
HASHMAP_MAYBE_UNUSED
HASHMAP_TARGET_SSE2
static uint32_t
match_fp_sse2_wide(const uint8_t *control, uint8_t fingerprint)
{
    return match_fp_sse2(control, fingerprint) |
           (match_fp_sse2(control + 16, fingerprint) << 16);
}
#  endif

#endif

#if !defined(HASHMAP_DISABLE_SIMD) && GROUP_SIZE == 32 && \
    (defined(__AVX2__) || \
     ((defined(__GNUC__) || defined(__clang__)) && \
      (defined(__x86_64__) || defined(_M_X64))))

HASHMAP_MAYBE_UNUSED
HASHMAP_TARGET_AVX2
static uint32_t
match_fp_avx2(const uint8_t *control, uint8_t fingerprint)
{
    __m256i group  = _mm256_loadu_si256((const __m256i *)control);
    __m256i target = _mm256_set1_epi8((char)fingerprint);

    return (uint32_t)_mm256_movemask_epi8(_mm256_cmpeq_epi8(group, target));
}

#endif

#if !defined(HASHMAP_DISABLE_SIMD) && defined(__aarch64__)
HASHMAP_MAYBE_UNUSED
static uint32_t
match_fp_neon(const uint8_t *control, uint8_t fingerprint)
{
    uint8x16_t group    = vld1q_u8(control);
    uint8x16_t target   = vdupq_n_u8(fingerprint);
    uint8x16_t equality = vceqq_u8(group, target);

    const uint8x16_t weights = {
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
    };

    uint8x16_t folded = vandq_u8(equality, weights);
    folded = vpaddq_u8(folded, folded);
    folded = vpaddq_u8(folded, folded);
    folded = vpaddq_u8(folded, folded);

    return vgetq_lane_u16(vreinterpretq_u16_u8(folded), 0);
}
#endif

#if defined(HASHMAP_MULTIARCH) && (defined(__x86_64__) || defined(_M_X64))
HASHMAP_MAYBE_UNUSED
static uint32_t
match_fp_scalar_wide(const uint8_t *control, uint8_t fingerprint)
{
    return match_fp_scalar(control, fingerprint, GROUP_SIZE);
}
#endif

uint32_t
match_fingerprint(const uint8_t *control, uint8_t fingerprint)
{
#if defined(HASHMAP_DISABLE_SIMD)
    return match_fp_scalar(control, fingerprint, GROUP_SIZE);
#elif defined(HASHMAP_MULTIARCH) && (defined(__x86_64__) || defined(_M_X64))
    static uint32_t (*matcher)(const uint8_t *, uint8_t);

    if (matcher == NULL) {
        __builtin_cpu_init();

        if (__builtin_cpu_supports("avx2"))
            matcher = match_fp_avx2;
        else if (__builtin_cpu_supports("sse2"))
            matcher = match_fp_sse2_wide;
        else
            matcher = match_fp_scalar_wide;
    }

    return matcher(control, fingerprint);
#elif GROUP_SIZE == 32
    return match_fp_avx2(control, fingerprint);
#elif defined(__aarch64__)
    return match_fp_neon(control, fingerprint);
#elif defined(__SSE2__) || defined(_M_X64)
    return match_fp_sse2(control, fingerprint);
#else
    return match_fp_scalar(control, fingerprint, GROUP_SIZE);
#endif
}

static uint32_t
match_group(const uint8_t *control, uint8_t fingerprint, size_t width)
{
    if (width == GROUP_SIZE)
        return match_fingerprint(control, fingerprint);

    return match_fp_scalar(control, fingerprint, width);
}

size_t hashmap_find(const HashMap *map, const char *key)
{
    if (map == NULL || map->capacity == 0 || map->control == NULL)
        return HASHMAP_NOT_FOUND;

    uint64_t hash   = hash_key(key);
    uint8_t  fp     = hash_fingerprint(hash);
    size_t   origin = home_group(hash, map->capacity);
    size_t   offset = 0;

    for (size_t step = 0; step < map->capacity / GROUP_SIZE; step++) {
        size_t group = (origin + offset) % map->capacity;
        offset += (step + 1) * GROUP_SIZE;

        const uint8_t *control = map->control + group;
        size_t width = MIN(GROUP_SIZE, map->capacity - group);

        uint32_t candidates = match_group(control, fp, width);

        while (candidates != 0) {
            unsigned bit = lowest_set_bit(candidates);
            candidates &= candidates - 1;

            HashEntry *entry = &map->entries[group + bit];
            if (entry->key != NULL && strcmp(entry->key, key) == 0)
                return group + bit;
        }

        if (match_group(control, HASHMAP_EMPTY, width) != 0)
            return HASHMAP_NOT_FOUND;
    }

    return HASHMAP_NOT_FOUND;
}

static size_t
insert_entry(HashMap *map, const char *key, void *value, uint64_t hash)
{
    uint8_t  fp     = hash_fingerprint(hash);
    size_t   origin = home_group(hash, map->capacity);
    size_t   offset = 0;
    size_t   tombstone = HASHMAP_NOT_FOUND;

    for (size_t step = 0; step < map->capacity / GROUP_SIZE; step++) {
        size_t group = (origin + offset) % map->capacity;
        offset += (step + 1) * GROUP_SIZE;

        const uint8_t *control = map->control + group;
        size_t width = MIN(GROUP_SIZE, map->capacity - group);

        uint32_t candidates = match_group(control, fp, width);

        while (candidates != 0) {
            unsigned bit = lowest_set_bit(candidates);
            candidates &= candidates - 1;

            HashEntry *entry = &map->entries[group + bit];
            if (entry->key != NULL && strcmp(entry->key, key) == 0) {
                entry->value = value;
                return group + bit;
            }
        }

        uint32_t deleted = match_group(control, HASHMAP_DELETED, width);
        if (deleted != 0 && tombstone == HASHMAP_NOT_FOUND)
            tombstone = group + lowest_set_bit(deleted);

        uint32_t empties = match_group(control, HASHMAP_EMPTY, width);
        if (empties != 0) {
            size_t slot = (tombstone != HASHMAP_NOT_FOUND)
                              ? tombstone
                              : group + lowest_set_bit(empties);

            map->control[slot]  = fp;
            map->entries[slot]  = (HashEntry){ key, value };
            map->length++;

            return slot;
        }
    }

    if (tombstone != HASHMAP_NOT_FOUND) {
        map->control[tombstone] = fp;
        map->entries[tombstone] = (HashEntry){ key, value };
        map->length++;

        return tombstone;
    }

    return HASHMAP_NOT_FOUND;
}

int
hashmap_resize(HashMap *map, size_t new_capacity)
{
    if (map == NULL || map->control == NULL)
        return -1;

    new_capacity = round_up_pow2(new_capacity);

    if (new_capacity == map->capacity)
        return 0;

    uint8_t *control = calloc(new_capacity, sizeof(uint8_t));
    HashEntry *entries = calloc(new_capacity, sizeof(HashEntry));

    if (!control || !entries) {
        free(control);
        free(entries);

        return -1;
    }

    memset(control, HASHMAP_EMPTY, new_capacity);

    HashMap grown = {
        .control = control,
        .entries = entries,
        .capacity = new_capacity,
        .length = 0
    };

    for (size_t i = 0; i < map->capacity; i++) {
        if (map->control[i] != HASHMAP_EMPTY &&
            map->control[i] != HASHMAP_DELETED) {
            insert_entry(&grown, map->entries[i].key, map->entries[i].value,
                         hash_key(map->entries[i].key));
        }
    }

    free(map->control);
    free(map->entries);

    *map = grown;

    return 0;
}

size_t
hashmap_insert(HashMap *map, const char *key, void *value)
{
    if (map == NULL || map->control == NULL || key == NULL)
        return HASHMAP_NOT_FOUND;

    if ((map->length + 1) * 8 > map->capacity * 7) {
        if (hashmap_resize(map, map->capacity * 2) != 0 &&
            map->length >= map->capacity) {
            return HASHMAP_NOT_FOUND;
        }
    }

    return insert_entry(map, key, value, hash_key(key));
}

int
hashmap_get(const HashMap *map, const char *key, void **value_out)
{
    size_t index = hashmap_find(map, key);

    if (index == HASHMAP_NOT_FOUND)
        return -1;

    if (value_out != NULL)
        *value_out = map->entries[index].value;

    return 0;
}

int
hashmap_erase(HashMap *map, const char *key)
{
    size_t index = hashmap_find(map, key);

    if (index == HASHMAP_NOT_FOUND)
        return -1;

    map->control[index]       = HASHMAP_DELETED;
    map->entries[index].key   = NULL;
    map->entries[index].value = NULL;
    map->length--;

    return 0;
}
