import stdlib
import "deque.cpy"
import "ring_buffer.cpy"

def main():
    Deque dq = create_deque((size_t)4)
    int i = 0
    for i in range(30000):
        if i % 2 == 0:
            dq = push_back(dq, (void*)(i + 1))
        else:
            dq = push_front(dq, (void*)(i + 1))
    if deque_length(dq) != (size_t)30000:
        print("dq len FAIL", (int)deque_length(dq))
        return
    # odd i -> push_front(i+1): last front push (i=29999) yields front value 30000
    if (int)deque_front(dq) != 30000:
        print("dq front FAIL", (int)deque_front(dq))
        return
    if (int)deque_back(dq) != 29999:
        print("dq back FAIL", (int)deque_back(dq))
        return
    # next front value after 30000 is 29998
    if (int)get(dq, (size_t)1) != 29998:
        print("dq get1 FAIL", (int)get(dq, (size_t)1))
        return
    for i in range(10000):
        dq = pop_front(dq)
        dq = pop_back(dq)
    if deque_length(dq) != (size_t)10000:
        print("dq pop FAIL", (int)deque_length(dq))
        return
    # after 10000 front-pops front = 30000 - 2*9999 = 10002
    if (int)deque_front(dq) != 10000:
        print("dq front2 FAIL", (int)deque_front(dq))
        return

    RingBuffer rb = create_ring((size_t)16)
    for i in range(100000):
        rb = ring_write(rb, (void*)(i + 1))
    if ring_length(rb) != (size_t)16:
        print("rb len FAIL", (int)ring_length(rb))
        return
    # last 16 written values are 99985..100000
    if (int)ring_peek(rb) != 99985:
        print("rb peek FAIL", (int)ring_peek(rb))
        return
    for i in range(8):
        rb = ring_read(rb)
    if (int)ring_peek(rb) != 99993:
        print("rb read FAIL", (int)ring_peek(rb))
        return
    rb = ring_write(rb, (void*)12345)
    if (int)ring_peek(rb) != 99993:
        print("rb write FAIL", (int)ring_peek(rb))
        return
    print("deque+ring: PASS")

