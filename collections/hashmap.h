#ifndef WEW_COLLECTIONS_HASHMAP_H
#define WEW_COLLECTIONS_HASHMAP_H

#include <stddef.h>
#include <stdint.h>

#define HASHMAP_EMPTY     0x80
#define HASHMAP_DELETED   0xFE
#define HASHMAP_NOT_FOUND SIZE_MAX

/*
 * Ownership contract: keys and values are stored by pointer and are
 * never copied. The caller must keep key strings valid and unmodified
 * for as long as they remain in the map; mutating or freeing a stored
 * key invalidates the map. hashmap_resize relocates entries but never
 * copies key storage. Stored values may be NULL (use the hashmap_get
 * out-parameter to tell a missing key from a stored NULL).
 */
typedef struct {
    const char *key;
    void *value;
} HashEntry;

typedef struct {
    uint8_t *control;
    HashEntry *entries;

    size_t capacity;
    size_t length;
} HashMap;

/* capacity is rounded up to a power of two; zero-initialize check via capacity == 0 on alloc failure */
HashMap create_hashmap(size_t cap);

void hashmap_destroy(HashMap *map);

/* returns slot index or HASHMAP_NOT_FOUND; re-inserting a key updates its value */
size_t hashmap_insert(HashMap *map, const char *key, void *value);

/* 0 = found (*value_out set, may be NULL), -1 = missing */
int hashmap_get(const HashMap *map, const char *key, void **value_out);

/* returns slot index or HASHMAP_NOT_FOUND */
size_t hashmap_find(const HashMap *map, const char *key);

/* 0 = erased (slot becomes a tombstone), -1 = missing */
int hashmap_erase(HashMap *map, const char *key);

/* 0 = ok, -1 = allocation failure; capacity is rounded up to a power of two */
int hashmap_resize(HashMap *map, size_t new_capacity);

#endif
