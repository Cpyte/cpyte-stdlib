import stdlib

# IdentitySet / Set: a set of distinct void* elements using open addressing with
# linear probing over packed arrays (same layout as HashMap minus values).
# IDENTITY-BASED: an element is the raw 64-bit void* value; membership is by
# numeric equality of that value, not by pointed-to contents. On 32-bit hosts
# _is_kvhash (a 64-bit finalizer) must be replaced.
# Slots: 0=empty, 1=live, 2=tombstone. length counts live elements,
# used_count counts live + tombstones so tombstones get reclaimed. Mutators
# return the updated set. add() is idempotent: adding an existing element
# returns the set unchanged.
struct IdentitySet:
    void** keys
    int* used
    size_t capacity
    size_t length
    size_t used_count

public def _is_next_pow2(n size_t) -> size_t:
    size_t p = 8
    while p < n:
        p = p * (size_t)2
    return p

public def create_identity_set(cap size_t) -> IdentitySet:
    size_t c = _is_next_pow2(cap)
    IdentitySet s
    s.capacity = c
    s.keys = malloc(c * (size_t)sizeof(void*))
    s.used = malloc(c * (size_t)sizeof(int))
    s.length = (size_t)0
    s.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        s.used[i] = 0
        s.keys[i] = 0
        i = i + 1
    return s

public def _is_kveq(a void*, b void*) -> int:
    int eq = 0
    if a == b:
        eq = 1
    return eq

public def _is_kvhash(key void*) -> size_t:
    size_t a = (size_t)key
    a = a ^ (a >> 33)
    a = a * (size_t)0xff51afd7ed558ccd
    a = a ^ (a >> 33)
    a = a * (size_t)0xc4ceb9fe1a85ec53
    a = a ^ (a >> 33)
    return a

public def _is_kvwalk(s IdentitySet, start size_t, key void*) -> size_t:
    size_t cap = s.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = s.used[idx]
        if st == 0:
            return cap
        if st == 1 and _is_kveq(s.keys[idx], key) == 1:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

public def _is_kvfree(s IdentitySet, start size_t) -> size_t:
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

public def _is_rehash(s IdentitySet, new_cap size_t, key void*, do_set int) -> IdentitySet:
    size_t c = _is_next_pow2(new_cap)
    IdentitySet ns
    ns.capacity = c
    ns.keys = malloc(c * (size_t)sizeof(void*))
    ns.used = malloc(c * (size_t)sizeof(int))
    ns.length = (size_t)0
    ns.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        ns.used[i] = 0
        ns.keys[i] = 0
        i = i + 1
    i = 0
    while i < (int)s.capacity:
        if s.used[i] == 1:
            size_t start = _is_kvhash(s.keys[i]) & (ns.capacity - (size_t)1)
            size_t slot = _is_kvfree(ns, start)
            ns.keys[slot] = s.keys[i]
            ns.used[slot] = 1
            ns.length += (size_t)1
            ns.used_count += (size_t)1
        i = i + 1
    if do_set == 1:
        size_t start = _is_kvhash(key) & (ns.capacity - (size_t)1)
        size_t slot = _is_kvfree(ns, start)
        ns.keys[slot] = key
        ns.used[slot] = 1
        ns.length += (size_t)1
        ns.used_count += (size_t)1
    free(s.keys)
    free(s.used)
    return ns

# Add an element. Idempotent: returns the set unchanged if present.
public def identity_set_add(s IdentitySet, key void*) -> IdentitySet:
    size_t cap = s.capacity
    size_t ln = s.length
    size_t uc = s.used_count
    size_t start = _is_kvhash(key) & (cap - (size_t)1)
    size_t hit = _is_kvwalk(s, start, key)
    if hit != cap:
        return s
    size_t grown = (ln + (size_t)1) * (size_t)10
    size_t loadthr = cap * (size_t)7
    size_t upthr = cap * (size_t)9
    if grown >= loadthr or (uc + (size_t)1) * (size_t)10 >= upthr:
        return _is_rehash(s, cap * (size_t)2, key, 1)
    size_t slot = _is_kvfree(s, start)
    s.keys[slot] = key
    s.used[slot] = 1
    s.length = ln + (size_t)1
    s.used_count = uc + (size_t)1
    return s

public def identity_set_contains(s IdentitySet, key void*) -> int:
    size_t cap = s.capacity
    size_t start = _is_kvhash(key) & (cap - (size_t)1)
    size_t hit = _is_kvwalk(s, start, key)
    int found = 0
    if hit != cap:
        found = 1
    return found

# Remove an element (marks a tombstone); returns the set.
public def identity_set_remove(s IdentitySet, key void*) -> IdentitySet:
    size_t cap = s.capacity
    size_t ln = s.length
    size_t start = _is_kvhash(key) & (cap - (size_t)1)
    size_t hit = _is_kvwalk(s, start, key)
    if hit != cap:
        s.used[hit] = 2
        s.length = ln - (size_t)1
    return s

public def identity_set_size(s IdentitySet) -> size_t:
    return s.length

public def identity_set_is_empty(s IdentitySet) -> int:
    int e = 0
    if s.length == (size_t)0:
        e = 1
    return e
