import stdlib

# Circular / Ring buffer. Fixed-size streaming buffer of void* elements.
# Overwrites the oldest element when full (rolling overwrite).
# Structs are passed by value: field-mutating ops return the updated buffer.
struct RingBuffer:
    void** data
    size_t capacity
    size_t length
    size_t head
    size_t tail

public def create_ring(cap size_t) -> RingBuffer:
    assert cap >= (size_t)1, "Value Error: You cannot create a ring buffer of capacity below 1"
    RingBuffer rb
    rb.capacity = cap
    rb.data = malloc(cap * (size_t)sizeof(void*))
    rb.length = (size_t)0
    rb.head = (size_t)0
    rb.tail = (size_t)0
    return rb

public def ring_capacity(rb RingBuffer) -> size_t:
    return rb.capacity

public def ring_length(rb RingBuffer) -> size_t:
    return rb.length

public def ring_is_empty(rb RingBuffer) -> bool:
    return rb.length == (size_t)0

public def ring_is_full(rb RingBuffer) -> bool:
    return rb.length == rb.capacity

# Write an element, returning the updated buffer. If full, the oldest is
# overwritten (position advanced) so writes never fail on a full ring.
public def ring_write(rb RingBuffer, value void*) -> RingBuffer:
    rb.data[rb.tail] = value
    if rb.length == rb.capacity:
        rb.head = (rb.head + (size_t)1) % (int)rb.capacity
    else:
        rb.length += (size_t)1
    rb.tail = (rb.tail + (size_t)1) % (int)rb.capacity
    return rb

# Read and remove the oldest element, returning the updated buffer.
# Read the value first with ring_peek if you need it.
public def ring_read(rb RingBuffer) -> RingBuffer:
    if rb.length == (size_t)0:
        return rb
    rb.head = (rb.head + (size_t)1) % (int)rb.capacity
    rb.length -= (size_t)1
    return rb

# Peek at the oldest element without removing it.
public def ring_peek(rb RingBuffer) -> void*:
    if rb.length == (size_t)0:
        return 0
    return rb.data[rb.head]
