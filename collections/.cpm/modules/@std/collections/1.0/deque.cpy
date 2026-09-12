import stdlib

struct Deque:
    void** data
    size_t capacity
    size_t length
    size_t front

ccode:
    #include <stddef.h>
    #include <stdlib.h>
    extern void cpyte_array_register(void *arr, long long n);
    typedef struct { int kind; long long data; } dq_dynval;
    void* deque_to_list(void *deque) {
        typedef struct { void *data; size_t capacity; size_t length; size_t front; } dq_t;
        dq_t *dq = (dq_t *)deque;
        size_t n = dq->length;
        if (n == 0) {
            dq_dynval *e = (dq_dynval*)malloc(sizeof(dq_dynval));
            cpyte_array_register(e, 0);
            return (void*)e;
        }
        void **src = (void **)dq->data;
        dq_dynval *arr = (dq_dynval*)malloc(sizeof(dq_dynval) * n);
        for (size_t i = 0; i < n; i++) {
            size_t idx = (dq->front + i) % dq->capacity;
            arr[i] = *(dq_dynval *)src[idx];
        }
        cpyte_array_register(arr, (long long)n);
        return (void*)arr;
    }

public def create_deque(cap size_t) -> Deque:
    assert cap >= (size_t)1, "Value Error: You cannot create a deque of capacity below 1"
    Deque list
    list.capacity = cap
    list.data = malloc(cap * (size_t)sizeof(void*))
    list.length = (size_t)0
    list.front = (size_t)0
    return list

public def get(list Deque, i size_t) -> void*:
    assert i < list.length, "Index out of bounds"
    size_t index = (list.front + i) % list.capacity
    return list.data[index]

#VERY IMPORTANT!
public def grow_list(list Deque, new_size size_t) -> Deque:
    assert new_size >= list.length, "Value Error: You can't shrink an deque list"
    Deque newlist = create_deque(new_size)
    for i in range((int)list.length):
        void *ind = get(list, (size_t)i)
        newlist.data[i] = ind
    newlist.front = (size_t)0
    newlist.length = list.length
    return newlist

#Push back function lol
public def push_back(list Deque, value void*) -> Deque:
    if list.length >= list.capacity:
        list = grow_list(list, list.capacity * (size_t)2)
    size_t index = (list.front + list.length) % list.capacity
    list.data[index] = value
    list.length += (size_t)1
    return list

public def push_front(list Deque, value void*) -> Deque:
    if list.length >= list.capacity:
        list = grow_list(list, list.capacity * (size_t)2)
    list.front = (list.front + list.capacity - (size_t)1) % list.capacity
    list.data[list.front] = value
    list.length += (size_t)1
    return list

public def to_list(d Deque) -> dynamic:
    return d.data
