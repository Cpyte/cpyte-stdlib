import stdlib

# SegmentTree: range queries (sum / min / max) and point updates over n ints
# in O(log n). Implemented recursively over a 4*n backing store (three arrays:
# sum, min, max, kept in sync by every update). Indexes are 0-based, ranges
# inclusive [l, r]. Creates implicitly-zero leaves; fill with seg_set.
# All state lives on the heap, so mutators return the container for the
# convention `g = seg_set(g, i, v)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*p).field.
struct SegmentTree:
    int* sum
    int* mn
    int* mx
    size_t n

public def create_segment_tree(n size_t) -> SegmentTree:
    SegmentTree g
    g.n = n
    size_t cap = (size_t)4 * n + (size_t)4
    g.sum = malloc(cap * (size_t)sizeof(int))
    g.mn = malloc(cap * (size_t)sizeof(int))
    g.mx = malloc(cap * (size_t)sizeof(int))
    size_t i = (size_t)0
    while i < cap:
        g.sum[i] = 0
        g.mn[i] = 0
        g.mx[i] = 0
        i += (size_t)1
    return g

public def _seg_set_rec(tr int*, gmn int*, gmx int*, node int, lo int, hi int, pos int, value int) -> void:
    if lo == hi:
        tr[node] = value
        gmn[node] = value
        gmx[node] = value
        return
    int mid = (lo + hi) / 2
    if pos <= mid:
        _seg_set_rec(tr, gmn, gmx, node * 2, lo, mid, pos, value)
    else:
        _seg_set_rec(tr, gmn, gmx, node * 2 + 1, mid + 1, hi, pos, value)
    tr[node] = tr[node * 2] + tr[node * 2 + 1]
    int l1 = gmn[node * 2]
    int r1 = gmn[node * 2 + 1]
    if l1 <= r1:
        gmn[node] = l1
    else:
        gmn[node] = r1
    int l2 = gmx[node * 2]
    int r2 = gmx[node * 2 + 1]
    if l2 >= r2:
        gmx[node] = l2
    else:
        gmx[node] = r2

public def _seg_sum_rec(tr int*, node int, lo int, hi int, ql int, qr int) -> int:
    if ql <= lo and hi <= qr:
        return tr[node]
    if qr < lo or hi < ql:
        return 0
    int mid = (lo + hi) / 2
    return _seg_sum_rec(tr, node * 2, lo, mid, ql, qr) + _seg_sum_rec(tr, node * 2 + 1, mid + 1, hi, ql, qr)

public def _seg_min_rec(gmn int*, node int, lo int, hi int, ql int, qr int) -> int:
    if ql <= lo and hi <= qr:
        return gmn[node]
    if qr < lo or hi < ql:
        return 2147483647
    int mid = (lo + hi) / 2
    int a = _seg_min_rec(gmn, node * 2, lo, mid, ql, qr)
    int b = _seg_min_rec(gmn, node * 2 + 1, mid + 1, hi, ql, qr)
    if a <= b:
        return a
    return b

public def _seg_max_rec(gmx int*, node int, lo int, hi int, ql int, qr int) -> int:
    if ql <= lo and hi <= qr:
        return gmx[node]
    if qr < lo or hi < ql:
        return -2147483647
    int mid = (lo + hi) / 2
    int a = _seg_max_rec(gmx, node * 2, lo, mid, ql, qr)
    int b = _seg_max_rec(gmx, node * 2 + 1, mid + 1, hi, ql, qr)
    if a >= b:
        return a
    return b

# Sets element pos (0-based) to value.
public def seg_set(g SegmentTree, pos int, value int) -> SegmentTree:
    _seg_set_rec(g.sum, g.mn, g.mx, 1, 0, (int)g.n - 1, pos, value)
    return g

# Sum over [l, r], inclusive (0-based).
public def seg_range_sum(g SegmentTree, l int, r int) -> int:
    return _seg_sum_rec(g.sum, 1, 0, (int)g.n - 1, l, r)

# Minimum over [l, r], inclusive.
public def seg_range_min(g SegmentTree, l int, r int) -> int:
    return _seg_min_rec(g.mn, 1, 0, (int)g.n - 1, l, r)

# Maximum over [l, r], inclusive.
public def seg_range_max(g SegmentTree, l int, r int) -> int:
    return _seg_max_rec(g.mx, 1, 0, (int)g.n - 1, l, r)

# Element at pos (0-based).
public def seg_point(g SegmentTree, pos int) -> int:
    return _seg_sum_rec(g.sum, 1, 0, (int)g.n - 1, pos, pos)

public def seg_size(g SegmentTree) -> size_t:
    return g.n

public def seg_is_empty(g SegmentTree) -> int:
    int e = 0
    if g.n == (size_t)0:
        e = 1
    return e