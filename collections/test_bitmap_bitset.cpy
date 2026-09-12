import stdlib
import "bitmap.cpy"
import "bitset.cpy"

public def mix(v size_t) -> size_t:
    size_t t = v * (size_t)2654435761 + (size_t)1013904223
    t = t ^ (t >> (int)16)
    return t & (size_t)0x7fffffff

public def main():
    int bits = 400
    Bitmap m = create_bitmap((size_t)bits)
    int[] model = new int[512]
    int i = 0
    for i in range(120):
        m = bitmap_set(m, (size_t)i)
        model[i] = 1
    if (int)bitmap_count(m) != 120:
        print("c0 FAIL", (int)bitmap_count(m))
        return
    if (int)bitmap_count_range(m, (size_t)0, (size_t)bits) != 120:
        print("cr0 FAIL", (int)bitmap_count_range(m, (size_t)0, (size_t)bits))
        return
    BitSet s = create_bitset((size_t)bits)
    int[] smodel = new int[512]
    int j = 0
    for j in range(120):
        s = bitset_set(s, (size_t)j)
        smodel[j] = 1
    if (int)bitset_count(s) != 120:
        print("bs0 FAIL", (int)bitset_count(s))
        return
    size_t ns = bitset_next_set(s, (size_t)5)
    if (int)ns != 5:
        print("next0 FAIL", (int)ns)
        return
    if (int)bitset_next_set(s, (size_t)120) != (int)0x7FFFFFFF:
        print("next-sentinel FAIL")
        return
    int onesA = 120
    int onesB = 120
    int ops = 0
    while ops < 20000:
        size_t kind = mix((size_t)ops) % (size_t)16
        size_t i2 = mix((size_t)ops * (size_t)3 + (size_t)1) % (size_t)bits
        if (int)kind < 8:
            int wi = (int)mix((size_t)ops * (size_t)5 + (size_t)7) % (size_t)3
            if wi == 0:
                m = bitmap_flip(m, i2)
                if model[(int)i2] == 1:
                    model[(int)i2] = 0
                    onesA = onesA - 1
                else:
                    model[(int)i2] = 1
                    onesA = onesA + 1
            elif wi == 1:
                m = bitmap_set(m, i2)
                if model[(int)i2] == 0:
                    model[(int)i2] = 1
                    onesA = onesA + 1
            else:
                m = bitmap_clear(m, i2)
                if model[(int)i2] == 1:
                    model[(int)i2] = 0
                    onesA = onesA - 1
        elif (int)kind < 14:
            size_t lo2 = mix((size_t)ops * (size_t)7 + (size_t)3) % (size_t)bits
            size_t span = (mix((size_t)ops * (size_t)11 + (size_t)5) % (size_t)200) + (size_t)1
            size_t hi2 = lo2 + span
            if hi2 > (size_t)bits:
                hi2 = (size_t)bits
            int mode = (int)kind - 8
            int u = (int)lo2
            if mode == 0:
                m = bitmap_set_range(m, lo2, hi2)
                while u < (int)hi2:
                    if model[u] == 0:
                        onesA = onesA + 1
                    model[u] = 1
                    u = u + 1
            elif mode == 1:
                m = bitmap_clear_range(m, lo2, hi2)
                while u < (int)hi2:
                    if model[u] == 1:
                        onesA = onesA - 1
                    model[u] = 0
                    u = u + 1
            else:
                m = bitmap_flip_range(m, lo2, hi2)
                while u < (int)hi2:
                    if model[u] == 1:
                        model[u] = 0
                        onesA = onesA - 1
                    else:
                        model[u] = 1
                        onesA = onesA + 1
                    u = u + 1
        else:
            int bi = (int)mix((size_t)ops * (size_t)13 + (size_t)7) % (size_t)3
            if bi == 0:
                s = bitset_flip(s, i2)
                if smodel[(int)i2] == 1:
                    smodel[(int)i2] = 0
                    onesB = onesB - 1
                else:
                    smodel[(int)i2] = 1
                    onesB = onesB + 1
            elif bi == 1:
                s = bitset_set(s, i2)
                if smodel[(int)i2] == 0:
                    smodel[(int)i2] = 1
                    onesB = onesB + 1
            else:
                s = bitset_clear(s, i2)
                if smodel[(int)i2] == 1:
                    smodel[(int)i2] = 0
                    onesB = onesB - 1
        if ops % 997 == 0:
            m = bitmap_recount(m)
            if (int)bitmap_count(m) != onesA:
                print("A count FAIL", (int)bitmap_count(m), onesA, "op", ops)
                return
            int k = 0
            while k < bits:
                if (int)bitmap_test(m, (size_t)k) != model[k]:
                    print("BM MISMATCH at", k, "op", ops)
                    return
                k = k + 1
            if (int)bitmap_count_range(m, (size_t)0, (size_t)bits) != onesA:
                print("A cr FAIL", (int)bitmap_count_range(m, (size_t)0, (size_t)bits), onesA, "op", ops)
                return
            s = bitset_recount(s)
            if (int)bitset_count(s) != onesB:
                print("B count FAIL", (int)bitset_count(s), onesB, "op", ops)
                return
            k = 0
            while k < bits:
                if (int)bitset_test(s, (size_t)k) != smodel[k]:
                    print("BS MISMATCH at", k, "op", ops)
                    return
                k = k + 1
            if (int)bitset_count_range(s, (size_t)0, (size_t)bits) != onesB:
                print("B cr FAIL", (int)bitset_count_range(s, (size_t)0, (size_t)bits), onesB, "op", ops)
                return
            size_t from = (size_t)0
            k = 0
            while k < bits:
                size_t nxt = bitset_next_set(s, from)
                while k < bits and smodel[k] == 0:
                    k = k + 1
                if k >= bits:
                    if (int)nxt != (int)0x7FFFFFFF:
                        print("next FAIL end", (int)nxt, "op", ops)
                        return
                    break
                if (int)nxt != k:
                    print("next FAIL", (int)nxt, k, "op", ops)
                    return
                from = (size_t)k + (size_t)1
                k = k + 1
        ops = ops + 1
    print("bitmap+bitset: PASS")