import stdlib

# DaryHeap: a d-ary heap (min-order) whose branching factor is configurable at
# creation time. Each node has up to `arity` children, so sift-down examines at
# most `arity` candidates per level. arity = 2 coincides with an ordinary
# binary min-heap; larger arities produce shallower trees with more work per
# level. Elements are stored by value in a growable int array; mutators return
# the updated heap (`h = dary_heap_push(h, v)`).
struct DaryHeap:
    int* data
    size_t capacity
    size_t size
    int arity

public def create_dary_heap(cap size_t, arity int) -> DaryHeap:
    assert cap >= (size_t)1, "Value Error: you cannot create a heap of capacity below 1"
    assert arity >= 2, "Value Error: a d-ary heap needs arity >= 2"
    DaryHeap h
    h.capacity = cap
    h.data = malloc(cap * (size_t)sizeof(int))
    h.size = (size_t)0
    h.arity = arity
    return h

public def _dh_grow(h DaryHeap) -> DaryHeap:
    size_t new_size = h.capacity * (size_t)2
    DaryHeap nh
    nh.capacity = new_size
    nh.data = malloc(new_size * (size_t)sizeof(int))
    nh.size = h.size
    nh.arity = h.arity
    int i = 0
    while i < (int)h.size:
        nh.data[i] = h.data[i]
        i += 1
    return nh

public def _dh_parent(k int, a int) -> int:
    return (k - 1) / a

public def _dh_swap(h DaryHeap, i int, j int) -> void:
    int tmp = h.data[i]
    h.data[i] = h.data[j]
    h.data[j] = tmp

public def _dh_sift_up(h DaryHeap, k int) -> void:
    int run = 1
    int a = h.arity
    while run == 1:
        if k <= 0:
            run = 0
        else:
            int p = _dh_parent(k, a)
            if h.data[k] < h.data[p]:
                _dh_swap(h, k, p)
                k = p
            else:
                run = 0

public def _dh_sift_down(h DaryHeap, k int) -> void:
    int run = 1
    int a = h.arity
    int hs = (int)h.size
    while run == 1:
        int first = k * a + 1
        if first >= hs:
            run = 0
        else:
            int m = first
            int j = 2
            while j <= a:
                int idx = k * a + j
                if idx < hs and h.data[idx] < h.data[m]:
                    m = idx
                j = j + 1
            if h.data[m] < h.data[k]:
                _dh_swap(h, m, k)
                k = m
            else:
                run = 0

# Insert a value. Returns the updated heap.
public def dary_heap_push(h DaryHeap, value int) -> DaryHeap:
    if h.size >= h.capacity:
        h = _dh_grow(h)
    int idx = (int)h.size
    h.data[idx] = value
    h.size += (size_t)1
    _dh_sift_up(h, idx)
    return h

# Remove the smallest element; read it first with dary_heap_top.
public def dary_heap_pop(h DaryHeap) -> DaryHeap:
    if h.size == (size_t)0:
        return h
    h.size -= (size_t)1
    if h.size == (size_t)0:
        return h
    int idx = (int)h.size
    h.data[0] = h.data[idx]
    _dh_sift_down(h, 0)
    return h

# Peek at the smallest element (caller should check is_empty first).
public def dary_heap_top(h DaryHeap) -> int:
    return h.data[0]

public def dary_heap_size(h DaryHeap) -> size_t:
    return h.size

public def dary_heap_is_empty(h DaryHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# 1 if every node is <= all of its arity children.
public def dary_heap_validate(h DaryHeap) -> int:
    int k = 0
    int ok = 1
    int a = h.arity
    int hs = (int)h.size
    while ok == 1 and k < hs:
        int j = 1
        while j <= a:
            int idx = k * a + j
            if idx < hs and h.data[idx] < h.data[k]:
                ok = 0
            j = j + 1
        k += 1
    return ok