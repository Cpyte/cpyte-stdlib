import stdlib

# MultiMap: a type-agnostic key -> (many values) table using the same open
# addressing / packed-array layout as HashMap, except that inserting a key
# that already exists does NOT replace — it appends another (key, value) pair.
# Each live slot is one key->value association; a key may occupy several live
# slots. All associations for one key hash to the same probe start, but linear
# probing can scatter them anywhere in that cluster and interleave them with
# entries from other colliding keys, so lookups scan the whole cluster from
# the shared start.
# IDENTITY-BASED keys (raw 64-bit void* value). 64-bit hash assumed.
# Slots: 0=empty, 1=live, 2=tombstone. length = number of associations
# (live slots), distinct = number of keys with >=1 live association,
# used_count = live + tombstones. Mutators return the updated MultiMap.
struct MultiMap:
    void** keys
    void** values
    int* used
    size_t capacity
    size_t length
    size_t distinct
    size_t used_count

public def _mm_next_pow2(n size_t) -> size_t:
    size_t p = 8
    while p < n:
        p = p * (size_t)2
    return p

public def create_multimap(cap size_t) -> MultiMap:
    size_t c = _mm_next_pow2(cap)
    MultiMap m
    m.capacity = c
    m.keys = malloc(c * (size_t)sizeof(void*))
    m.values = malloc(c * (size_t)sizeof(void*))
    m.used = malloc(c * (size_t)sizeof(int))
    m.length = (size_t)0
    m.distinct = (size_t)0
    m.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        m.used[i] = 0
        m.keys[i] = 0
        m.values[i] = 0
        i = i + 1
    return m

public def _mm_kveq(a void*, b void*) -> int:
    int eq = 0
    if a == b:
        eq = 1
    return eq

public def _mm_kvhash(key void*) -> size_t:
    size_t a = (size_t)key
    a = a ^ (a >> 33)
    a = a * (size_t)0xff51afd7ed558ccd
    a = a ^ (a >> 33)
    a = a * (size_t)0xc4ceb9fe1a85ec53
    a = a ^ (a >> 33)
    return a

# First free (empty or tombstone) slot in the cluster starting at `start`.
public def _mm_kvfree(m MultiMap, start size_t) -> size_t:
    size_t cap = m.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0 or st == 2:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

# Does any live slot in the cluster hold `key`? 1 if yes, 0 otherwise.
public def _kvhas(m MultiMap, start size_t, key void*) -> int:
    size_t cap = m.capacity
    size_t idx = start
    int stop = 0
    int found = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            return found
        if st == 1 and _mm_kveq(m.keys[idx], key) == 1:
            found = 1
            return found
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return found
    return found

public def _mm_rehash(m MultiMap, new_cap size_t, key void*, value void*, do_set int) -> MultiMap:
    size_t c = _mm_next_pow2(new_cap)
    MultiMap nm
    nm.capacity = c
    nm.keys = malloc(c * (size_t)sizeof(void*))
    nm.values = malloc(c * (size_t)sizeof(void*))
    nm.used = malloc(c * (size_t)sizeof(int))
    nm.length = (size_t)0
    nm.distinct = (size_t)0
    nm.used_count = (size_t)0
    int i = 0
    while i < (int)c:
        nm.used[i] = 0
        nm.keys[i] = 0
        nm.values[i] = 0
        i = i + 1
    i = 0
    while i < (int)m.capacity:
        if m.used[i] == 1:
            size_t start = _mm_kvhash(m.keys[i]) & (nm.capacity - (size_t)1)
            # was m.keys[i] already placed into nm? (distinct keys only counted once)
            int placed = _kvhas(nm, start, m.keys[i])
            size_t slot = _mm_kvfree(nm, start)
            nm.keys[slot] = m.keys[i]
            nm.values[slot] = m.values[i]
            nm.used[slot] = 1
            nm.length += (size_t)1
            nm.used_count += (size_t)1
            if placed == 0:
                nm.distinct += (size_t)1
        i = i + 1
    if do_set == 1:
        size_t start = _mm_kvhash(key) & (nm.capacity - (size_t)1)
        int placed = _kvhas(nm, start, key)
        size_t slot = _mm_kvfree(nm, start)
        nm.keys[slot] = key
        nm.values[slot] = value
        nm.used[slot] = 1
        nm.length += (size_t)1
        nm.used_count += (size_t)1
        if placed == 0:
            nm.distinct += (size_t)1
    free(m.keys)
    free(m.values)
    free(m.used)
    return nm

