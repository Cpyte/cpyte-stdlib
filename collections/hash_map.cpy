import stdlib
import "mem.cpy"

# HashMap / Map: type-agnostic key->value table using open addressing (linear
# probing down a cluster, cache-friendly packed arrays).
#
# KEYS ARE IDENTITY-BASED. A key is the raw 64-bit void* value (an int
# stored as void*, or a pointer). Two keys are equal iff their 8-byte values
# are equal; keys are hashed by that numeric value, not by any pointed-to
# contents. So `int x=42, y=42; map[x]=1; map[y]` treats x and y as the same
# key only if you pass the pointer VALUE (e.g. 42 as an int-like void*) — two
# different addresses &x, &y are always distinct keys even if *x == *y. This
# is a deliberate, documented identity-map semantic.
#
# PLATFORM ASSUMPTION: the key hash and slot arithmetic assume 64-bit size_t
# and pointer width (shifts by 33, 64-bit mixing constants). On 32-bit hosts
# _hm_kvhash must be replaced; the rest still works.
#
# Slots: 0=empty, 1=live, 2=tombstone. A single _hm_kvwalk traverses a cluster
# skipping tombstones and stopping at the first empty slot (empty means the
# key is definitively absent, tombstone means keep probing). Rehash builds
# fresh arrays (different arrays from the source) which avoids the JIT
# same-array write bug, then frees the old arrays. Mutators return the
# updated HashMap; length counts live entries and used_count counts live +
# tombstones so tombstones can be reclaimed.
struct HashMap:
    void** keys
    void** values
    int* used
    char* slab
    size_t capacity
    size_t length
    size_t used_count

public def _hm_next_pow2(n size_t) -> size_t:
    size_t p = 8
    while p < n:
        p = p * (size_t)2
    return p

public def _hm_init_table(m HashMap, c size_t) -> HashMap:
    # One aligned slab for keys/values/used: a single malloc and adjacent
    # arrays keep every probe inside the same cache lines.
    size_t voff = c * (size_t)8
    size_t uoff = voff + c * (size_t)8
    size_t total = uoff + c * (size_t)4
    char* slab = (char*)malloc(total)
    m.slab = slab
    m.keys = (void**)(slab + (int)0)
    m.values = (void**)(slab + (int)voff)
    m.used = (int*)(slab + (int)uoff)
    m.length = (size_t)0
    m.used_count = (size_t)0
    buf_zero((void*)m.keys, c * (size_t)8)
    buf_zero((void*)m.values, c * (size_t)8)
    buf_zero((void*)m.used, c * (size_t)4)
    return m

public def create_hashmap(cap size_t) -> HashMap:
    size_t c = _hm_next_pow2(cap)
    HashMap m
    m.capacity = c
    return _hm_init_table(m, c)

public def _hm_kveq(a void*, b void*) -> int:
    int eq = 0
    if a == b:
        eq = 1
    return eq

# Identity hash folded from the 8 bytes of the key value (64-bit finalizer).
public def _hm_kvhash(key void*) -> size_t:
    size_t a = (size_t)key
    a = a ^ (a >> 33)
    a = a * (size_t)0xff51afd7ed558ccd
    a = a ^ (a >> 33)
    a = a * (size_t)0xc4ceb9fe1a85ec53
    a = a ^ (a >> 33)
    return a

# Walk the cluster starting at `start` looking for `key`.
# Returns: slot of the matching live key, or capacity if the key is absent.
public def _hm_kvwalk(m HashMap, start size_t, key void*) -> size_t:
    size_t cap = m.capacity
    size_t idx = start
    int stop = 0
    while stop == 0:
        int st = m.used[idx]
        if st == 0:
            return cap
        if st == 1 and _hm_kveq(m.keys[idx], key) == 1:
            return idx
        idx = idx + (size_t)1
        if idx >= cap:
            idx = (size_t)0
        if idx == start:
            return cap
    return cap

# First empty or tombstone slot in the cluster starting at `start`.
public def _hm_kvfree(m HashMap, start size_t) -> size_t:
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

# Rehash every live entry (skipping tombstones) into a fresh table of at
# least `new_cap` slots; optionally insert (key,value) when do_set == 1.
# Frees the source arrays (they have been fully copied) to avoid leaking the
# old table on every growth.
public def _hm_kv_rehash(m HashMap, new_cap size_t, key void*, value void*, do_set int) -> HashMap:
    size_t c = _hm_next_pow2(new_cap)
    HashMap nm
    nm.capacity = c
    nm = _hm_init_table(nm, c)
    int i = 0
    while i < (int)m.capacity:
        if m.used[i] == 1:
            size_t start = _hm_kvhash(m.keys[i]) & (nm.capacity - (size_t)1)
            size_t slot = _hm_kvfree(nm, start)
            nm.keys[slot] = m.keys[i]
            nm.values[slot] = m.values[i]
            nm.used[slot] = 1
            nm.length += (size_t)1
            nm.used_count += (size_t)1
        i = i + 1
    if do_set == 1:
        size_t start = _hm_kvhash(key) & (nm.capacity - (size_t)1)
        size_t slot = _hm_kvfree(nm, start)
        nm.keys[slot] = key
        nm.values[slot] = value
        nm.used[slot] = 1
        nm.length += (size_t)1
        nm.used_count += (size_t)1
    free((void*)m.slab)
    return nm

# Insert or update key->value; returns the updated HashMap.
public def hashmap_put(m HashMap, key void*, value void*) -> HashMap:
    size_t cap = m.capacity
    size_t ln = m.length
    size_t uc = m.used_count
    size_t start = _hm_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hm_kvwalk(m, start, key)
    if hit != cap:
        m.values[hit] = value
        return m
    # grow when live load is high, or when live+tombstone occupancy is high
    # (the latter reclaims accumulated tombstones by rebuilding).
    size_t grown = (ln + (size_t)1) * (size_t)10
    size_t loadthr = cap * (size_t)7
    size_t upthr = cap * (size_t)9
    if grown >= loadthr or (uc + (size_t)1) * (size_t)10 >= upthr:
        return _hm_kv_rehash(m, cap * (size_t)2, key, value, 1)
    size_t slot = _hm_kvfree(m, start)
    m.keys[slot] = key
    m.values[slot] = value
    m.used[slot] = 1
    m.length = ln + (size_t)1
    m.used_count = uc + (size_t)1
    return m

# Value for key, or NULL (use hashmap_contains for presence).
public def hashmap_get(m HashMap, key void*) -> void*:
    size_t cap = m.capacity
    size_t start = _hm_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hm_kvwalk(m, start, key)
    if hit != cap:
        return m.values[hit]
    return 0

public def hashmap_contains(m HashMap, key void*) -> int:
    size_t cap = m.capacity
    size_t start = _hm_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hm_kvwalk(m, start, key)
    int found = 0
    if hit != cap:
        found = 1
    return found

# Remove a key (marks a tombstone); returns the HashMap. The slot stays
# occupied (as a tombstone) so in-progress lookups never truncate a cluster.
public def hashmap_erase(m HashMap, key void*) -> HashMap:
    size_t cap = m.capacity
    size_t ln = m.length
    size_t start = _hm_kvhash(key) & (cap - (size_t)1)
    size_t hit = _hm_kvwalk(m, start, key)
    if hit != cap:
        m.used[hit] = 2
        m.length = ln - (size_t)1
        # used_count unchanged (slot remains occupied as a tombstone)
    return m

public def hashmap_size(m HashMap) -> size_t:
    return m.length

public def hashmap_is_empty(m HashMap) -> int:
    int e = 0
    if m.length == (size_t)0:
        e = 1
    return e
