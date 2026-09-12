import stdlib

# MultiSet / MultiSet: an identity-keyed multiset where each distinct void* element
# carries a multiplicity count. Uses the same open addressing / packed-array
# layout as the other hash collections, with a parallel int count array.
# multi_set_add increments the count of an existing element (or inserts it with
# count 1); bag_remove_one decrements and finally removes it. bag_size is the
# total number of elements (sum of counts); bag_distinct is the number of
# distinct elements. IDENTITY-BASED (raw 64-bit void* value); 64-bit hash.
# Slots: 0=empty, 1=live, 2=tombstone. Mutators return the updated MultiSet.
struct MultiSet:
    void** keys
    int* counts
    int* used
    size_t capacity
    size_t length
    size_t used_count

public def _ms_next_pow2(n size_t) -> size_t:
    size_t p = 8
    while p < n:
        p = p * (size_t)2
    return p

public def create_multi_set(cap size_t) -> MultiSet:
    size_t c = _ms_next_pow2(cap)
    MultiSet b
    b.capacity = c
    b.keys = malloc(c * (size_t)sizeof(void*))
    b.counts = malloc(c * (size_t)sizeof(int))
    b.used = malloc(c * (size_t)sizeof(int))
    b.length = (size_t)0
    b.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        b.used[i] = 0
        b.keys[i] = 0
        b.counts[i] = 0
        i = i + 1
    return b

public def _ms_kveq(a void*, b void*) -> int:
    int eq = 0
    if a == b:
        eq = 1
    return eq

public def _ms_kvhash(key void*) -> size_t:
    size_t a = (size_t)key
    a = a ^ (a >> 33)
    a = a * (size_t)0xff51afd7ed558ccd
    a = a ^ (a >> 33)
    a = a * (size_t)0xc4ceb9fe1a85ec53
    a = a ^ (a >> 33)
    return a

public def _ms_kvwalk(b MultiSet, start size_t, key void*) -> size_t:
    size_t cap = b.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = b.used[idx]
        if st == 0:
            return cap
        if st == 1 and _ms_kveq(b.keys[idx], key) == 1:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

public def _ms_kvfree(b MultiSet, start size_t) -> size_t:
    size_t cap = b.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = b.used[idx]
        if st == 0 or st == 2:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

public def _ms_rehash(b MultiSet, new_cap size_t, key void*, count int, do_set int) -> MultiSet:
    size_t c = _ms_next_pow2(new_cap)
    MultiSet nb
    nb.capacity = c
    nb.keys = malloc(c * (size_t)sizeof(void*))
    nb.counts = malloc(c * (size_t)sizeof(int))
    nb.used = malloc(c * (size_t)sizeof(int))
    nb.length = (size_t)0
    nb.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        nb.used[i] = 0
        nb.keys[i] = 0
        nb.counts[i] = 0
        i = i + 1
    i = 0
    while i < (int)b.capacity:
        if b.used[i] == 1:
            size_t start = _ms_kvhash(b.keys[i]) & (nb.capacity - (size_t)1)
            size_t slot = _ms_kvfree(nb, start)
            nb.keys[slot] = b.keys[i]
            nb.counts[slot] = b.counts[i]
            nb.used[slot] = 1
            nb.length += (size_t)1
            nb.used_count += (size_t)1
        i = i + 1
    if do_set == 1:
        size_t start = _ms_kvhash(key) & (nb.capacity - (size_t)1)
        size_t slot = _ms_kvfree(nb, start)
        nb.keys[slot] = key
        nb.counts[slot] = count
        nb.used[slot] = 1
        nb.length += (size_t)1
        nb.used_count += (size_t)1
    free(b.keys)
    free(b.counts)
    free(b.used)
    return nb

# Add one occurrence of `key`; returns the MultiSet.
public def multi_set_add(b MultiSet, key void*) -> MultiSet:
    size_t cap = b.capacity
    size_t ln = b.length
    size_t uc = b.used_count
    size_t start = _ms_kvhash(key) & (cap - (size_t)1)
    size_t hit = _ms_kvwalk(b, start, key)
    if hit != cap:
        b.counts[hit] += 1
        return b
    size_t grown = (ln + (size_t)1) * (size_t)10
    size_t loadthr = cap * (size_t)7
    size_t upthr = cap * (size_t)9
    if grown >= loadthr or (uc + (size_t)1) * (size_t)10 >= upthr:
        return _ms_rehash(b, cap * (size_t)2, key, 1, 1)
    size_t slot = _ms_kvfree(b, start)
    b.keys[slot] = key
    b.counts[slot] = 1
    b.used[slot] = 1
    b.length = ln + (size_t)1
    b.used_count = uc + (size_t)1
    return b

public def multi_set_contains(b MultiSet, key void*) -> int:
    size_t cap = b.capacity
    size_t start = _ms_kvhash(key) & (cap - (size_t)1)
    size_t hit = _ms_kvwalk(b, start, key)
    int found = 0
    if hit != cap:
        found = 1
    return found

# Multiplicity count for `key` (0 if absent).
public def multi_set_count(b MultiSet, key void*) -> size_t:
    size_t cap = b.capacity
    size_t start = _ms_kvhash(key) & (cap - (size_t)1)
    size_t hit = _ms_kvwalk(b, start, key)
    if hit != cap:
        return (size_t)b.counts[hit]
    return (size_t)0

# Remove one occurrence of `key`; removes the element entirely at zero.
public def multi_set_remove_one(b MultiSet, key void*) -> MultiSet:
    size_t cap = b.capacity
    size_t ln = b.length
    size_t start = _ms_kvhash(key) & (cap - (size_t)1)
    size_t hit = _ms_kvwalk(b, start, key)
    if hit != cap:
        b.counts[hit] -= 1
        if b.counts[hit] <= 0:
            b.used[hit] = 2
            b.counts[hit] = 0
            b.length = ln - (size_t)1
    return b

# Total number of elements (sum of all multiplicities).
public def multi_set_size(b MultiSet) -> size_t:
    size_t cap = b.capacity
    size_t i = 0
    size_t total = (size_t)0
    while i < cap:
        if b.used[i] == 1:
            total = total + (size_t)b.counts[i]
        i = i + (size_t)1
    return total

# Number of distinct elements.
public def multi_set_distinct(b MultiSet) -> size_t:
    return b.length

public def multi_set_is_empty(b MultiSet) -> int:
    int e = 0
    if b.length == (size_t)0:
        e = 1
    return e
