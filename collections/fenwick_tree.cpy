import stdlib

# FenwickTree (Binary Indexed Tree): prefix/range sum queries and point
# updates in O(log n) over an implicit 1-based array of n ints. Indexes used
# by callers are 0-based. All state lives on the heap, so updates persist even
# though the Fenwick struct is passed by value; mutators still return the
# container for the convention `f = fenwick_add(f, i, d)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*p).field.
struct Fenwick:
    int* bit
    size_t n

public def create_fenwick(n size_t) -> Fenwick:
    Fenwick f
    size_t cap = n + (size_t)1
    f.bit = malloc(cap * (size_t)sizeof(int))
    f.n = n
    size_t i = (size_t)0
    while i < cap:
        f.bit[i] = 0
        i += (size_t)1
    return f

# Adds delta to element idx (0-based).
public def fenwick_add(f Fenwick, idx int, delta int) -> Fenwick:
    size_t i = (size_t)(idx + 1)
    while i <= f.n:
        f.bit[i] = f.bit[i] + delta
        i = i + (i & (~i + (size_t)1))
    return f

# Sum of elements [0, idx], inclusive (0-based). 0 when idx < 0.
public def fenwick_prefix(f Fenwick, idx int) -> int:
    size_t i = (size_t)(idx + 1)
    int s = 0
    while i > (size_t)0:
        s = s + f.bit[i]
        i = i - (i & (~i + (size_t)1))
    return s

# Sum over [l, r], inclusive (0-based).
public def fenwick_range_sum(f Fenwick, l int, r int) -> int:
    int hi = fenwick_prefix(f, r)
    int lo = 0
    if l > 0:
        lo = fenwick_prefix(f, l - 1)
    return hi - lo

# Value at index idx (0-based).
public def fenwick_point(f Fenwick, idx int) -> int:
    int lo = 0
    if idx > 0:
        lo = fenwick_prefix(f, idx - 1)
    return fenwick_prefix(f, idx) - lo

public def fenwick_size(f Fenwick) -> size_t:
    return f.n

public def fenwick_is_empty(f Fenwick) -> int:
    int e = 0
    if f.n == (size_t)0:
        e = 1
    return e