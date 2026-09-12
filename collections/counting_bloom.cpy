import stdlib

# CountingBloom: space-efficient multiset with per-slot byte counters.
# delete() is safe (only decrements counters); may_contain and estimated
# count (min of probed counters) support classic counting-bloom queries.
# The element count is stored on the heap (countp) so that struct-by-value
# copies all share it; scalar fields can't round-trip through byte-value
# returns in this compiler, so mutable state lives behind the pointer.

struct CountingBloom:
    char* counters
    size_t* countp
    size_t slots
    size_t k

public def create_counting_bloom(slots size_t, k size_t) -> CountingBloom:
    CountingBloom cb
    cb.counters = (char*)malloc(slots * (size_t)sizeof(char))
    cb.countp = (size_t*)malloc((size_t)1 * (size_t)sizeof(size_t))
    cb.slots = slots
    cb.k = k
    cb.countp[0] = (size_t)0
    size_t i = (size_t)0
    for i in range((int)slots):
        cb.counters[i] = (char)0
    return cb

public def _cbl_strlen(s char*) -> int:
    int n = 0
    if s == 0:
        return 0
    while s[n] != (char)0:
        n = n + 1
    return n

public def _cbl_h1(s char*, n int) -> size_t:
    size_t h = (size_t)5381
    int i = 0
    for i in range(n):
        int c = (int)s[i]
        h = h * (size_t)33 + (size_t)c
    return h

public def _cbl_h2(s char*, n int) -> size_t:
    size_t h = (size_t)0
    int i = 0
    for i in range(n):
        int c = (int)s[i]
        h = (size_t)c + (h << (int)6) + (h << (int)16)
    return h

public def counting_bloom_position(cb CountingBloom, s char*, j size_t) -> size_t:
    int n = _cbl_strlen(s)
    size_t h1 = _cbl_h1(s, n)
    size_t h2 = _cbl_h2(s, n)
    h2 = h2 | (size_t)1
    size_t h12 = h1
    h12 = h12 ^ (h12 >> (int)3)
    h12 = h12 ^ (h12 << (int)21)
    h12 = h12 ^ (h12 >> (int)15)
    size_t pos = (h1 + j * h12) % cb.slots
    return pos

public def counting_bloom_add(cb CountingBloom, s char*) -> CountingBloom:
    cb.countp[0] = cb.countp[0] + (size_t)1
    size_t j = (size_t)0
    for j in range((int)cb.k):
        size_t p = counting_bloom_position(cb, s, j)
        int c = (int)cb.counters[p]
        if c < 255:
            cb.counters[p] = (char)(c + 1)
    return cb

public def counting_bloom_remove(cb CountingBloom, s char*) -> int:
    size_t j = (size_t)0
    for j in range((int)cb.k):
        size_t p = counting_bloom_position(cb, s, j)
        int c = (int)cb.counters[p]
        if c <= 0:
            return 0
    j = (size_t)0
    for j in range((int)cb.k):
        size_t pos = counting_bloom_position(cb, s, j)
        int c = (int)cb.counters[pos]
        if c > 0:
            cb.counters[pos] = (char)(c - 1)
    if cb.countp[0] > (size_t)0:
        cb.countp[0] = cb.countp[0] - (size_t)1
    return 1

public def counting_bloom_may_contain(cb CountingBloom, s char*) -> int:
    size_t j = (size_t)0
    for j in range((int)cb.k):
        size_t p = counting_bloom_position(cb, s, j)
        int c = (int)cb.counters[p]
        if c <= 0:
            return 0
    return 1

public def counting_bloom_freq(cb CountingBloom, s char*) -> int:
    int best = 2147483647
    size_t j = (size_t)0
    for j in range((int)cb.k):
        size_t p = counting_bloom_position(cb, s, j)
        int c = (int)cb.counters[p]
        if c < best:
            best = c
    if best == 2147483647:
        return 0
    return best

public def counting_bloom_count(cb CountingBloom) -> size_t:
    return cb.countp[0]

public def counting_bloom_clear(cb CountingBloom) -> CountingBloom:
    size_t i = (size_t)0
    for i in range((int)cb.slots):
        cb.counters[i] = (char)0
    cb.countp[0] = (size_t)0
    return cb

public def counting_bloom_is_empty(cb CountingBloom) -> int:
    size_t i = (size_t)0
    for i in range((int)cb.slots):
        if (int)cb.counters[i] != 0:
            return 0
    return 1
