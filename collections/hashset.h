#ifndef WEW_COLLECTIONS_HASHSET_H
#define WEW_COLLECTIONS_HASHSET_H

#include <stddef.h>

#include "hashmap.h"

/*
 * HashSet: keys only. Inherits the HashMap ownership contract:
 * stored key strings are borrowed pointers and must remain valid
 * and unmodified while present in the set.
 */
typedef struct {
    HashMap map;
} HashSet;

HashSet hashset_create(size_t cap);

void hashset_destroy(HashSet *set);

/* returns slot index or HASHMAP_NOT_FOUND; duplicate insert is a no-op */
size_t hashset_insert(HashSet *set, const char *key);

/* 1 = present, 0 = absent */
int hashset_contains(const HashSet *set, const char *key);

/* 0 = erased, -1 = absent */
int hashset_erase(HashSet *set, const char *key);

size_t hashset_length(const HashSet *set);

#endif
