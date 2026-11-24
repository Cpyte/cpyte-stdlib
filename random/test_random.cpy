# Known-answer / smoke suite for std.random.
import "csprng.cpy"
import "secrets.cpy"
import "drbg.cpy"
import "prng.cpy"

def hex_eq(got char[], want str) -> int:
    int64 n = len(want)
    int64 i = 0
    while i < n:
        if got[i] != want[i]:
            return 0
        i += 1
    return 1

def check_hex(name str, got char[], want str) -> int:
    if hex_eq(got, want):
        print("  ok    " + name)
        return 0
    print("  FAIL  " + name)
    print("        want " + want)
    print("        got  " + str(got))
    return 1

def check_str(name str, got str, want str) -> int:
    int64 n = len(want)
    int64 i = 0
    while i < n:
        if got[i] != want[i]:
            print("  FAIL  " + name)
            print("        want " + want)
            print("        got  " + got)
            return 1
        i += 1
    if got[n] != (char)0:
        print("  FAIL  " + name)
        return 1
    print("  ok    " + name)
    return 0

def check_u64(name str, got uint64, want uint64) -> int:
    if got == want:
        print("  ok    " + name)
        return 0
    print("  FAIL  " + name)
    print("        want " + str(want))
    print("        got  " + str(got))
    return 1

def check_int(name str, got int, want int) -> int:
    if got == want:
        print("  ok    " + name)
        return 0
    print("  FAIL  " + name)
    return 1

public def main() -> int:
    int bad = 0

    # HMAC-SHA-256 DRBG (SP 800-90A 10.1.2), cross-checked against CPython
    # hashlib/hmac.  Entropy is bytes 0..47, personalization "test-pers".
    char[48] ent
    int i = 0
    while i < 48:
        ent[i] = (char)i
        i += 1
    void* st = drbg_from_entropy((void*)ent, (size_t)48, "test-pers")
    if st == 0:
        bad += 1
    if st != 0:
        char[] a = drbg_bytes(st, 64)
        bad += check_hex(
            "drbg first 64",
            hex((void*)a, 64),
            "a2726b1e2b99633fdf5270025bac053d749a09b5495b6439e1311ba0d2601aec47365316960b2443e8865fabdc64e6ebf67c624260b88c0d8ff928878685316f",
        )
        char[] b = drbg_bytes(st, 32)
        bad += check_hex(
            "drbg next 32",
            hex((void*)b, 32),
            "d80b7d29bf49799cd0cf18bd7ed37c8136386e0f84c46047af37bb0da0f01da6",
        )
        bad += check_u64("drbg counter", drbg_counter(st), (uint64)3)
        drbg_free(st)

    # SplitMix64 with seed 1, verified against the reference recurrence.
    void* p = prng_new(alg_splitmix64(), (uint64)1)
    bad += check_u64("splitmix64 #1", prng_next_u64(p), (uint64)10451216379200822465)
    bad += check_u64("splitmix64 #2", prng_next_u64(p), (uint64)13757245211066428519)
    bad += check_u64("splitmix64 #3", prng_next_u64(p), (uint64)17911839290282890590)
    bad += check_int("prng alg id", prng_alg(p), alg_splitmix64())
    bad += check_str("prng name", prng_name(alg_xoshiro256ss()), "xoshiro256**")
    prng_destroy(p)

    # Philox family: exact counter/key KATs plus seeded determinism.
    void* ph4 = prng_new_philox4x32(0, 0, 0, 0, 0, 0, 10)
    bad += check_int("philox4 alg id", prng_alg(ph4), alg_philox4x32())
    bad += check_int("philox4 rounds", prng_rounds(ph4), 10)
    bad += check_u64("philox4 u32 #1", (uint64)prng_next_u32(ph4), (uint64)1713891541)
    bad += check_u64("philox4 u32 #2", (uint64)prng_next_u32(ph4), (uint64)3781805453)
    bad += check_u64("philox4 u32 #3", (uint64)prng_next_u32(ph4), (uint64)3159862348)
    bad += check_u64("philox4 u32 #4", (uint64)prng_next_u32(ph4), (uint64)2600524760)
    prng_destroy(ph4)

    void* ph4u = prng_new_philox4x32(0, 0, 0, 0, 0, 0, 10)
    bad += check_u64("philox4 u64 #1", prng_next_u64(ph4u), (uint64)16242730742183356629)
    bad += check_u64("philox4 u64 #2", prng_next_u64(ph4u), (uint64)11169168799798111308)
    prng_destroy(ph4u)

    void* ph2 = prng_new_philox2x32(0, 0, 10)
    bad += check_int("philox2 alg id", prng_alg(ph2), alg_philox2x32())
    bad += check_str("philox2 name", prng_name(alg_philox2x32()), "philox2x32")
    bad += check_u64("philox2 u64 #1", prng_next_u64(ph2), (uint64)16229706333600668493)
    prng_destroy(ph2)

    void* ph4r = prng_new_philox4x32(0, 0, 0, 0, 0, 0, 4)
    bad += check_int("philox4 rounds arg", prng_rounds(ph4r), 4)
    bad += check_u64("philox4 r4 u32", (uint64)prng_next_u32(ph4r), (uint64)509180460)
    prng_destroy(ph4r)

    void* pha = prng_new_philox(alg_philox4x32(), (uint64)123, 6)
    void* phb = prng_new_philox(alg_philox4x32(), (uint64)123, 6)
    bad += check_int("philox seeded rounds", prng_rounds(pha), 6)
    if prng_next_u64(pha) != prng_next_u64(phb):
        bad += 1
    prng_destroy(pha)
    prng_destroy(phb)

    # OS CSPRNG shape / formatting checks (values are nondeterministic).
    char[] raw = token_bytes(16)
    bad += check_int("token_bytes length", (int)len(raw), 16)
    char[] hx = token_hex(16)
    bad += check_int("token_hex length", (int)len(hx), 33)
    char[] u = token_urlsafe(16)
    bad += check_int("token_urlsafe length", (int)len(u), 23)
    char[] uid = token_uuid4()
    bad += check_int("uuid4 length", (int)len(uid), 37)
    bad += check_int("uuid4 version", uid[14], (char)52)
    char var = uid[19]
    if var != (char)56 and var != (char)57 and var != (char)97 and var != (char)98:
        bad += 1
    bad += check_int("ct equal", compare_digest((void*)raw, (void*)raw, 16), 1)
    int64 v = randint(7, 7)
    bad += check_int("randint fixed", (int)v, 7)
    uint64 small = randbelow((uint64)10)
    if small >= (uint64)10:
        bad += 1

    if bad == 0:
        print("random: all tests passed")
    else:
        print("random: FAILURES")
    return bad
