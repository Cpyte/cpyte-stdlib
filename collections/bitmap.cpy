import stdlib

# Bitmap: dense flag store over a fixed universe with fast range operations
# (set/clear/flip/count over [lo, hi)). One 64-bit word per 64 flags; masks
# are built at runtime from shifts. Range ops touch only the boundary words
# plus a stride-1 interior scan, so the LLVM JIT can vectorize the interior
# loop over the contiguous size_t buffer.

struct Bitmap:
    size_t* words
    int* tab
    size_t nwords
    size_t bits
    size_t count

public def _bm_tab() -> int*:
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

public def create_bitmap(bits size_t) -> Bitmap:
    size_t nw = bits / (size_t)64
    if bits % (size_t)64 != (size_t)0:
        nw = nw + (size_t)1
    Bitmap m
    m.nwords = nw
    m.bits = bits
    m.count = (size_t)0
    m.tab = _bm_tab()
    m.words = (size_t*)malloc(nw * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)nw):
        m.words[i] = (size_t)0
    return m

public def _bm_pc_w(m Bitmap, w size_t) -> int:
    int s = 0
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    w = (w >> (int)8) & (size_t)0x00FFFFFFFFFFFFFF
    s = s + m.tab[(int)(w & (size_t)0xFF)]
    return s

public def _bm_highmask(n size_t) -> size_t:
    size_t full = ~((size_t)0)
    size_t low = ((size_t)1 << (int)n) - (size_t)1
    return full ^ low

public def bitmap_set(m Bitmap, i size_t) -> Bitmap:
    if i >= m.bits:
        return m
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t bitmask = (size_t)1 << (int)bit
    if (m.words[w] & bitmask) == (size_t)0:
        m.count = m.count + (size_t)1
    m.words[w] = m.words[w] | bitmask
    return m

public def bitmap_clear(m Bitmap, i size_t) -> Bitmap:
    if i >= m.bits:
        return m
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t bitmask = (size_t)1 << (int)bit
    if (m.words[w] & bitmask) != (size_t)0:
        m.count = m.count - (size_t)1
    m.words[w] = m.words[w] & (bitmask ^ ~((size_t)0))
    return m

public def bitmap_test(m Bitmap, i size_t) -> int:
    if i >= m.bits:
        return 0
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t bitmask = (size_t)1 << (int)bit
    if (m.words[w] & bitmask) != (size_t)0:
        return 1
    return 0

public def bitmap_flip(m Bitmap, i size_t) -> Bitmap:
    if i >= m.bits:
        return m
    size_t w = i / (size_t)64
    size_t bit = i % (size_t)64
    size_t bitmask = (size_t)1 << (int)bit
    if (m.words[w] & bitmask) == (size_t)0:
        m.count = m.count + (size_t)1
    else:
        m.count = m.count - (size_t)1
    m.words[w] = m.words[w] ^ bitmask
    return m

public def _bm_low_partial(n size_t) -> size_t:
    if n == (size_t)0:
        return ~((size_t)0)
    return ((size_t)1 << (int)n) - (size_t)1

public def _bm_recount(m Bitmap) -> Bitmap:
    size_t total = (size_t)0
    size_t i = (size_t)0
    for i in range((int)m.nwords):
        total = total + (size_t)_bm_pc_w(m, m.words[i])
    m.count = total
    return m

public def bitmap_set_range(m Bitmap, lo size_t, hi size_t) -> Bitmap:
    if lo >= m.bits:
        return m
    if hi > m.bits:
        hi = m.bits
    if hi <= lo:
        return m
    size_t wl = lo / (size_t)64
    size_t bl = lo % (size_t)64
    size_t wr = (hi - (size_t)1) / (size_t)64
    size_t br = hi % (size_t)64
    if wl == wr:
        size_t wordmask = (_bm_low_partial(br)) ^ (((size_t)1 << (int)bl) - (size_t)1)
        m.words[wl] = m.words[wl] | wordmask
        m = _bm_recount(m)
        return m
    m.words[wl] = m.words[wl] | _bm_highmask(bl)
    size_t w = wl + (size_t)1
    while w < wr:
        m.words[w] = ~((size_t)0)
        w = w + (size_t)1
    m.words[wr] = m.words[wr] | _bm_low_partial(br)
    m = _bm_recount(m)
    return m

