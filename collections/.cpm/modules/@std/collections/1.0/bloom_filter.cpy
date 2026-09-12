import stdlib

# BloomFilter: classic probabilistic set membership. A single flat word
# array; k positions per key are derived by double hashing so the probe
# stream is spread over the buffer and can be gathered as independent loads.

struct Bloom:
    size_t* words
    size_t bits
    size_t k
    size_t count

public def create_bloom(bits size_t, k size_t) -> Bloom:
    size_t nw = bits / (size_t)64
    if bits % (size_t)64 != (size_t)0:
        nw = nw + (size_t)1
    Bloom bl
    bl.words = (size_t*)malloc(nw * (size_t)sizeof(size_t))
    bl.bits = bits
    bl.k = k
    bl.count = (size_t)0
    size_t i = (size_t)0
    for i in range((int)nw):
        bl.words[i] = (size_t)0
    return bl

public def _bl_strlen(s char*) -> int:
    int n = 0
    if s == 0:
        return 0
    while s[n] != (char)0:
        n = n + 1
    return n

public def _bl_h1(s char*, n int) -> size_t:
    size_t h = (size_t)5381
    int i = 0
    for i in range(n):
        int c = (int)s[i]
        h = h * (size_t)33 + (size_t)c
    return h

public def _bl_h2(s char*, n int) -> size_t:
    size_t h = (size_t)0
    int i = 0
    for i in range(n):
        int c = (int)s[i]
        h = (size_t)c + (h << (int)6) + (h << (int)16)
    return h

public def bloom_position(bl Bloom, s char*, j size_t) -> size_t:
    int n = _bl_strlen(s)
    size_t h1 = _bl_h1(s, n)
    size_t h2 = _bl_h2(s, n)
    h2 = h2 | (size_t)1
    size_t h12 = h1
    h12 = h12 ^ (h12 >> (int)33)
    h12 = h12 ^ (h12 << (int)21)
    h12 = h12 ^ (h12 >> (int)15)
    size_t pos = (h1 + j * h12) % bl.bits
    return pos

public def bloom_add(bl Bloom, s char*) -> Bloom:
    bl.count = bl.count + (size_t)1
    size_t j = (size_t)0
    for j in range((int)bl.k):
        size_t p = bloom_position(bl, s, j)
        bl.words[p / (size_t)64] = bl.words[p / (size_t)64] | ((size_t)1 << (int)(p % (size_t)64))
    return bl

public def bloom_contains(bl Bloom, s char*) -> int:
    size_t j = (size_t)0
    for j in range((int)bl.k):
        size_t p = bloom_position(bl, s, j)
        if ((bl.words[p / (size_t)64] >> (int)(p % (size_t)64)) & (size_t)1) == (size_t)0:
            return 0
    return 1

public def bloom_maybe(bl Bloom, s char*) -> int:
    return bloom_contains(bl, s)

public def bloom_clear(bl Bloom) -> Bloom:
    size_t nw = bl.bits / (size_t)64
    if bl.bits % (size_t)64 != (size_t)0:
        nw = nw + (size_t)1
    size_t i = (size_t)0
    for i in range((int)nw):
        bl.words[i] = (size_t)0
    bl.count = (size_t)0
    return bl

public def bloom_count(bl Bloom) -> size_t:
    return bl.count

public def bloom_is_empty(bl Bloom) -> int:
    size_t nw = bl.bits / (size_t)64
    if bl.bits % (size_t)64 != (size_t)0:
        nw = nw + (size_t)1
    size_t i = (size_t)0
    for i in range((int)nw):
        if bl.words[i] != (size_t)0:
            return 0
    return 1
