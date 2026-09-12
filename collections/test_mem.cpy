import stdlib
import "mem.cpy"

def main():
    int* a = (int*)malloc((size_t)8 * (size_t)sizeof(int))
    for i in range(8):
        a[i] = i + 1
    int* b = (int*)malloc((size_t)8 * (size_t)sizeof(int))
    buf_zero(b, (size_t)8 * (size_t)sizeof(int))
    buf_copy(b, a, (size_t)8 * (size_t)sizeof(int))
    if b[3] != 4:
        print("buf_copy FAIL")
        return
    buf_move(a, b, (size_t)8 * (size_t)sizeof(int))
    if a[7] != 8:
        print("buf_move FAIL")
        return
    void* ar = arena_create((size_t)1024)
    int* p1 = (int*)arena_alloc(ar, (size_t)1024, (size_t)8)
    if p1 == 0:
        print("arena_alloc FAIL")
        return
    p1 = (int*)arena_alloc(ar, (size_t)1024, (size_t)8)
    p1[0] = 77
    if p1[0] != 77:
        print("arena realloc-chunk FAIL")
        return
    arena_reset(ar)
    int* p2 = (int*)arena_alloc(ar, (size_t)1024, (size_t)8)
    p2[0] = 88
    if p2[0] != 88:
        print("arena reset FAIL")
        return
    arena_destroy(ar)
    print("mem: PASS")

