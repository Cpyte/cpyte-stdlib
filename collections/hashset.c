#include "hashset.h"

#include <stddef.h>

HashSet
hashset_create(size_t cap)
{
    HashSet set = { create_hashmap(cap) };
    return set;
}

void
hashset_destroy(HashSet *set)
{
    if (set == NULL)
        return;

    hashmap_destroy(&set->map);
}

size_t
hashset_insert(HashSet *set, const char *key)
{
    if (set == NULL)
        return HASHMAP_NOT_FOUND;

    return hashmap_insert(&set->map, key, NULL);
}

int
hashset_contains(const HashSet *set, const char *key)
{
    if (set == NULL)
        return 0;

    return hashmap_find(&set->map, key) != HASHMAP_NOT_FOUND;
}

int
hashset_erase(HashSet *set, const char *key)
{
    if (set == NULL)
        return -1;

    return hashmap_erase(&set->map, key);
}

size_t
hashset_length(const HashSet *set)
{
    if (set == NULL)
        return 0;

    return set->map.length;
}
