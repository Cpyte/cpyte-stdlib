import stdlib
import "bitvector.cpy"

public def mix(v size_t) -> size_t:
    size_t t = v * (size_t)2654435761 + (size_t)1013904223
    t = t ^ (t >> (int)16)
    return t & (size_t)0x7fffffff

public def main():
    BitVector b = create_bitvector()
    int[] model = new int[3000]
    int n = 0
    for n in range(300):
        if n % 2 == 0:
            b = bitvector_push(b, 1)
            model[n] = 1
        else:
            b = bitvector_push(b, 0)
            model[n] = 0
    if (int)bitvector_length(b) != 300:
        print("len FAIL", (int)bitvector_length(b))
        return
    if (int)bitvector_count(b) != 150:
        print("count FAIL", (int)bitvector_count(b))
        return
    int ops = 0
    while ops < 30000:
        size_t op = mix((size_t)ops) % (size_t)4
        int len = (int)bitvector_length(b)
        if (int)op <= 1:
            if len == 0:
                ops = ops + 1
                continue
            size_t pos = mix((size_t)ops * (size_t)5 + (size_t)2) % (size_t)len
            int val = (int)(mix((size_t)ops * (size_t)7 + (size_t)3) & (size_t)1)
            if (int)op == 0:
                b = bitvector_insert(b, pos, val)
                int j = len
                while j > (int)pos:
                    model[j] = model[j - 1]
                    j = j - 1
                model[(int)pos] = val
                if (int)bitvector_length(b) != (size_t)(len + 1):
                    print("len2 FAIL", (int)bitvector_length(b), ops)
                    return
            else:
                b = bitvector_set(b, pos, val)
                model[(int)pos] = val
        elif (int)op == 2:
            if len == 0:
                ops = ops + 1
                continue
            size_t pos = mix((size_t)ops * (size_t)11 + (size_t)5) % (size_t)len
            b = bitvector_delete(b, pos)
            int j = (int)pos
            while j < len - 1:
                model[j] = model[j + 1]
                j = j + 1
            if (int)bitvector_length(b) != (size_t)(len - 1):
                print("len3 FAIL", (int)bitvector_length(b), ops)
                return
        else:
            if len == 0:
                ops = ops + 1
                continue
            size_t pos = mix((size_t)ops * (size_t)13 + (size_t)7) % (size_t)len
            b = bitvector_flip(b, pos)
            if model[(int)pos] == 1:
                model[(int)pos] = 0
            else:
                model[(int)pos] = 1
        if (int)bitvector_length(b) > (size_t)2900:
            ops = ops + 1
            continue
        size_t L = bitvector_length(b)
        int k = 0
        int cc = 0
        while k < (int)L:
            if (int)bitvector_get(b, (size_t)k) != model[k]:
                print("MISMATCH at", k, "op", ops)
                return
            cc = cc + model[k]
            k = k + 1
        if (int)bitvector_count(b) != cc:
            print("count2 FAIL", (int)bitvector_count(b), cc, "op", ops)
            return
        ops = ops + 1
    print("bitvector: PASS")
