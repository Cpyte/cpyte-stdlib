import stdlib
import "mem.cpy"

# Deque: double-ended queue over a contiguous slab with power-of-two
# capacity, so front/back index arithmetic is a bitwise AND (no per-op modulo).
# Growth reallocs in place (no element-by-element copy). Struct is passed by
# value; field-mutating ops return the updated Deque.
#
# LAYOUT LOCKED: the runtime hook (runtime_hooks.py / deque_to_list) reads
# {void* data; size_t capacity; size_t length; size_t front}. Keep field order.
struct Deque:
    void** data
    size_t capacity
    size_t length
    size_t front

ccode:
    #include <stddef.h>
    #include <stdlib.h>
    extern void *cpyte_array_alloc(size_t elem_size, size_t count);
    typedef struct { int kind; long long data; } dq_dynval;
    void* deque_to_list(void *deque) {
        typedef struct { void *data; size_t capacity; size_t length; size_t front; } dq_t;
        dq_t *dq = (dq_t *)deque;
        size_t n = dq->length;
        dq_dynval *arr = (dq_dynval*)cpyte_array_alloc(sizeof(dq_dynval), n);
        void **src = (void **)dq->data;
        size_t mask = dq->capacity - 1u;
        for (size_t i = 0; i < n; i++) {
            size_t idx = (dq->front + i) & mask;
            arr[i] = *(dq_dynval *)src[idx];
        }
        return (void*)arr;
    }

public def _dq_next_pow2(n size_t) -> size_t:
    size_t p = 1
    while p < n:
        p = p * (size_t)2
    return p

public def create_deque(cap size_t) -> Deque:
    assert cap >= (size_t)1, "Value Error: You cannot create a deque of capacity below 1"
    Deque list
    list.capacity = _dq_next_pow2(cap)
    list.data = (void**)malloc(list.capacity * (size_t)sizeof(void*))
    list.length = (size_t)0
    list.front = (size_t)0
    return list

public def deque_capacity(list Deque) -> size_t:
    return list.capacity

public def deque_length(list Deque) -> size_t:
    return list.length

# Logical (front-relative) index i -> physical slot.
public def _dq_slot(list Deque, i size_t) -> size_t:
    size_t mask = list.capacity - (size_t)1
    return (list.front + i) & mask

public def get(list Deque, i size_t) -> void*:
    assert i < list.length, "Index out of bounds"
    return list.data[_dq_slot(list, i)]

# Grow capacity in place. realloc preserves the slab, then any wrapped
# elements are compacted to start at slot 0 (front=0) so the new bitmask maps
# every logical index onto the right physical slot.
public def grow_list(list Deque, new_size size_t) -> Deque:
    assert new_size >= list.length, "Value Error: You can't shrink an deque list"
    size_t oldcap = list.capacity
    size_t word = (size_t)sizeof(void*)
    list.data = (void**)realloc(list.data, new_size * (size_t)sizeof(void*))
    list.capacity = new_size
    if list.front != (size_t)0:
        size_t m = oldcap - list.front
        buf_move((void*)list.data,
                 (void*)((char*)list.data + (int)(list.front * word)),
                 m * word)
        if list.length > m:
            buf_move((void*)((char*)list.data + (int)(m * word)),
                     (void*)list.data,
                     (list.length - m) * word)
        list.front = (size_t)0
    return list

# Push at the back. Amortized O(1).
public def push_back(list Deque, value void*) -> Deque:
    if list.length >= list.capacity:
        list = grow_list(list, list.capacity * (size_t)2)
    list.data[_dq_slot(list, list.length)] = value
    list.length = list.length + (size_t)1
    return list

# Push at the front. Amortized O(1).
public def push_front(list Deque, value void*) -> Deque:
    if list.length >= list.capacity:
        list = grow_list(list, list.capacity * (size_t)2)
    size_t mask = list.capacity - (size_t)1
    list.front = (list.front - (size_t)1) & mask
    list.data[list.front] = value
    list.length = list.length + (size_t)1
    return list

# Pop (remove) from the front. Returns the updated Deque; read the value first
# with get(list, 0).
public def pop_front(list Deque) -> Deque:
    if list.length == (size_t)0:
        return list
    size_t mask = list.capacity - (size_t)1
    list.front = (list.front + (size_t)1) & mask
    list.length = list.length - (size_t)1
    return list

# Pop from the back. Returns the updated Deque; read the value first with
# get(list, length-1).
public def pop_back(list Deque) -> Deque:
    if list.length == (size_t)0:
        return list
    list.length = list.length - (size_t)1
    return list

public def deque_front(list Deque) -> void*:
    if list.length == (size_t)0:
        return 0
    return list.data[list.front]

public def deque_back(list Deque) -> void*:
    if list.length == (size_t)0:
        return 0
    return list.data[_dq_slot(list, list.length - (size_t)1)]

public def to_list(d Deque) -> dynamic:
    return d.data