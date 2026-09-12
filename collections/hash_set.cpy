import stdlib
import "mem.cpy"

# HashSet / Set: a set of distinct void* elements using open addressing with
# linear probing over packed arrays (same layout as HashMap minus values).
# IDENTITY-BASED: an element is the raw 64-bit void* value; membership is by
# numeric equality of that value, not by pointed-to contents. On 32-bit hosts
# _hs_kvhash (a 64-bit finalizer) must be replaced.
# Slots: 0=empty, 1=live, 2=tombstone. length counts live elements,
# used_count counts live + tombstones so tombstones get reclaimed. Mutators
# return the updated set. add() is idempotent: adding an existing element
# returns the set unchanged.
struct HashSet:
    void** keys
    int* used
    char* slab
    size_t capacity
    size_t length
    size_t used_count

public def _hs_next_pow2(n size_t) -> size_t:
    size_t p = 8
    while p < n:
        p = p * (size_t)2
    return p

public def _hs_init_table(s HashSet, c size_t) -> HashSet:
    # One aligned slab for keys/used: single malloc, adjacent arrays.
    size_t uoff = c * (size_t)8
    size_t total = uoff + c * (size_t)4
    char* slab = (char*)malloc(total)
    s.slab = slab
    s.keys = (void**)(slab + (int)0)
    s.used = (int*)(slab + (int)uoff)
    s.length = (size_t)0
    s.used_count = (size_t)0
    buf_zero((void*)s.keys, c * (size_t)8)
    buf_zero((void*)s.used, c * (size_t)4)
    return s

public def create_hashset(cap size_t) -> HashSet:
    size_t c = _hs_next_pow2(cap)
    HashSet s
    s.capacity = c
    return _hs_init_table(s, c)

public def _hs_kveq(a void*, b void*) -> int:
    int eq = 0
    if a == b:
        eq = 1
    return eq

public def _hs_kvhash(key void*) -> size_t:
    size_t a = (size_t)key
    a = a ^ (a >> 33)
    a = a * (size_t)0xff51afd7ed558ccd
    a = a ^ (a >> 33)
    a = a * (size_t)0xc4ceb9fe1a85ec53
    a = a ^ (a >> 33)
    return a

public def _hs_kvwalk(s HashSet, start size_t, key void*) -> size_t:
    size_t cap = s.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = s.used[idx]
        if st == 0:
            return cap
        if st == 1 and _hs_kveq(s.keys[idx], key) == 1:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

public def _hs_kvfree(s HashSet, start size_t) -> size_t:
    size_t cap = s.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = s.used[idx]
        if st == 0 or st == 2:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

public def _hs_rehash(s HashSet, new_cap size_t, key void*, do_set int) -> HashSet:
    size_t c = _hs_next_pow2(new_cap)
    HashSet ns
    ns.capacity = c
    ns = _hs_init_table(ns, c)
    int i = 0
    while i < (int)s.capacity:
        if s.used[i] == 1:
            size_t start = _hs_kvhash(s.keys[i]) & (ns.capacity - (size_t)1)
            size_t slot = _hs_kvfree(ns, start)
            ns.keys[slot] = s.keys[i]
            ns.used[slot] = 1
            ns.length += (size_t)1
            ns.used_count += (size_t)1
        i = i + 1
    if do_set == 1:
        size_t start = _hs_kvhash(key) & (ns.capacity - (size_t)1)
        size_t slot = _hs_kvfree(ns, start)
        ns.keys[slot] = key
        ns.used[slot] = 1
        ns.length += (size_t)1
        ns.used_count += (size_t)1
    free((void*)s.slab)
    return ns

# Add an element. Idempotent: returns the set unchanged if present.
public def hashset_add(s HashSet, key void*) -> HashSet:
    size_t cap = s.capacity
    size_t ln = s.length
    size_t uc = s.used_count
    size_t start = _hs_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hs_kvwalk(s, start, key)
    if hit != cap:
        return s
    size_t grown = (ln + (size_t)1) * (size_t)10
    size_t loadthr = cap * (size_t)7
    size_t upthr = cap * (size_t)9
    if grown >= loadthr or (uc + (size_t)1) * (size_t)10 >= upthr:
        return _hs_rehash(s, cap * (size_t)2, key, 1)
    size_t slot = _hs_kvfree(s, start)
    s.keys[slot] = key
    s.used[slot] = 1
    s.length = ln + (size_t)1
    s.used_count = uc + (size_t)1
    return s

public def hashset_contains(s HashSet, key void*) -> int:
    size_t cap = s.capacity
    size_t start = _hs_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hs_kvwalk(s, start, key)
    int found = 0
    if hit != cap:
        found = 1
    return found

# Remove an element (marks a tombstone); returns the set.
public def hashset_remove(s HashSet, key void*) -> HashSet:
    size_t cap = s.capacity
    size_t ln = s.length
    size_t start = _hs_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hs_kvwalk(s, start, key)
    if hit != cap:
        s.used[hit] = 2
        s.length = ln - (size_t)1
    return s

public def hashset_size(s HashSet) -> size_t:
    return s.length

public def hashset_is_empty(s HashSet) -> int:
    int e = 0
    if s.length == (size_t)0:
        e = 1
    return e
