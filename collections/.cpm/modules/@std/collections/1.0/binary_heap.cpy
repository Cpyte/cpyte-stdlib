import stdlib

# BinaryHeap: an implicit complete binary tree over a growable int array used
# as a priority queue. Min-order by default (smallest value has highest
# priority / sits at the top); set max_mode = 1 in create_binary_heap for a
# max-order priority queue. The mode is fixed at creation. Elements are stored
# by value; mutators return the updated BinaryHeap (`h = binary_heap_push(h, v)`).
struct BinaryHeap:
    int* data
    size_t capacity
    size_t size
    int max_mode

public def create_binary_heap(cap size_t, max_mode int) -> BinaryHeap:
    assert cap >= (size_t)1, "Value Error: you cannot create a heap of capacity below 1"
    BinaryHeap h
    h.capacity = cap
    h.data = malloc(cap * (size_t)sizeof(int))
    h.size = (size_t)0
    h.max_mode = max_mode
    return h

public def create_binary_minheap(cap size_t) -> BinaryHeap:
    return create_binary_heap(cap, 0)

public def create_binary_maxheap(cap size_t) -> BinaryHeap:
    return create_binary_heap(cap, 1)

public def _heap_grow(h BinaryHeap) -> BinaryHeap:
    size_t new_size = h.capacity * (size_t)2
    BinaryHeap nh
    nh.capacity = new_size
    nh.data = malloc(new_size * (size_t)sizeof(int))
    nh.size = h.size
    nh.max_mode = h.max_mode
    int i = 0
    while i < (int)h.size:
        nh.data[i] = h.data[i]
        i += 1
    return nh

# 1 if value a ranks above value b for this heap's ordering.
public def _heap_prefers(h BinaryHeap, a int, b int) -> int:
    if h.max_mode == 1:
        if a > b:
            return 1
        return 0
    if a < b:
        return 1
    return 0

public def _heap_swap(h BinaryHeap, i int, j int) -> void:
    int tmp = h.data[i]
    h.data[i] = h.data[j]
    h.data[j] = tmp

public def _heap_sift_up(h BinaryHeap, k int) -> void:
    int run = 1
    while run == 1:
        if k <= 0:
            run = 0
        else:
            int p = (k - 1) / 2
            if _heap_prefers(h, h.data[k], h.data[p]) == 1:
                _heap_swap(h, k, p)
                k = p
            else:
                run = 0

public def _heap_sift_down(h BinaryHeap, k int) -> void:
    int run = 1
    int hs = (int)h.size
    while run == 1:
        int left = k * 2 + 1
        if left >= hs:
            run = 0
        else:
            int right = left + 1
            int m = left
            if right < hs and _heap_prefers(h, h.data[right], h.data[left]) == 1:
                m = right
            if _heap_prefers(h, h.data[m], h.data[k]) == 1:
                _heap_swap(h, m, k)
                k = m
            else:
                run = 0

# Insert a value. Returns the updated heap.
public def binary_heap_push(h BinaryHeap, value int) -> BinaryHeap:
    if h.size >= h.capacity:
        h = _heap_grow(h)
    int idx = (int)h.size
    h.data[idx] = value
    h.size += (size_t)1
    _heap_sift_up(h, idx)
    return h

# Remove the top value; read it first with binary_heap_top.
public def binary_heap_pop(h BinaryHeap) -> BinaryHeap:
    if h.size == (size_t)0:
        return h
    h.size -= (size_t)1
    if h.size == (size_t)0:
        return h
    int idx = (int)h.size
    h.data[0] = h.data[idx]
    _heap_sift_down(h, 0)
    return h

# Peek at the top value (caller should check is_empty first).
public def binary_heap_top(h BinaryHeap) -> int:
    return h.data[0]

public def binary_heap_size(h BinaryHeap) -> size_t:
    return h.size

public def binary_heap_is_empty(h BinaryHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# 1 if every node outranks all of its children for this heap's ordering.
public def binary_heap_validate(h BinaryHeap) -> int:
    int k = 0
    int ok = 1
    int hs = (int)h.size
    while ok == 1 and k < hs:
        int left = k * 2 + 1
        int right = left + 1
        if left < hs and _heap_prefers(h, h.data[left], h.data[k]) == 1:
            ok = 0
        if ok == 1 and right < hs and _heap_prefers(h, h.data[right], h.data[k]) == 1:
            ok = 0
        k += 1
    return ok