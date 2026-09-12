import stdlib
import "hash_map.cpy"
import "hash_set.cpy"

def main():
    HashMap m = create_hashmap((size_t)8)
    int i = 0
    for i in range(60000):
        m = hashmap_put(m, (void*)(i + 1), (void*)((i + 1) * 10))
    if (int)hashmap_size(m) != 60000:
        print("map size FAIL", (int)hashmap_size(m))
        return
    for i in range(60000):
        if (int)hashmap_get(m, (void*)(i + 1)) != (i + 1) * 10:
            print("map get FAIL", i + 1)
            return
    for i in range(30000):
        m = hashmap_erase(m, (void*)((i * 2) + 2))
    if (int)hashmap_size(m) != 30000:
        print("map erase FAIL", (int)hashmap_size(m))
        return
    for i in range(30000):
        if hashmap_contains(m, (void*)((i * 2) + 2)) != 0:
            print("map removed still there", (i * 2) + 2)
            return
        if hashmap_contains(m, (void*)((i * 2) + 1)) != 1:
            print("map survivor missing", (i * 2) + 1)
            return
    for i in range(40000):
        m = hashmap_put(m, (void*)(1000000 + i), (void*)(i * 7))
    if (int)hashmap_size(m) != 30000 + 40000:
        print("map grow FAIL", (int)hashmap_size(m))
        return
    for i in range(40000):
        if (int)hashmap_get(m, (void*)(1000000 + i)) != i * 7:
            print("map grow get FAIL", i)
            return
    for i in range(30000):
        if (int)hashmap_get(m, (void*)((i * 2) + 1)) != ((i * 2) + 1) * 10:
            print("map survivor get FAIL", (i * 2) + 1)
            return

    HashSet s = create_hashset((size_t)8)
    for i in range(50000):
        s = hashset_add(s, (void*)(i + 1))
    for i in range(25000):
        s = hashset_remove(s, (void*)((i * 2) + 2))
    for i in range(25000):
        if hashset_contains(s, (void*)((i * 2) + 2)) != 0:
            print("set removed still there", (i * 2) + 2)
            return
        if hashset_contains(s, (void*)((i * 2) + 1)) != 1:
            print("set survivor missing", (i * 2) + 1)
            return
    for i in range(30000):
        s = hashset_add(s, (void*)(50000 + i))
    if (int)hashset_size(s) != 25000 + 30000:
        print("set size FAIL", (int)hashset_size(s))
        return
    if hashset_contains(s, (void*)(60000)) != 1:
        print("set reinsert FAIL")
        return
    print("hash_map+hash_set: PASS")

