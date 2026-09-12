import stdlib

# MonotonicQueue: a deque utility for sliding-window extrema problems. While
# elements arrive, values are kept in strictly decreasing order (largest in
# front); each value carries the index at which it arrived. When an element
# leaves the window, monotonic_pop(q, index) ejects it iff it is the front
# (older, smaller values were already removed as the window slid). The front
# is always the maximum of every window that covers all retained indices.
#
# Typical sliding-window maximum:
#   for i in range(n over window):
#       q = monotonic_push(q, a[i], i)
#       if i >= w: q = monotonic_pop(q, i - w)
#       if i >= w - 1: max = monotonic_max(q)
#
# Storage is a growable array pair (values + indices); mutators return the
# updated MonotonicQueue. Indices must be passed in strictly increasing order.
struct MonotonicQueue:
    int* data
    int* idx
    size_t capacity
    size_t front
    size_t size

public def create_monotonic_queue(cap size_t) -> MonotonicQueue:
    assert cap >= (size_t)1, "Value Error: you cannot create a queue of capacity below 1"
    MonotonicQueue q
    q.capacity = cap
    q.data = malloc(cap * (size_t)sizeof(int))
    q.idx = malloc(cap * (size_t)sizeof(int))
    q.front = (size_t)0
    q.size = (size_t)0
    return q

public def _mq_grow(q MonotonicQueue) -> MonotonicQueue:
    size_t new_size = q.capacity * (size_t)2
    MonotonicQueue nq
    nq.capacity = new_size
    nq.data = malloc(new_size * (size_t)sizeof(int))
    nq.idx = malloc(new_size * (size_t)sizeof(int))
    nq.front = (size_t)0
    nq.size = q.size
    size_t i = (size_t)0
    while i < q.size:
        nq.data[i] = q.data[q.front + i]
        nq.idx[i] = q.idx[q.front + i]
        i += (size_t)1
    return nq

# Push value arriving at `index`. Removes from the back every retained value
# that is <= it (ties keep only the newest), then appends.
public def monotonic_push(q MonotonicQueue, value int, index int) -> MonotonicQueue:
    if q.front + q.size >= q.capacity:
        q = _mq_grow(q)
    int run = 1
    while run == 1:
        if q.size == (size_t)0:
            run = 0
        else:
            if q.data[q.front + q.size - (size_t)1] <= value:
                q.size -= (size_t)1
            else:
                run = 0
    q.data[q.front + q.size] = value
    q.idx[q.front + q.size] = index
    q.size += (size_t)1
    return q

# Drop the element that arrived at `index` (it left the window) if it is the
# front; otherwise it is already gone (a newer value dominated it).
public def monotonic_pop(q MonotonicQueue, index int) -> MonotonicQueue:
    if q.size == (size_t)0:
        return q
    if q.idx[q.front] == index:
        q.front += (size_t)1
        q.size -= (size_t)1
    return q

# Largest value in the current window (caller should check is_empty first).
public def monotonic_max(q MonotonicQueue) -> int:
    return q.data[q.front]

public def monotonic_size(q MonotonicQueue) -> size_t:
    return q.size

public def monotonic_is_empty(q MonotonicQueue) -> int:
    int e = 0
    if q.size == (size_t)0:
        e = 1
    return e

# 1 if values are strictly decreasing front-to-back and indices increasing.
public def monotonic_validate(q MonotonicQueue) -> int:
    size_t i = (size_t)1
    while i < q.size:
        if q.data[q.front + i] >= q.data[q.front + i - (size_t)1]:
            return 0
        if q.idx[q.front + i] <= q.idx[q.front + i - (size_t)1]:
            return 0
        i += (size_t)1
    return 1