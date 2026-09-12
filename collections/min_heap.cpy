import stdlib

# MinHeap: a min-oriented binary heap. The smallest element is always at the
# top. Elements are stored by value in a growable int array; mutators return
# the updated MinHeap (`h = min_heap_push(h, v)`). See also max_heap.cpy
# (largest first) and binary_heap.cpy (mode-configurable priority queue).
struct MinHeap:
    int* data
    size_t capacity
    size_t size

public def create_min_heap(cap size_t) -> MinHeap:
    assert cap >= (size_t)1, "Value Error: you cannot create a heap of capacity below 1"
    MinHeap h
    h.capacity = cap
    h.data = malloc(cap * (size_t)sizeof(int))
    h.size = (size_t)0
    return h

public def _minhp_grow(h MinHeap) -> MinHeap:
    size_t new_size = h.capacity * (size_t)2
    MinHeap nh
    nh.capacity = new_size
    nh.data = malloc(new_size * (size_t)sizeof(int))
    nh.size = h.size
    int i = 0
    while i < (int)h.size:
        nh.data[i] = h.data[i]
        i += 1
    return nh

public def _minhp_swap(h MinHeap, i int, j int) -> void:
    int tmp = h.data[i]
    h.data[i] = h.data[j]
    h.data[j] = tmp

public def _minhp_sift_up(h MinHeap, k int) -> void:
    int run = 1
    while run == 1:
        if k <= 0:
            run = 0
        else:
            int p = (k - 1) / 2
            if h.data[k] < h.data[p]:
                _minhp_swap(h, k, p)
                k = p
            else:
                run = 0

public def _minhp_sift_down(h MinHeap, k int) -> void:
    int run = 1
    int hs = (int)h.size
    while run == 1:
        int left = k * 2 + 1
        if left >= hs:
            run = 0
        else:
            int right = left + 1
            int m = left
            if right < hs and h.data[right] < h.data[left]:
                m = right
            if h.data[m] < h.data[k]:
                _minhp_swap(h, m, k)
                k = m
            else:
                run = 0

# Insert a value. Returns the updated heap.
public def min_heap_push(h MinHeap, value int) -> MinHeap:
    if h.size >= h.capacity:
        h = _minhp_grow(h)
    int idx = (int)h.size
    h.data[idx] = value
    h.size += (size_t)1
    _minhp_sift_up(h, idx)
    return h

# Remove the smallest element; read it first with min_heap_top.
public def min_heap_pop(h MinHeap) -> MinHeap:
    if h.size == (size_t)0:
        return h
    h.size -= (size_t)1
    if h.size == (size_t)0:
        return h
    int idx = (int)h.size
    h.data[0] = h.data[idx]
    _minhp_sift_down(h, 0)
    return h

# Peek at the smallest element (caller should check is_empty first).
public def min_heap_top(h MinHeap) -> int:
    return h.data[0]

public def min_heap_size(h MinHeap) -> size_t:
    return h.size

public def min_heap_is_empty(h MinHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# 1 if every node is <= all of its children.
public def min_heap_validate(h MinHeap) -> int:
    int k = 0
    int ok = 1
    int hs = (int)h.size
    while ok == 1 and k < hs:
        int left = k * 2 + 1
        int right = left + 1
        if left < hs and h.data[left] < h.data[k]:
            ok = 0
        if ok == 1 and right < hs and h.data[right] < h.data[k]:
            ok = 0
        k += 1
    return ok