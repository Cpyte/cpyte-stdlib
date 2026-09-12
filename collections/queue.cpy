import stdlib
import "mem.cpy"

# Queue (FIFO). Circular buffer of void* elements with power-of-two capacity;
# slot = (front + n) & mask avoids the modulo in every index computation.
# Structs are passed by value: field-mutating ops return the updated Queue.
struct Queue:
    void** data
    size_t capacity
    size_t length
    size_t front
    size_t back

public def _q_next_pow2(n size_t) -> size_t:
    if n < (size_t)2:
        return (size_t)1
    size_t p = (size_t)1
    while p < n:
        p = p * (size_t)2
    return p

public def create_queue(cap size_t) -> Queue:
    assert cap >= (size_t)1, "Value Error: You cannot create a queue of capacity below 1"
    Queue q
    q.capacity = _q_next_pow2(cap)
    q.data = (void**)malloc(q.capacity * (size_t)sizeof(void*))
    q.length = (size_t)0
    q.front = (size_t)0
    q.back = (size_t)0
    return q

# Grow capacity in place. realloc preserves the slab, then any wrapped
# elements are compacted to start at slot 0 so the new bitmask maps every
# logical index onto the right physical slot.
public def _queue_grow(q Queue) -> Queue:
    size_t new_size = q.capacity * (size_t)2
    size_t oldcap = q.capacity
    q.data = (void**)realloc(q.data, new_size * (size_t)sizeof(void*))
    q.capacity = new_size
    if q.front != (size_t)0:
        size_t word = (size_t)sizeof(void*)
        size_t m = oldcap - q.front
        buf_move((void*)q.data,
                 (void*)((char*)q.data + (int)(q.front * word)),
                 m * word)
        if q.length > m:
            buf_move((void*)((char*)q.data + (int)(m * word)),
                     (void*)q.data,
                     (q.length - m) * word)
        q.front = (size_t)0
    # back may have wrapped modulo the OLD capacity; rebase it to the tail.
    q.back = q.length
    return q

# Enqueue at the back. Returns the updated Queue.
public def queue_push(q Queue, value void*) -> Queue:
    if q.length >= q.capacity:
        q = _queue_grow(q)
    size_t mask = q.capacity - (size_t)1
    q.data[q.back] = value
    q.back = (q.back + (size_t)1) & mask
    q.length = q.length + (size_t)1
    return q

# Dequeue from the front and return the updated Queue.
# Read the value first with queue_front if you need it.
public def queue_pop(q Queue) -> Queue:
    if q.length == (size_t)0:
        return q
    size_t mask = q.capacity - (size_t)1
    q.front = (q.front + (size_t)1) & mask
    q.length = q.length - (size_t)1
    return q

# Peek at the front element without removing it.
public def queue_front(q Queue) -> void*:
    if q.length == (size_t)0:
        return (void*)0
    return q.data[q.front]

public def queue_size(q Queue) -> size_t:
    return q.length

public def queue_is_empty(q Queue) -> bool:
    return q.length == (size_t)0