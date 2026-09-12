import stdlib

# Circular / Ring buffer. Fixed-size streaming buffer of void* elements backed
# by a power-of-two slab, so head/tail advance with a bitwise AND instead of a
# modulo. Overwrites the oldest element when full (rolling overwrite).
# Structs are passed by value: field-mutating ops return the updated buffer.
struct RingBuffer:
    void** data
    size_t capacity
    size_t length
    size_t head
    size_t tail

public def _rb_next_pow2(n size_t) -> size_t:
    size_t p = 1
    while p < n:
        p = p * (size_t)2
    return p

public def create_ring(cap size_t) -> RingBuffer:
    assert cap >= (size_t)1, "Value Error: You cannot create a ring buffer of capacity below 1"
    RingBuffer rb
    rb.capacity = _rb_next_pow2(cap)
    rb.data = (void**)malloc(rb.capacity * (size_t)sizeof(void*))
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
    size_t mask = rb.capacity - (size_t)1
    if rb.length == rb.capacity:
        rb.head = (rb.head + (size_t)1) & mask
    else:
        rb.length = rb.length + (size_t)1
    rb.tail = (rb.tail + (size_t)1) & mask
    return rb

# Read and remove the oldest element, returning the updated buffer.
# Read the value first with ring_peek if you need it.
public def ring_read(rb RingBuffer) -> RingBuffer:
    if rb.length == (size_t)0:
        return rb
    size_t mask = rb.capacity - (size_t)1
    rb.head = (rb.head + (size_t)1) & mask
    rb.length = rb.length - (size_t)1
    return rb

# Peek at the oldest element without removing it.
public def ring_peek(rb RingBuffer) -> void*:
    if rb.length == (size_t)0:
        return 0
    return rb.data[rb.head]