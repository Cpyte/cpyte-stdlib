import stdlib
import "roaring_bitmap.cpy"

public def mix(v size_t) -> size_t:
    size_t t = v * (size_t)2654435761 + (size_t)1013904223
    t = t ^ (t >> (int)16)
    return t & (size_t)0x7fffffff

public def main():
    int U = 200000
    int* model = (int*)malloc((size_t)200000 * (size_t)sizeof(int))
    Roaring r = create_roaring()
    int i = 0
    while i < U:
        model[i] = 0
        i = i + 1
    for i in range(5001):
        r = roaring_add(r, (size_t)i)
        model[i] = 1
    if (int)roaring_cardinality(r) != 5001:
        print("densify FAIL", (int)roaring_cardinality(r))
        return
    if roaring_contains(r, (size_t)0) != 1 or roaring_contains(r, (size_t)4096) != 1:
        print("contains edge FAIL")
        return
    if roaring_contains(r, (size_t)5001) != 0 or roaring_contains(r, (size_t)100000) != 0:
        print("contains miss FAIL")
        return
    int ones = 5001
    int ops = 0
    while ops < 40000:
        size_t op = mix((size_t)ops) % (size_t)4
        size_t key = mix((size_t)ops * (size_t)5 + (size_t)7) % (size_t)U
        if (int)op < 3:
            r = roaring_add(r, key)
            if model[(int)key] == 0:
                model[(int)key] = 1
                ones = ones + 1
        else:
            r = roaring_remove(r, key)
            if model[(int)key] == 1:
                model[(int)key] = 0
                ones = ones - 1
        if ops % 977 == 0:
            r = roaring_add(r, (size_t)31000)
            if model[31000] == 0:
                model[31000] = 1
                ones = ones + 1
            int BB = 0
            int kk = 0
            while kk < U:
                BB = BB + model[kk]
                kk = kk + 1
            if (int)roaring_cardinality(r) != BB:
                print("card FAIL", (int)roaring_cardinality(r), BB, "op", ops)
                return
            if ones != BB:
                print("ones FAIL", ones, BB, "op", ops)
                return
            int k2 = 0
            while k2 < U:
                int exp = model[k2]
                if exp == 1:
                    if roaring_contains(r, (size_t)k2) != 1:
                        print("contains FAIL at", k2, "op", ops)
                        return
                else:
                    if roaring_contains(r, (size_t)k2) != 0:
                        print("false-pos FAIL at", k2, "op", ops)
                        return
                k2 = k2 + 137
        ops = ops + 1
    size_t nb = roaring_buckets(r)
    size_t h = (size_t)0
    int high_ok = 1
    while h < nb:
        size_t c = roaring_high_at(r, h)
        if h > (size_t)0:
            size_t pc = roaring_high_at(r, h - (size_t)1)
            if c <= pc:
                high_ok = 0
        if c >= (size_t)65536:
            high_ok = 0
        h = h + (size_t)1
    if high_ok != 1:
        print("buckets FAIL")
        return
    if (int)roaring_cardinality(r) != ones:
        print("final card FAIL", (int)roaring_cardinality(r), ones)
        return
    if roaring_is_empty(r) != 0:
        print("empty FAIL")
        return
    free(model)
    print("roaring: PASS")