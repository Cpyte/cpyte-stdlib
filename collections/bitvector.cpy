import stdlib

# BitVector: growable sequence of bits over a flat word array. One 64-bit
# word per 64 flags; the buffer doubles like a classic dynamic array and
# only the trailing word is touched on push/pop. Insert/delete shift bits
# across word boundaries with a single pass of carry propagation.

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

public def _bv_word(b BitVector, i size_t) -> size_t:
    return i / (size_t)64

public def _bv_bit(i size_t) -> size_t:
    return i % (size_t)64

public def bitvector_push(b BitVector, v int) -> BitVector:
    if b.bits + (size_t)1 > b.capw * (size_t)64:
        b = _bv_grow(b)
    size_t w = _bv_word(b, b.bits)
    size_t bit = _bv_bit(b.bits)
    size_t m = (size_t)1 << (int)bit
    if v == 1:
        b.words[w] = b.words[w] | m
        b.count = b.count + (size_t)1
    b.bits = b.bits + (size_t)1
    return b

public def bitvector_pop(b BitVector) -> BitVector:
    if b.bits == (size_t)0:
        return b
    size_t last = b.bits - (size_t)1
    size_t w = _bv_word(b, last)
    size_t bit = _bv_bit(last)
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        b.count = b.count - (size_t)1
    b.words[w] = b.words[w] & (m ^ ~((size_t)0))
    b.bits = last
    return b

public def bitvector_get(b BitVector, i size_t) -> int:
    if i >= b.bits:
        return 0
    size_t w = _bv_word(b, i)
    size_t bit = _bv_bit(i)
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) != (size_t)0:
        return 1
    return 0

public def bitvector_set(b BitVector, i size_t, v int) -> BitVector:
    if i >= b.bits:
        return b
    size_t w = _bv_word(b, i)
    size_t bit = _bv_bit(i)
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
    size_t w = _bv_word(b, i)
    size_t bit = _bv_bit(i)
    size_t m = (size_t)1 << (int)bit
    if (b.words[w] & m) == (size_t)0:
        b.count = b.count + (size_t)1
    else:
        b.count = b.count - (size_t)1
    b.words[w] = b.words[w] ^ m
    return b

# Insert v at position i, shifting bits [i, bits) up by one. Bits move from
# the low word toward the high word: each word's top bit is carried into the
# next word's slot 0. Position i is inside word iw at bit bi.
public def bitvector_insert(b BitVector, i size_t, v int) -> BitVector:
    if i > b.bits:
        i = b.bits
    if b.bits + (size_t)1 > b.capw * (size_t)64:
        b = _bv_grow(b)
    size_t iw = _bv_word(b, i)
    size_t bi = _bv_bit(i)
    size_t lowmask = ((size_t)1 << (int)bi) - (size_t)1
    size_t carry = (size_t)0
    if (int)bi == 63:
        carry = (b.words[iw] >> (int)63) & (size_t)1
        b.words[iw] = b.words[iw] & lowmask
    else:
        carry = (b.words[iw] >> (int)63) & (size_t)1
        size_t mid = (b.words[iw] >> (int)bi) << (int)(bi + 1)
        b.words[iw] = (b.words[iw] & lowmask) | mid
    int w = (int)(iw + (size_t)1)
    # top = index of the last word of the NEW data = pre-insert bits / 64;
    # the old +1 wrote words[bits/64+1] out of bounds whenever bits%64 == 0.
    int top = (int)(b.bits / (size_t)64)
    while w <= top:
        size_t t = (b.words[w] >> (int)63) & (size_t)1
        b.words[w] = (b.words[w] << (int)1) | carry
        carry = t
        w = w + 1
    if v == 1:
        size_t m = (size_t)1 << (int)bi
        b.words[iw] = b.words[iw] | m
        b.count = b.count + (size_t)1
    b.bits = b.bits + (size_t)1
    return b

# Delete the bit at position i, shifting bits (i, bits) down by one. Bits
# move from the high word toward the low word: each word's slot-0 bit is
# carried into the previous word's slot 63.
public def bitvector_delete(b BitVector, i size_t) -> BitVector:
    if b.bits == (size_t)0:
        return b
    if i >= b.bits:
        i = b.bits - (size_t)1
    size_t old_top = (b.bits - (size_t)1) / (size_t)64
    size_t iw = _bv_word(b, i)
    size_t bi = _bv_bit(i)
    size_t deleted = (b.words[iw] >> (int)bi) & (size_t)1
    size_t lowmask = ((size_t)1 << (int)bi) - (size_t)1
    size_t carry = (size_t)0
    int w = (int)(old_top)
    int stop = (int)iw
    while w > stop:
        size_t bit0 = b.words[w] & (size_t)1
        # `>>` is arithmetic in cpy, so mask off the sign-fill
        b.words[w] = ((b.words[w] >> (int)1) & (size_t)0x7FFFFFFFFFFFFFFF) | (carry << (int)63)
        carry = bit0
        w = w - 1
    size_t hi = (size_t)0
    if (int)bi < 63:
        # `>>` is arithmetic in cpy, so mask off the sign-fill before the <<
        size_t tail = ((size_t)1 << (int)(63 - bi)) - (size_t)1
        hi = ((b.words[iw] >> (int)(bi + 1)) & tail) << (int)bi
    b.words[iw] = (b.words[iw] & lowmask) | hi | (carry << (int)63)
    b.bits = b.bits - (size_t)1
    if b.bits > (size_t)0:
        size_t tw = _bv_word(b, b.bits - (size_t)1)
        size_t tbi = _bv_bit(b.bits - (size_t)1)
        # clear stale bits within the new top word
        if (int)tbi < 63:
            b.words[tw] = b.words[tw] & (((size_t)1 << (int)(tbi + 1)) - (size_t)1)
        # zero orphaned whole words above the new top so later push `|=` can
        # never merge with stale bits
        size_t ow = tw + (size_t)1
        while ow <= old_top:
            b.words[ow] = (size_t)0
            ow = ow + (size_t)1
    else:
        size_t ow = (size_t)0
        while ow <= old_top:
            b.words[ow] = (size_t)0
            ow = ow + (size_t)1
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