# Append a (key, value) association. Unlike a HashMap, this never replaces;
# a duplicate key adds another value under the same key.
public def multi_put(m MultiMap, key void*, value void*) -> MultiMap:
    size_t cap = m.capacity
    size_t ln = m.length
    size_t uc = m.used_count
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    size_t grown = (ln + (size_t)1) * (size_t)10
    size_t loadthr = cap * (size_t)7
    size_t usedthr = cap * (size_t)9
    if grown >= loadthr or (uc + (size_t)1) * (size_t)10 >= usedthr:
        return _mm_rehash(m, cap * (size_t)2, key, value, 1)
    # A fresh key (no live association yet) bumps the distinct-key count.
    int fresh = 0
    if _kvhas(m, start, key) == 0:
        fresh = 1
    size_t slot = _mm_kvfree(m, start)
    m.keys[slot] = key
    m.values[slot] = value
    m.used[slot] = 1
    m.length = ln + (size_t)1
    m.used_count = uc + (size_t)1
    if fresh == 1:
        m.distinct += (size_t)1
    return m

# First value associated with key, or NULL if none.
public def multi_get(m MultiMap, key void*) -> void*:
    size_t cap = m.capacity
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            return 0
        if st == 1 and _mm_kveq(m.keys[idx], key) == 1:
            return m.values[idx]
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return 0
    return 0

public def multi_contains(m MultiMap, key void*) -> int:
    size_t cap = m.capacity
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    return _kvhas(m, start, key)

# Number of associations for `key`.
public def multi_count(m MultiMap, key void*) -> size_t:
    size_t cap = m.capacity
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    size_t idx = start
    int stop = 0
    size_t n = (size_t)0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            return n
        if st == 1 and _mm_kveq(m.keys[idx], key) == 1:
            n += (size_t)1
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return n
    return n

# Remove one association matching (key, value); returns the MultiMap.
public def multi_erase(m MultiMap, key void*, value void*) -> MultiMap:
    size_t cap = m.capacity
    size_t ln = m.length
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            return m
        if st == 1 and _mm_kveq(m.keys[idx], key) == 1 and _mm_kveq(m.values[idx], value) == 1:
            m.used[idx] = 2
            m.length = ln - (size_t)1
            # if this was the key's last live association, it is no longer distinct
            if multi_count(m, key) == (size_t)0 and m.distinct > (size_t)0:
                m.distinct -= (size_t)1
            return m
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return m
    return m

# Remove every association for `key`; returns the MultiMap.
public def multi_erase_all(m MultiMap, key void*) -> MultiMap:
    size_t cap = m.capacity
    size_t start = _mm_kvhash(key) & (cap - (size_t)1)
    size_t idx = start
    int removed = 0
    int stop = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            if removed == 1 and m.distinct > (size_t)0:
                m.distinct -= (size_t)1
            return m
        if st == 1 and _mm_kveq(m.keys[idx], key) == 1:
            m.used[idx] = 2
            m.length -= (size_t)1
            removed = 1
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            if removed == 1 and m.distinct > (size_t)0:
                m.distinct -= (size_t)1
            return m
    return m

public def multi_size(m MultiMap) -> size_t:
    return m.length

# Number of distinct keys with at least one live association.
public def multi_distinct(m MultiMap) -> size_t:
    return m.distinct

public def multi_is_empty(m MultiMap) -> int:
    int e = 0
    if m.length == (size_t)0:
        e = 1
    return e
