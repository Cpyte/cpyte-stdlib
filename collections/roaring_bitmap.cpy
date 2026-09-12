import stdlib

# RoaringBitmap: compressed bitset in 16-bit buckets over a flat structure.
# Buckets (high-16 keys) live in one size_t array; containers live in one
# RoCont array. Sparse buckets use sorted 16-bit arrays that convert to
# dense 64 KB flag containers past 4096 values: one byte per bit (0/1) over
# the full 16-bit bucket, which sidesteps broken >=32-bit literal/shift
# folding and avoids bitwise ops on char reads.

struct RoCont:
    int is_bitmap
    size_t len
    size_t vcap
    size_t* vals
    char* words

struct Roaring:
    size_t* highs
    RoCont* conts
    size_t nb
    size_t cap

public def create_roaring() -> Roaring:
    Roaring r
    r.cap = (size_t)8
    r.nb = (size_t)0
    r.highs = (size_t*)malloc(r.cap * (size_t)sizeof(size_t))
    r.conts = (RoCont*)malloc(r.cap * (size_t)sizeof(RoCont))
    return r

public def _rg_grow(r Roaring) -> Roaring:
    size_t nc = r.cap * (size_t)2
    size_t* nh = (size_t*)malloc(nc * (size_t)sizeof(size_t))
    RoCont* nc2 = (RoCont*)malloc(nc * (size_t)sizeof(RoCont))
    size_t i = (size_t)0
    for i in range((int)r.nb):
        nh[i] = r.highs[i]
        nc2[i].is_bitmap = r.conts[i].is_bitmap
        nc2[i].len = r.conts[i].len
        nc2[i].vcap = r.conts[i].vcap
        nc2[i].vals = r.conts[i].vals
        nc2[i].words = r.conts[i].words
    r.highs = nh
    r.conts = nc2
    r.cap = nc
    return r

public def _rg_b_reset(r Roaring, idx size_t, vcap size_t) -> Roaring:
    r.conts[idx].is_bitmap = 0
    r.conts[idx].len = (size_t)0
    r.conts[idx].vcap = vcap
    r.conts[idx].vals = (size_t*)malloc(vcap * (size_t)sizeof(size_t))
    r.conts[idx].words = 0
    return r

public def _rg_find_high(r Roaring, hi size_t) -> size_t:
    size_t p = (size_t)0
    while p < r.nb:
        if r.highs[p] >= hi:
            return p
        p = p + (size_t)1
    return r.nb

public def _rg_bucket_insert(r Roaring, pos size_t) -> Roaring:
    if r.nb == r.cap:
        r = _rg_grow(r)
    int i = (int)r.nb
    while i > (int)pos:
        r.highs[i] = r.highs[i - 1]
        r.conts[i].is_bitmap = r.conts[i - 1].is_bitmap
        r.conts[i].len = r.conts[i - 1].len
        r.conts[i].vcap = r.conts[i - 1].vcap
        r.conts[i].vals = r.conts[i - 1].vals
        r.conts[i].words = r.conts[i - 1].words
        i = i - 1
    r.nb = r.nb + (size_t)1
    return r

public def _rg_bitset_set(r Roaring, idx size_t, low size_t) -> Roaring:
    char* bp = r.conts[idx].words
    bp[low] = (char)1
    return r

public def _rg_bitset_test(r Roaring, idx size_t, low size_t) -> int:
    char* bp = r.conts[idx].words
    if (int)bp[low] == 1:
        return 1
    return 0

public def _rg_bitset_clear(r Roaring, idx size_t, low size_t) -> Roaring:
    char* bp = r.conts[idx].words
    bp[low] = (char)0
    return r

public def _rg_conv(r Roaring, idx size_t) -> Roaring:
    r.conts[idx].words = (char*)malloc((size_t)65536 * (size_t)sizeof(char))
    char* bp = r.conts[idx].words
    int k = 0
    for k in range(65536):
        bp[k] = (char)0
    size_t i = (size_t)0
    for i in range((int)r.conts[idx].len):
        bp[r.conts[idx].vals[i]] = (char)1
    r.conts[idx].is_bitmap = 1
    return r

