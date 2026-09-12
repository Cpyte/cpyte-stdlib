import stdlib

# Queue (FIFO). Circular buffer of void* elements.
# Structs are passed by value: field-mutating ops return the updated Queue.
struct Queue:
    void** data
    size_t capacity
    size_t length
    size_t front
    size_t back

public def create_queue(cap size_t) -> Queue:
    assert cap >= (size_t)1, "Value Error: You cannot create a queue of capacity below 1"
    Queue q
    q.capacity = cap
    q.data = malloc(cap * (size_t)sizeof(void*))
    q.length = (size_t)0
    q.front = (size_t)0
    q.back = (size_t)0
    return q

public def _queue_grow(q Queue) -> Queue:
    size_t new_size = q.capacity * (size_t)2
    Queue nq
    nq.capacity = new_size
    nq.data = malloc(new_size * (size_t)sizeof(void*))
    nq.length = q.length
    nq.front = (size_t)0
    for i in range((int)q.length):
        size_t idx = (q.front + (size_t)i) % (int)q.capacity
        nq.data[i] = q.data[idx]
    nq.back = q.length
    return nq

# Enqueue at the back. Returns the updated Queue.
public def queue_push(q Queue, value void*) -> Queue:
    if q.length >= q.capacity:
        return queue_push(_queue_grow(q), value)
    q.data[q.back] = value
    q.back = (q.back + (size_t)1) % (int)q.capacity
    q.length += (size_t)1
    return q

# Dequeue from the front and return the updated Queue.
# Read the value first with queue_front if you need it.
public def queue_pop(q Queue) -> Queue:
    if q.length == (size_t)0:
        return q
    q.front = (q.front + (size_t)1) % (int)q.capacity
    q.length -= (size_t)1
    return q

# Peek at the front element without removing it.
public def queue_front(q Queue) -> void*:
    if q.length == (size_t)0:
        return 0
    return q.data[q.front]

public def queue_size(q Queue) -> size_t:
    return q.length

public def queue_is_empty(q Queue) -> bool:
    return q.length == (size_t)0
