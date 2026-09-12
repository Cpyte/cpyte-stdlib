import stdlib

# CuckooFilter: set membership with deletion. Each bucket holds 4
# fingerprints; inserts relocate (kick) entries to an alternate bucket
# derived as b2 = b1 XOR fp_hash. Storage is one flat word array.

struct Cuckoo:
    size_t* table
    size_t nbuck
    size_t count
    size_t seed

public def create_cuckoo(nbuckets size_t) -> Cuckoo:
    Cuckoo c
    c.table = (size_t*)malloc(nbuckets * (size_t)4 * (size_t)sizeof(size_t))
    c.nbuck = nbuckets
    c.count = (size_t)0
    c.seed = (size_t)1
    size_t n = nbuckets * (size_t)4
    size_t i = (size_t)0
    for i in range((int)n):
        c.table[i] = (size_t)0
    return c

public def _cf_mix(x size_t) -> size_t:
    size_t y = x
    y = y ^ (y >> (int)33)
    y = y ^ (y << (int)21)
    y = y ^ (y >> (int)15)
    y = y ^ (y << (int)27)
    y = y ^ (y >> (int)31)
    return y

public def _cf_fp(x size_t) -> size_t:
    size_t m = _cf_mix(x)
    size_t f = (m & (size_t)0xFF) + (size_t)1
    return f

public def _cf_fp_hash(fp size_t) -> size_t:
    return _cf_mix(fp)

public def _cf_bucket1(c Cuckoo, x size_t) -> size_t:
    return _cf_mix(x) % c.nbuck

public def _cf_alt(c Cuckoo, b size_t, fp size_t) -> size_t:
    size_t fh = _cf_fp_hash(fp) % c.nbuck
    return b ^ fh

public def _cf_find_slot(c Cuckoo, b size_t, fp size_t) -> size_t:
    size_t s = (size_t)0
    for s in range(4):
        if c.table[b * (size_t)4 + s] == fp:
            return (size_t)s
    return (size_t)0x7FFFFFFF

public def _cf_find_free(c Cuckoo, b size_t) -> size_t:
    size_t s = (size_t)0
    for s in range(4):
        if c.table[b * (size_t)4 + s] == (size_t)0:
            return (size_t)s
    return (size_t)0x7FFFFFFF

public def _cf_try_place(c Cuckoo, b size_t, fp size_t) -> int:
    size_t s = _cf_find_free(c, b)
    if s != (size_t)0x7FFFFFFF:
        c.table[b * (size_t)4 + s] = fp
        return 1
    return 0

public def cuckoo_insert(c Cuckoo, x size_t) -> int:
    size_t fp = _cf_fp(x)
    size_t b1 = _cf_bucket1(c, x)
    size_t b2 = _cf_alt(c, b1, fp)
    if _cf_try_place(c, b1, fp) == 1:
        c.count = c.count + (size_t)1
        return 1
    if _cf_try_place(c, b2, fp) == 1:
        c.count = c.count + (size_t)1
        return 1
    size_t b = b1
    int kicks = 0
    for kicks in range(500):
        size_t slot = b * (size_t)4 + (c.seed % (size_t)4)
        c.seed = c.seed + (size_t)97
        size_t old = c.table[slot]
        c.table[slot] = fp
        fp = old
        b = _cf_alt(c, b, fp)
        if _cf_try_place(c, b, fp) == 1:
            c.count = c.count + (size_t)1
            return 1
    return 0

public def cuckoo_contains(c Cuckoo, x size_t) -> int:
    size_t fp = _cf_fp(x)
    size_t b1 = _cf_bucket1(c, x)
    size_t b2 = _cf_alt(c, b1, fp)
    if _cf_find_slot(c, b1, fp) != (size_t)0x7FFFFFFF:
        return 1
    if _cf_find_slot(c, b2, fp) != (size_t)0x7FFFFFFF:
        return 1
    return 0

public def cuckoo_delete(c Cuckoo, x size_t) -> int:
    size_t fp = _cf_fp(x)
    size_t b1 = _cf_bucket1(c, x)
    size_t b2 = _cf_alt(c, b1, fp)
    size_t s = _cf_find_slot(c, b1, fp)
    if s != (size_t)0x7FFFFFFF:
        c.table[b1 * (size_t)4 + s] = (size_t)0
        c.count = c.count - (size_t)1
        return 1
    s = _cf_find_slot(c, b2, fp)
    if s != (size_t)0x7FFFFFFF:
        c.table[b2 * (size_t)4 + s] = (size_t)0
        c.count = c.count - (size_t)1
        return 1
    return 0

public def cuckoo_count(c Cuckoo) -> size_t:
    return c.count

public def cuckoo_load_factor(c Cuckoo) -> size_t:
    size_t cap = c.nbuck * (size_t)4
    return (c.count * (size_t)100) / cap

public def cuckoo_clear(c Cuckoo) -> Cuckoo:
    size_t n = c.nbuck * (size_t)4
    size_t i = (size_t)0
    for i in range((int)n):
        c.table[i] = (size_t)0
    c.count = (size_t)0
    return c
