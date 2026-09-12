import stdlib

# Fixed-size contiguous array of void* elements.
# capacity is fixed at creation; length tracks the number of elements
# actually stored. Accessing past length is out of bounds.
# NOTE: structs are passed by value, so mutators that change fields return
# the updated Array; heap pointer writes (data[i]) persist on their own.
struct Array:
    void** data
    size_t capacity
    size_t length

public def create_array(cap size_t) -> Array:
    assert cap >= (size_t)1, "Value Error: You cannot create an array of capacity below 1"
    Array arr
    arr.capacity = cap
    arr.data = (void**)malloc(cap * (size_t)sizeof(void*))
    arr.length = (size_t)0
    return arr

public def array_capacity(arr Array) -> size_t:
    return arr.capacity

public def array_length(arr Array) -> size_t:
    return arr.length

public def array_is_empty(arr Array) -> bool:
    return arr.length == (size_t)0

public def array_is_full(arr Array) -> bool:
    return arr.length == arr.capacity

# Get the element at index i (0-based).
public def array_get(arr Array, i size_t) -> void*:
    assert i < arr.length, "Index out of bounds"
    return arr.data[i]

# Set the element at index i and return the updated Array.
# length is updated to i+1 if i >= length.
public def array_set(arr Array, i size_t, value void*) -> Array:
    assert i < arr.capacity, "Index out of bounds"
    arr.data[i] = value
    if i >= arr.length:
        arr.length = i + (size_t)1
    return arr

# Append at the end. Returns (updated Array, 0) via return; a full array
# returns an unchanged Array plus -1 is impossible with a single return, so
# this asserts instead. Callers that need failure codes should use a
# pre-check with array_is_full.
public def array_push(arr Array, value void*) -> Array:
    assert arr.length < arr.capacity, "Value Error: array is full"
    arr.data[arr.length] = value
    arr.length = arr.length + (size_t)1
    return arr
