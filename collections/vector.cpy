import stdlib
import "mem.cpy"

# Dynamic array / Vector. Growable contiguous buffer of void* elements backed
# by a single heap slab.
# Structs are passed by value: field-mutating ops return the updated Vector.
# Growth uses realloc in place (no allocation+copy churn); insert/erase shift
# the tail with one memmove instead of allocating a fresh buffer per op.
struct Vector:
    void** data
    size_t capacity
    size_t length

public def create_vector(cap size_t) -> Vector:
    assert cap >= (size_t)1, "Value Error: You cannot create a vector of capacity below 1"
    Vector v
    v.capacity = cap
    v.data = (void**)malloc(cap * (size_t)sizeof(void*))
    v.length = (size_t)0
    return v

# Grow capacity in place. realloc preserves the existing elements, so a push
# that hits the ceiling costs one call instead of malloc + element-by-element
# copy.
public def _vector_grow(v Vector) -> Vector:
    size_t new_size = v.capacity * (size_t)2
    assert new_size > v.capacity, "Value Error: vector capacity overflow"
    v.data = (void**)realloc(v.data, new_size * (size_t)sizeof(void*))
    v.capacity = new_size
    return v

# Push at the back. Returns the updated Vector. Amortized O(1).
public def vector_push(v Vector, value void*) -> Vector:
    if v.length >= v.capacity:
        v = _vector_grow(v)
    v.data[v.length] = value
    v.length = v.length + (size_t)1
    return v

# Pop the last element and return the updated Vector. Read value first with
# vector_get(v, v.length-1).
public def vector_pop(v Vector) -> Vector:
    if v.length == (size_t)0:
        return v
    v.length = v.length - (size_t)1
    return v

public def vector_get(v Vector, i size_t) -> void*:
    assert i < v.length, "Index out of bounds"
    return v.data[i]

public def vector_set(v Vector, i size_t, value void*) -> void*:
    assert i < v.length, "Index out of bounds"
    v.data[i] = value
    return value

# Insert at index i, shifting subsequent elements right in place via one
# memmove (no fresh buffer). Returns the updated Vector.
public def vector_insert(v Vector, i size_t, value void*) -> Vector:
    if i > v.length:
        return v
    if v.length >= v.capacity:
        v = _vector_grow(v)
    if i < v.length:
        size_t word = (size_t)sizeof(void*)
        void* dst = (void*)((char*)v.data + (int)((i + (size_t)1) * word))
        void* src = (void*)((char*)v.data + (int)(i * word))
        size_t nbytes = (v.length - i) * word
        buf_move(dst, src, nbytes)
    v.data[i] = value
    v.length = v.length + (size_t)1
    return v

# Remove the element at index i, shifting subsequent elements left in place
# via one memmove. Returns the updated Vector.
public def vector_erase(v Vector, i size_t) -> Vector:
    if i >= v.length:
        return v
    if i + (size_t)1 < v.length:
        size_t word = (size_t)sizeof(void*)
        void* dst = (void*)((char*)v.data + (int)(i * word))
        void* src = (void*)((char*)v.data + (int)((i + (size_t)1) * word))
        size_t nbytes = (v.length - i - (size_t)1) * word
        buf_move(dst, src, nbytes)
    v.length = v.length - (size_t)1
    return v

public def vector_size(v Vector) -> size_t:
    return v.length

public def vector_capacity(v Vector) -> size_t:
    return v.capacity

public def vector_is_empty(v Vector) -> bool:
    return v.length == (size_t)0