import stdlib
import "vector.cpy"

def main():
    Vector vec = create_vector((size_t)8)
    int i = 0
    for i in range(100000):
        vec = vector_push(vec, (void*)(i + 1))

    if vector_size(vec) != (size_t)100000:
        print("push size FAIL", (int)vector_size(vec))
        return
    if (int)vector_get(vec, (size_t)99999) != 100000:
        print("push tail FAIL")
        return
    if (int)vector_get(vec, (size_t)0) != 1:
        print("push head FAIL")
        return

    vec = vector_insert(vec, (size_t)0, (void*)999)
    if (int)vector_get(vec, (size_t)0) != 999:
        print("insert head FAIL")
        return
    vec = vector_insert(vec, (size_t)50000, (void*)777)
    if (int)vector_get(vec, (size_t)50000) != 777:
        print("insert mid FAIL")
        return
    if (int)vector_get(vec, (size_t)50001) != 50000:
        print("insert shift FAIL")
        return

    vec = vector_erase(vec, (size_t)0)
    if (int)vector_get(vec, (size_t)0) != 1:
        print("erase head FAIL")
        return
    vec = vector_erase(vec, (size_t)50000)
    if (int)vector_get(vec, (size_t)50000) != 50001:
        print("erase shift FAIL")
        return

    i = 0
    for i in range(1000):
        vec = vector_pop(vec)
    if vector_size(vec) != (size_t)99000:
        print("pop size FAIL", (int)vector_size(vec))
        return

    if vector_capacity(vec) < vector_size(vec):
        print("capacity invariant FAIL")
        return
    print("vector: PASS")

