import stdlib
import "array.cpy"
import "stack.cpy"
import "queue.cpy"

def main():
    # stack
    Stack st = create_stack((size_t)2)
    int i = 0
    for i in range(100000):
        st = stack_push(st, (void*)(i + 1))
    if (int)stack_size(st) != 100000:
        print("stack size FAIL", (int)stack_size(st))
        return
    if (int)stack_peek(st) != 100000:
        print("stack peek FAIL", (int)stack_peek(st))
        return
    for i in range(100000):
        st = stack_pop(st)
    if not stack_is_empty(st):
        print("stack empty FAIL")
        return

    # queue, fighting wraps on a tiny starting capacity
    Queue q = create_queue((size_t)2)
    int n = 0
    for n in range(100000):
        q = queue_push(q, (void*)(n + 1))
    if (int)queue_size(q) != 100000:
        print("queue size FAIL", (int)queue_size(q))
        return
    for n in range(90000):
        q = queue_pop(q)
    # pop from a wrapped, partially-consumed ring then push more to force
    # growth with compaction at many capacity boundaries
    if (int)queue_front(q) != 90001:
        print("queue front FAIL", (int)queue_front(q))
        return
    for n in range(50000):
        q = queue_push(q, (void*)(n + 1))
        q = queue_pop(q)
    if (int)queue_front(q) != 40001:
        print("queue front2 FAIL", (int)queue_front(q))
        return
    while not queue_is_empty(q):
        q = queue_pop(q)
    if (int)queue_size(q) != 0:
        print("queue drain FAIL")
        return

    # array basics
    Array arr = create_array((size_t)8)
    for i in range(8):
        arr = array_push(arr, (void*)(i * 10))
    if (int)array_get(arr, (size_t)3) != 30:
        print("array get FAIL")
        return
    if array_length(arr) != (size_t)8:
        print("array len FAIL")
        return
    print("stack+queue+array: PASS")