public def bitmap_clear_range(m Bitmap, lo size_t, hi size_t) -> Bitmap:
    if lo >= m.bits:
        return m
    if hi > m.bits:
        hi = m.bits
    if hi <= lo:
        return m
    size_t wl = lo / (size_t)64
    size_t bl = lo % (size_t)64
    size_t wr = (hi - (size_t)1) / (size_t)64
    size_t br = hi % (size_t)64
    if wl == wr:
        size_t wordmask = (_bm_low_partial(br)) ^ (((size_t)1 << (int)bl) - (size_t)1)
        m.words[wl] = m.words[wl] & (wordmask ^ ~((size_t)0))
        m = _bm_recount(m)
        return m
    m.words[wl] = m.words[wl] & (_bm_highmask(bl) ^ ~((size_t)0))
    size_t w = wl + (size_t)1
    while w < wr:
        m.words[w] = (size_t)0
        w = w + (size_t)1
    m.words[wr] = m.words[wr] & (_bm_low_partial(br) ^ ~((size_t)0))
    m = _bm_recount(m)
    return m

public def bitmap_flip_range(m Bitmap, lo size_t, hi size_t) -> Bitmap:
    if lo >= m.bits:
        return m
    if hi > m.bits:
        hi = m.bits
    if hi <= lo:
        return m
    size_t wl = lo / (size_t)64
    size_t bl = lo % (size_t)64
    size_t wr = (hi - (size_t)1) / (size_t)64
    size_t br = hi % (size_t)64
    if wl == wr:
        size_t wordmask = (_bm_low_partial(br)) ^ (((size_t)1 << (int)bl) - (size_t)1)
        m.words[wl] = m.words[wl] ^ wordmask
        m = _bm_recount(m)
        return m
    m.words[wl] = m.words[wl] ^ _bm_highmask(bl)
    size_t w = wl + (size_t)1
    while w < wr:
        m.words[w] = m.words[w] ^ ~((size_t)0)
        w = w + (size_t)1
    m.words[wr] = m.words[wr] ^ _bm_low_partial(br)
    m = _bm_recount(m)
    return m

public def bitmap_count_range(m Bitmap, lo size_t, hi size_t) -> int:
    if lo >= m.bits:
        return 0
    if hi > m.bits:
        hi = m.bits
    if hi <= lo:
        return 0
    size_t wl = lo / (size_t)64
    size_t bl = lo % (size_t)64
    size_t wr = (hi - (size_t)1) / (size_t)64
    size_t br = hi % (size_t)64
    int total = 0
    if wl == wr:
        size_t wordmask = (_bm_low_partial(br)) ^ (((size_t)1 << (int)bl) - (size_t)1)
        total = _bm_pc_w(m, m.words[wl] & wordmask)
        return total
    total = _bm_pc_w(m, m.words[wl] & _bm_highmask(bl))
    size_t w = wl + (size_t)1
    while w < wr:
        total = total + _bm_pc_w(m, m.words[w])
        w = w + (size_t)1
    total = total + _bm_pc_w(m, m.words[wr] & _bm_low_partial(br))
    return total

public def bitmap_count(m Bitmap) -> size_t:
    return m.count

public def bitmap_recount(m Bitmap) -> Bitmap:
    return _bm_recount(m)

public def bitmap_any(m Bitmap) -> int:
    size_t i = (size_t)0
    for i in range((int)m.nwords):
        if m.words[i] != (size_t)0:
            return 1
    return 0

public def bitmap_clear_all(m Bitmap) -> Bitmap:
    size_t i = (size_t)0
    for i in range((int)m.nwords):
        m.words[i] = (size_t)0
    m.count = (size_t)0
    return m

public def bitmap_to_words(m Bitmap) -> size_t*:
    return m.words