import stdlib

# BitSet: dense boolean values over a fixed-size universe, backed by a flat
# word array. One 64-bit word per 64 flags; every operation walks a
# contiguous size_t buffer (cache-friendly) with byte-wise popcount via an
# L1 table.

struct BitSet:
    size_t* words
    int* tab
    size_t nwords
    size_t bits
    size_t count

public def _bs_tab() -> int*:
    int* t = (int*)malloc((size_t)256 * (size_t)sizeof(int))
    int i = 0
    for i in range(256):
        int c = 0
        int v = i
        int k = 0
        for k in range(8):
            c = c + (v & 1)
            v = v >> 1
        t[i] = c
    return t

public def create_bitset(bits size_t) -> BitSet:
    size_t nw = bits / (size_t)64
    if bits % (size_t)64 != (size_t)0:
        nw = nw + (size_t)1
    BitSet b
    b.nwords = nw
    b.bits = bits
    b.count = (size_t)0
    b.tab = _bs_tab()
    b.words = (size_t*)malloc(nw * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)nw):
        b.words[i] = (size_t)0
    return b

public def _bs_pc_w(b BitSet, w size_t) -> int:
    int s = 0
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + b.tab[(int)(w & (size_t)0xFF)]
    return s

public def _bs_highmask(n size_t) -> size_t:
    size_t full = ~((size_t)0)
    size_t low = ((size_t)1 << (int)n) - (size_t)1
    return full ^ low

public def bitset_set(b BitSet, i size_t) -> BitSet:
    if i >= b.bits:
        return b
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) == (size_t)0:
        b.count = b.count + (size_t)1
    b.words[w] = b.words[w] | m
    return b

public def bitset_clear(b BitSet, i size_t) -> BitSet:
    if i >= b.bits:
        return b
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        b.count = b.count - (size_t)1
    b.words[w] = b.words[w] & (m ^ ~((size_t)0))
    return b

public def bitset_flip(b BitSet, i size_t) -> BitSet:
    if i >= b.bits:
        return b
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) == (size_t)0:
        b.count = b.count + (size_t)1
    else:
        b.count = b.count - (size_t)1
    b.words[w] = b.words[w] ^ m
    return b

public def bitset_test(b BitSet, i size_t) -> int:
    if i >= b.bits:
        return 0
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        return 1
    return 0

public def bitset_count(b BitSet) -> size_t:
    return b.count

public def bitset_recount(b BitSet) -> BitSet:
    size_t total = (size_t)0
    size_t i = (size_t)0
    for i in range((int)b.nwords):
        total = total + (size_t)_bs_pc_w(b, b.words[i])
    b.count = total
    return b

public def bitset_any(b BitSet) -> int:
    size_t i = (size_t)0
    for i in range((int)b.nwords):
        if b.words[i] != (size_t)0:
            return 1
    return 0

public def bitset_none(b BitSet) -> int:
    size_t i = (size_t)0
    for i in range((int)b.nwords):
        if b.words[i] != (size_t)0:
            return 0
    return 1

public def bitset_clear_all(b BitSet) -> BitSet:
    size_t i = (size_t)0
    for i in range((int)b.nwords):
        b.words[i] = (size_t)0
    b.count = (size_t)0
    return b

public def bitset_count_range(b BitSet, lo size_t, hi size_t) -> int:
    if lo >= b.bits:
        return 0
    if hi > b.bits:
        hi = b.bits
    if hi <= lo:
        return 0
    size_t wl = lo / (size_t)64
    size_t bl = lo % (size_t)64
    size_t wr = (hi - (size_t)1) / (size_t)64
    size_t br = hi % (size_t)64
    int total = 0
    if wl == wr:
        size_t mlo = ((size_t)1 << (int)bl) - (size_t)1
        if br == (size_t)0:
            total = _bs_pc_w(b, b.words[wl] & (mlo ^ ~((size_t)0)))
        else:
            total = _bs_pc_w(b, b.words[wl] & ((((size_t)1 << (int)br) - (size_t)1) ^ mlo))
        return total
    total = _bs_pc_w(b, b.words[wl] & _bs_highmask(bl))
    size_t w = wl + (size_t)1
    while w < wr:
        total = total + _bs_pc_w(b, b.words[w])
        w = w + (size_t)1
    if br == (size_t)0:
        total = total + _bs_pc_w(b, b.words[wr])
    else:
        total = total + _bs_pc_w(b, b.words[wr] & (((size_t)1 << (int)br) - (size_t)1))
    return total

public def bitset_next_set(b BitSet, from size_t) -> size_t:
    size_t w = from / (size_t)64
    size_t bl = from % (size_t)64
    if w >= b.nwords:
        return (size_t)0x7FFFFFFF
    size_t cur = b.words[w] & _bs_highmask(bl)
    while cur == (size_t)0:
        w = w + (size_t)1
        if w >= b.nwords:
            return (size_t)0x7FFFFFFF
        cur = b.words[w]
    size_t base = w * (size_t)64
    int e = 0
    for e in range(64):
        size_t m = (size_t)1 << e
        if (cur & m) != (size_t)0:
            return base + (size_t)e
    return (size_t)0x7FFFFFFF

public def bitset_to_words(b BitSet) -> size_t*:
    return b.words

public def bitset_word_count(b BitSet) -> size_t:
    return b.nwords