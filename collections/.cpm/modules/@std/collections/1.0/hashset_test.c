#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "hashset.h"
#include "hashmap_internal.h"

static void
test_system(void)
{
    HashSet s = hashset_create(16);
    assert(s.map.capacity == 16);
    assert(hashset_length(&s) == 0);

    enum { N = 3000 };
    static char keys[N][12];

    for (int i = 0; i < N; i++)
        snprintf(keys[i], sizeof(keys[i]), "e%d", i);

    for (int i = 0; i < N; i++) {
        size_t at = hashset_insert(&s, keys[i]);
        assert(at != HASHMAP_NOT_FOUND);
    }
    assert(hashset_length(&s) == N);
    assert(s.map.capacity >= (size_t)N);

    for (int i = 0; i < N; i++)
        assert(hashset_contains(&s, keys[i]) == 1);
    assert(hashset_contains(&s, "absent") == 0);

    /* duplicate insert is a no-op */
    size_t before = hashset_length(&s);
    assert(hashset_insert(&s, "e7") != HASHMAP_NOT_FOUND);
    assert(hashset_length(&s) == before);
    assert(hashset_contains(&s, "e7") == 1);

    int erased = 0;
    for (int i = 0; i < N; i += 3) {
        assert(hashset_erase(&s, keys[i]) == 0);
        erased++;
    }
    assert(hashset_length(&s) == (size_t)(N - erased));
    assert(hashset_erase(&s, "e0") == -1);
    assert(hashset_contains(&s, "e0") == 0);

    for (int i = 1; i < N; i += 3)
        assert(hashset_contains(&s, keys[i]) == 1);

    /* reinsert after erase */
    assert(hashset_insert(&s, "e6") != HASHMAP_NOT_FOUND);
    assert(hashset_contains(&s, "e6") == 1);

    hashset_destroy(&s);
}

static void
test_boundaries(void)
{
    HashSet empty = hashset_create(0);
    assert(empty.map.capacity == GROUP_SIZE);
    assert(hashset_contains(&empty, "x") == 0);
    assert(hashset_erase(&empty, "x") == -1);
    hashset_destroy(&empty);

    assert(hashset_contains(NULL, "x") == 0);
    assert(hashset_erase(NULL, "x") == -1);
    assert(hashset_length(NULL) == 0);

    HashSet nullmap = { .map = { 0 } };
    assert(hashset_insert(&nullmap, "x") == HASHMAP_NOT_FOUND);
    assert(hashset_contains(&nullmap, "x") == 0);
}

int
main(void)
{
    test_system();
    test_boundaries();
    printf("all tests passed\n");
    return 0;
}
