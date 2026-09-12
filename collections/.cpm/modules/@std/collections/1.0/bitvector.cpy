import stdlib

# BitVector: growable sequence of bits over a flat word array. Doubles its
# word buffer like a classic dynamic array; only the trailing element is
# touched on push/pop.

struct BitVector:
    size_t* words
    int* tab
    size_t capw
    size_t bits
    size_t count

public def _bv_tab() -> int*:
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

public def create_bitvector() -> BitVector:
    BitVector b
    b.capw = (size_t)8
    b.bits = (size_t)0
    b.count = (size_t)0
    b.tab = _bv_tab()
    b.words = (size_t*)malloc(b.capw * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)b.capw):
        b.words[i] = (size_t)0
    return b

public def _bv_grow(b BitVector) -> BitVector:
    size_t nc = b.capw * (size_t)2
    size_t* nw = (size_t*)malloc(nc * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)b.capw):
        nw[i] = b.words[i]
    i = b.capw
    while i < nc:
        nw[i] = (size_t)0
        i = i + (size_t)1
    b.capw = nc
    b.words = nw
    return b

public def bitvector_push(b BitVector, v int) -> BitVector:
    if b.bits + (size_t)1 > b.capw * (size_t)64:
        b = _bv_grow(b)
    size_t w = b.bits / (size_t)64
    size_t bit = b.bits % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if v == 1:
        b.words[w] = b.words[w] | m
        b.count = b.count + (size_t)1
    b.bits = b.bits + (size_t)1
    return b

public def bitvector_pop(b BitVector) -> BitVector:
    if b.bits == (size_t)0:
        return b
    size_t w = (b.bits - (size_t)1) / (size_t)64
    size_t bit = (b.bits - (size_t)1) % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        b.count = b.count - (size_t)1
    b.words[w] = b.words[w] & (m ^ ~((size_t)0))
    b.bits = b.bits - (size_t)1
    return b

public def bitvector_get(b BitVector, i size_t) -> int:
    if i >= b.bits:
        return 0
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        return 1
    return 0

public def bitvector_set(b BitVector, i size_t, v int) -> BitVector:
    if i >= b.bits:
        return b
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t m = (size_t)1 << (int)bit
    if v == 1:
        if (b.words[w] & m) == (size_t)0:
            b.count = b.count + (size_t)1
        b.words[w] = b.words[w] | m
    else:
        if (b.words[w] & m) != (size_t)0:
            b.count = b.count - (size_t)1
        b.words[w] = b.words[w] & (m ^ ~((size_t)0))
    return b

public def bitvector_flip(b BitVector, i size_t) -> BitVector:
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

public def bitvector_insert(b BitVector, i size_t, v int) -> BitVector:
    if i > b.bits:
        i = b.bits
    if b.bits + (size_t)1 > b.capw * (size_t)64:
        b = _bv_grow(b)
    size_t iw = i / (size_t)64
    size_t bi = i % (size_t)64
    size_t lowmask = ((size_t)1 << (int)bi) - (size_t)1
    size_t carry = (size_t)0
    int w = (int)iw
    int last = (int)((b.bits / (size_t)64) + (size_t)1)
    while w > (int)iw:
        w = w - 1
        size_t hibit = b.words[w] >> (int)63
        b.words[w] = (b.words[w] << (int)1) | carry
        carry = hibit
    size_t mid = (b.words[iw] >> (int)bi) << (int)(bi + 1)
    b.words[iw] = (b.words[iw] & lowmask) | mid
    if ((b.bits - (size_t)1) % (size_t)64) == (size_t)63:
        b.words[(b.bits / (size_t)64)] = carry
    if v == 1:
        size_t m = (size_t)1 << (int)bi
        b.words[iw] = b.words[iw] | m
        b.count = b.count + (size_t)1
    b.bits = b.bits + (size_t)1
    return b

public def bitvector_delete(b BitVector, i size_t) -> BitVector:
    if b.bits == (size_t)0:
        return b
    if i >= b.bits:
        i = b.bits - (size_t)1
    size_t iw = i / (size_t)64
    size_t bi = i % (size_t)64
    size_t deleted = (b.words[iw] >> (int)bi) & (size_t)1
    size_t lowmask = ((size_t)1 << (int)bi) - (size_t)1
    size_t carry = (size_t)0
    int w = (int)((b.bits - (size_t)1) / (size_t)64)
    while w >= (int)iw:
        size_t bybit = b.words[w] >> (int)63
        if w == (int)iw:
            size_t high = b.words[w] >> (int)(bi + 1)
            b.words[w] = (b.words[w] & lowmask) | (high << (int)bi) | (carry << (int)63)
        else:
            b.words[w] = (b.words[w] << (int)1) | carry
        carry = bybit
        w = w - 1
    b.bits = b.bits - (size_t)1
    if deleted == (size_t)1:
        b.count = b.count - (size_t)1
    return b

public def bitvector_length(b BitVector) -> size_t:
    return b.bits

public def bitvector_count(b BitVector) -> size_t:
    return b.count

public def bitvector_word_count(b BitVector) -> size_t:
    return b.capw

public def bitvector_to_words(b BitVector) -> size_t*:
    return b.words