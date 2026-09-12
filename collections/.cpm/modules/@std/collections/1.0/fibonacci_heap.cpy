import stdlib

# FibonacciHeap: a meldable min-priority queue with lazy O(1) insert and meld
# and O(log n) amortized extract-min. Prioritized for theoretical /
# large-dropworkloads where meld-heavy usage benefits from the O(1) union; the
# constant factors are higher than a pairing heap in practice. Nodes are kept
# in circular, doubly-linked `left`/`right` sibling rings (one ring for roots,
# one per child set). Decrease-key is not offered (no node handles). Structs
# are passed by value; mutators return the updated FibonacciHeap.
# NOTE (codegen): chained pointer fields are avoided; multi-level pointer
# arrays are built via a void* intermediate and a local cast (see
# _fib_consolidate).
struct FibNode:
    FibNode* right
    FibNode* left
    FibNode* child
    size_t degree
    int key

struct FibHeap:
    FibNode* min
    size_t size

public def create_fibonacci_heap() -> FibHeap:
    FibHeap h
    h.min = 0
    h.size = (size_t)0
    return h

# Insert a key (O(1), amortized). Returns the updated heap.
public def fibonacci_heap_insert(h FibHeap, key int) -> FibHeap:
    FibNode* n = new FibNode
    n.key = key
    n.child = 0
    n.degree = (size_t)0
    n.left = n
    n.right = n
    if h.min == 0:
        h.min = n
        h.size = (size_t)1
        return h
    n.right = h.min
    FibNode* mn = h.min
    FibNode* mnl = mn.left
    n.left = mnl
    mnl.right = n
    mn.left = n
    if n.key < mn.key:
        h.min = n
    h.size += (size_t)1
    return h

# Meld two heaps into one (O(1)). Returns the resulting heap.
public def fibonacci_heap_meld(a FibHeap, b FibHeap) -> FibHeap:
    if b.size == (size_t)0:
        return a
    if a.size == (size_t)0:
        return b
    FibNode* aa = a.min
    FibNode* bb = b.min
    FibNode* a1 = aa.right
    FibNode* b2 = bb.left
    aa.right = bb
    bb.left = aa
    a1.left = b2
    b2.right = a1
    if bb.key < aa.key:
        a.min = bb
    a.size = a.size + b.size
    return a

# Peek at the smallest key (caller should check is_empty first).
public def fibonacci_heap_top(h FibHeap) -> int:
    FibNode* mn = h.min
    return mn.key

# Meld together the trees of equal root degree, rebuilding the root ring.
# Buckets are sized for degree <= 127; test workloads stay far below that.
public def _fib_consolidate(h FibHeap) -> FibHeap:
    FibNode* start = h.min
    size_t cnt = (size_t)0
    FibNode* w = start
    int run = 1
    while run == 1:
        cnt += (size_t)1
        w = w.right
        if w == start:
            run = 0
    void* rawr = malloc(cnt * (size_t)sizeof(void*))
    FibNode** roots = (FibNode**)rawr
    w = h.min
    int k = 0
    run = 1
    while run == 1:
        roots[k] = w
        k = k + 1
        w = w.right
        if w == h.min:
            run = 0
    void* rawb = malloc((size_t)128 * (size_t)sizeof(void*))
    FibNode** bk = (FibNode**)rawb
    int i = 0
    while i < 128:
        bk[i] = 0
        i = i + 1
    i = 0
    while i < (int)cnt:
        FibNode* x = roots[i]
        size_t d = x.degree
        if d >= (size_t)128:
            d = (size_t)127
        int run2 = 1
        while run2 == 1:
            if bk[d] == 0:
                run2 = 0
            else:
                FibNode* y = bk[d]
                if y.key < x.key:
                    FibNode* tt = x
                    x = y
                    y = tt
                FibNode* yl = y.left
                FibNode* yr = y.right
                yl.right = yr
                yr.left = yl
                FibNode* fc = x.child
                if fc != 0:
                    FibNode* fl = fc.left
                    y.left = fl
                    y.right = fc
                    fl.right = y
                    fc.left = y
                else:
                    y.left = y
                    y.right = y
                x.child = y
                x.degree = x.degree + (size_t)1
                bk[d] = 0
                d = d + (size_t)1
                if d >= (size_t)128:
                    d = (size_t)127
        bk[d] = x
        i = i + 1
    FibNode* newmin = 0
    FibNode* first = 0
    FibNode* last = 0
    i = 0
    while i < 128:
        if bk[i] != 0:
            FibNode* x = bk[i]
            x.left = last
            if last != 0:
                last.right = x
            else:
                first = x
            last = x
            if newmin == 0 or x.key < newmin.key:
                newmin = x
        i = i + 1
    if last != 0:
        last.right = first
    if first != 0:
        first.left = last
    h.min = newmin
    return h

# Remove the smallest key: detaches it, promotes its children into the root
# ring, then consolidates equal-degree trees.
public def fibonacci_heap_pop_top(h FibHeap) -> FibHeap:
    if h.size == (size_t)0:
        return h
    size_t sz = h.size - (size_t)1
    FibNode* z = h.min
    h.size = sz
    if sz == (size_t)0:
        h.min = 0
        return h
    FibNode* L = z.left
    FibNode* R = z.right
    if L == z:
        h.min = z.child
        if z.child != 0:
            return _fib_consolidate(h)
        h.min = 0
        return h
    L.right = R
    R.left = L
    if z.child != 0:
        FibNode* c = z.child
        FibNode* last = c.left
        L.right = c
        c.left = L
        last.right = R
        R.left = last
    h.min = R
    return _fib_consolidate(h)

public def fibonacci_heap_size(h FibHeap) -> size_t:
    return h.size

public def fibonacci_heap_is_empty(h FibHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# Returns n's degree, or -1 if children violate heap order / the degree count.
public def _fib_check(n FibNode*) -> int:
    if n == 0:
        return 0
    int deg = 0
    FibNode* c = n.child
    if c != 0:
        FibNode* start = c
        int run = 1
        while run == 1:
            if c.key < n.key:
                return -1
            int cd = _fib_check(c)
            if cd < 0:
                return -1
            c = c.right
            deg = deg + 1
            if c == start:
                run = 0
    if deg != (int)n.degree:
        return -1
    return deg

# 1 if the heap is well formed: a closed root ring, every tree heap-ordered,
# h.min really the minimum, and the walk count matches size.
public def fibonacci_heap_validate(h FibHeap) -> int:
    size_t n = h.size
    if n == (size_t)0:
        if h.min == 0:
            return 1
        return 0
    if h.min == 0:
        return 0
    FibNode* mn = h.min
    size_t count = (size_t)0
    FibNode* w = h.min
    FibNode* start = w
    int run = 1
    int ok = 1
    while run == 1:
        if w.key < mn.key:
            ok = 0
        int cd = _fib_check(w)
        if cd < 0:
            ok = 0
        count += (size_t)1
        w = w.right
        if w == start:
            run = 0
    if ok == 0:
        return 0
    if count != n:
        return 0
    return 1