import stdlib

# Dynamic array / Vector. Growable contiguous buffer of void* elements.
# Structs are passed by value: field-mutating ops return the updated Vector.
struct Vector:
    void** data
    size_t capacity
    size_t length

public def create_vector(cap size_t) -> Vector:
    assert cap >= (size_t)1, "Value Error: You cannot create a vector of capacity below 1"
    Vector v
    v.capacity = cap
    v.data = malloc(cap * (size_t)sizeof(void*))
    v.length = (size_t)0
    return v

public def _vector_grow(v Vector) -> Vector:
    size_t new_size = v.capacity * (size_t)2
    assert new_size > v.capacity, "Value Error: vector capacity overflow"
    Vector nv
    nv.capacity = new_size
    nv.data = malloc(new_size * (size_t)sizeof(void*))
    nv.length = v.length
    for i in range((int)v.length):
        nv.data[i] = v.data[i]
    return nv

# Push at the back. Returns the updated Vector.
public def vector_push(v Vector, value void*) -> Vector:
    if v.length >= v.capacity:
        return vector_push(_vector_grow(v), value)
    v.data[v.length] = value
    v.length += (size_t)1
    return v

# Pop the last element and return the updated Vector. Read value first with
# vector_get(v, v.length-1).
public def vector_pop(v Vector) -> Vector:
    if v.length == (size_t)0:
        return v
    v.length -= (size_t)1
    return v

public def vector_get(v Vector, i size_t) -> void*:
    assert i < v.length, "Index out of bounds"
    return v.data[i]

public def vector_set(v Vector, i size_t, value void*) -> void*:
    assert i < v.length, "Index out of bounds"
    v.data[i] = value
    return value

# Insert at index i, shifting subsequent elements right. Returns the updated
# Vector; use vector_get to retrieve afterward.
public def vector_insert(v Vector, i size_t, value void*) -> Vector:
    if i > v.length:
        return v
    if v.length >= v.capacity:
        v = _vector_grow(v)
    Vector nv
    nv.capacity = v.capacity
    nv.data = malloc(v.capacity * (size_t)sizeof(void*))
    nv.length = v.length + (size_t)1
    size_t src = (size_t)0
    size_t dst = (size_t)0
    while src < v.length:
        if src == i:
            nv.data[dst] = value
            dst = dst + (size_t)1
        nv.data[dst] = v.data[src]
        src = src + (size_t)1
        dst = dst + (size_t)1
    if i == v.length:
        nv.data[dst] = value
    return nv

# Remove and return the updated Vector; read value first with vector_get.
public def vector_erase(v Vector, i size_t) -> Vector:
    if i >= v.length:
        return v
    Vector nv
    nv.capacity = v.capacity
    nv.data = malloc(v.capacity * (size_t)sizeof(void*))
    nv.length = v.length - (size_t)1
    size_t src = (size_t)0
    size_t dst = (size_t)0
    while src < v.length:
        if src != i:
            nv.data[dst] = v.data[src]
            dst = dst + (size_t)1
        src = src + (size_t)1
    return nv

public def vector_size(v Vector) -> size_t:
    return v.length

public def vector_capacity(v Vector) -> size_t:
    return v.capacity

public def vector_is_empty(v Vector) -> bool:
    return v.length == (size_t)0