public def _rg_arr_insert_low(r Roaring, idx size_t, low size_t) -> Roaring:
    size_t len = r.conts[idx].len
    if len == (size_t)0:
        r.conts[idx].vals[0] = low
        r.conts[idx].len = (size_t)1
        return r
    size_t p = (size_t)0
    while p < len:
        if r.conts[idx].vals[p] >= low:
            break
        p = p + (size_t)1
    if p < len:
        if r.conts[idx].vals[p] == low:
            return r
    if len == r.conts[idx].vcap:
        size_t nvcap = r.conts[idx].vcap * (size_t)2
        size_t* nv = (size_t*)malloc(nvcap * (size_t)sizeof(size_t))
        size_t k = (size_t)0
        for k in range((int)len):
            nv[k] = r.conts[idx].vals[k]
        r.conts[idx].vals = nv
        r.conts[idx].vcap = nvcap
    int i = (int)len
    while i > (int)p:
        r.conts[idx].vals[i] = r.conts[idx].vals[i - 1]
        i = i - 1
    r.conts[idx].vals[p] = low
    r.conts[idx].len = len + (size_t)1
    return r

public def roaring_add(r Roaring, key size_t) -> Roaring:
    size_t hi = key >> (int)16
    size_t low = key & (size_t)0xFFFF
    if hi >= (size_t)65536:
        return r
    size_t pos = _rg_find_high(r, hi)
    if pos >= r.nb:
        r = _rg_bucket_insert(r, r.nb)
        r.highs[r.nb - (size_t)1] = hi
        r = _rg_b_reset(r, r.nb - (size_t)1, (size_t)8)
        pos = r.nb - (size_t)1
    else:
        if r.highs[pos] != hi:
            r = _rg_bucket_insert(r, pos)
            r.highs[pos] = hi
            r = _rg_b_reset(r, pos, (size_t)8)
    if r.conts[pos].is_bitmap == 1:
        if _rg_bitset_test(r, pos, low) == 0:
            r = _rg_bitset_set(r, pos, low)
            r.conts[pos].len = r.conts[pos].len + (size_t)1
        return r
    r = _rg_arr_insert_low(r, pos, low)
    if r.conts[pos].len > (size_t)4096:
        r = _rg_conv(r, pos)
    return r

public def _rg_lowof(r Roaring, idx size_t, low size_t) -> int:
    size_t len = r.conts[idx].len
    size_t i = (size_t)0
    while i < len:
        if r.conts[idx].vals[i] == low:
            return 1
        i = i + (size_t)1
    return 0

public def roaring_contains(r Roaring, key size_t) -> int:
    size_t hi = key >> (int)16
    size_t low = key & (size_t)0xFFFF
    size_t pos = _rg_find_high(r, hi)
    if pos >= r.nb:
        return 0
    if r.highs[pos] != hi:
        return 0
    if r.conts[pos].is_bitmap == 1:
        return _rg_bitset_test(r, pos, low)
    return _rg_lowof(r, pos, low)

public def _rg_arr_del_low(r Roaring, idx size_t, low size_t) -> int:
    size_t len = r.conts[idx].len
    size_t p = (size_t)0
    while p < len:
        if r.conts[idx].vals[p] == low:
            break
        p = p + (size_t)1
    if p >= len:
        return 0
    int i = (int)p
    while i < (int)(len - (size_t)1):
        r.conts[idx].vals[i] = r.conts[idx].vals[i + 1]
        i = i + 1
    r.conts[idx].len = len - (size_t)1
    return 1

public def roaring_remove(r Roaring, key size_t) -> Roaring:
    size_t hi = key >> (int)16
    size_t low = key & (size_t)0xFFFF
    size_t pos = _rg_find_high(r, hi)
    if pos >= r.nb:
        return r
    if r.highs[pos] != hi:
        return r
    if r.conts[pos].is_bitmap == 1:
        if _rg_bitset_test(r, pos, low) != 0:
            r = _rg_bitset_clear(r, pos, low)
            r.conts[pos].len = r.conts[pos].len - (size_t)1
        return r
    _rg_arr_del_low(r, pos, low)
    return r

public def _rg_card_of(r Roaring, idx size_t) -> size_t:
    return r.conts[idx].len

public def roaring_cardinality(r Roaring) -> size_t:
    size_t t = (size_t)0
    size_t i = (size_t)0
    for i in range((int)r.nb):
        t = t + r.conts[i].len
    return t

public def roaring_range(r Roaring) -> size_t:
    return (size_t)0xFFFFFFFF

public def roaring_is_empty(r Roaring) -> int:
    size_t i = (size_t)0
    for i in range((int)r.nb):
        if r.conts[i].len != (size_t)0:
            return 0
    return 1

public def roaring_buckets(r Roaring) -> size_t:
    return r.nb

public def roaring_high_at(r Roaring, i size_t) -> size_t:
    if i >= r.nb:
        return (size_t)0
    return r.highs[i]