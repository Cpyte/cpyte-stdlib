import "hash.cpy"
import "kdf.cpy"
import "random.cpy"

# Known-answer suite for the cryptography package. Every vector below comes from
# the algorithm's own reference source (FIPS 180-4 / RFC 4231 / RFC 5869 /
# RFC 7693) and was cross-checked against CPython's hashlib.

def hex_eq(got char[], want str) -> int:
    int64 n = len(want)
    int64 i = 0
    while i < n:
        if got[i] != want[i]:
            return 0
        i += 1
    return 1

def check(name str, got char[], want str) -> int:
    if hex_eq(got, want):
        print("  ok    " + name)
        return 0
    print("  FAIL  " + name)
    print("        want " + want)
    print("        got  " + str(got))
    return 1

def check_int(name str, got int, want int) -> int:
    if got == want:
        print("  ok    " + name)
        return 0
    print("  FAIL  " + name)
    return 1

def buffers_differ(a char*, b char*, n int64) -> int:
    int64 i = 0
    while i < n:
        if a[i] != b[i]:
            return 1
        i += 1
    return 0

def abc() -> char[]:
    char[] out = new char[3]
    out[0] = (char)97
    out[1] = (char)98
    out[2] = (char)99
    return out

def key3() -> char[]:
    char[] out = new char[3]
    out[0] = (char)107
    out[1] = (char)101
    out[2] = (char)121
    return out

def seq(n int64, first int) -> char[]:
    char[] out = new char[n]
    int64 i = 0
    while i < n:
        out[i] = (char)(first + i)
        i += 1
    return out

def fill(n int64, byte int) -> char[]:
    char[] out = new char[n]
    int64 i = 0
    while i < n:
        out[i] = (char)byte
        i += 1
    return out

def test_hash(fails int) -> int:
    char[] m = abc()
    char[] k = key3()

    fails += check("sha256", digest_hex(sha256(m)),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    fails += check("sha384", digest_hex(sha384(m)),
        "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7")
    fails += check("sha512", digest_hex(sha512(m)),
        "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
    fails += check("sha3_256", digest_hex(sha3_256(m)),
        "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
    fails += check("sha3_384", digest_hex(sha3_384(m)),
        "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25")
    fails += check("sha3_512", digest_hex(sha3_512(m)),
        "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0")
    fails += check("blake2b", digest_hex(blake2b(m)),
        "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
    fails += check("blake2s", digest_hex(blake2s(m)),
        "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982")
    fails += check("blake2b_keyed", digest_hex(blake2b_keyed(m, k)),
        "5c6a9a4ae911c02fb7e71a991eb9aea371ae993d4842d206e6020d46f5e41358c6d5c277c110ef86c959ed63e6ecaaaceaaff38019a43264ae06acf73b9550b1")
    fails += check("blake2s_keyed", digest_hex(blake2s_keyed(m, k)),
        "3f9723437b033bf0c1f4df43cafd0776068cb0a95912de13f3b2952a3aba764d")
    fails += check("hmac_sha256", digest_hex(hmac_sha256(k, m)),
        "9c196e32dc0175f86f4b1cb89289d6619de6bee699e4c378e68309ed97a1a6ab")
    fails += check("hmac_sha512", digest_hex(hmac_sha512(k, m)),
        "3926a207c8c42b0c41792cbd3e1a1aaaf5f7a25704f62dfc939c4987dd7ce060009c5bb1c2447355b3216f10b537e9afa7b64a4e5391b0d631172d07939e087a")
    fails += check("sha256_string", digest_hex(sha256_string("abc")),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    fails += check_int("hash_equal", hash_equal((void*)sha256(m), (void*)sha256(abc()), 32), 1)
    return fails

def test_kdf(fails int) -> int:
    # RFC 5869 appendix A, case 1
    char[] ikm1 = fill(22, 11)
    char[] salt1 = seq(13, 0)
    char[] info1 = seq(10, 240)
    fails += check("hkdf case1 PRK", digest_hex(hkdf_extract((void*)salt1, 13, (void*)ikm1, 22)),
        "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5")
    fails += check("hkdf case1 OKM", digest_hex(hkdf((void*)salt1, 13, (void*)ikm1, 22, (void*)info1, 10, 42)),
        "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")

    # case 2: longer input/output, exercises three expand blocks
    char[] ikm2 = seq(52, 0)
    char[] salt2 = seq(20, 11)
    char[] info2 = seq(26, 160)
    fails += check("hkdf case2 PRK", digest_hex(hkdf_extract((void*)salt2, 20, (void*)ikm2, 52)),
        "e74b4e0a4d29a33ec69dd9452eade42a7b25cec1c9f484963d1439df516fa84f")
    fails += check("hkdf case2 OKM", digest_hex(hkdf((void*)salt2, 20, (void*)ikm2, 52, (void*)info2, 26, 82)),
        "6099362fa65feddea0b41907d0529fa37a3c5c84656343607de81c2229e680fbcef7fba93ffb3c5be62f5b196666794f36e0d4bc1dc1342773765c351e9c36721bb9e99be17a2426cf1c4e03801bfb7b8800")

    # case 3: empty salt and empty info
    fails += check("hkdf case3 PRK", digest_hex(hkdf_extract((void*)ikm1, 0, (void*)ikm1, 22)),
        "19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04")
    fails += check("hkdf case3 OKM", digest_hex(hkdf((void*)ikm1, 0, (void*)ikm1, 22, (void*)ikm1, 0, 42)),
        "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8")

    # hkdf() must agree with extract-then-expand done by hand
    char[] prk = hkdf_extract((void*)salt1, 13, (void*)ikm1, 22)
    char[] out = new char[42]
    hkdf_expand((void*)prk, 32, (void*)info1, 10, (void*)out, 42)
    fails += check("hkdf_expand matches hkdf", digest_hex(out),
        "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")
    fails += check_int("hkdf_expand rejects oversized L", hkdf_expand((void*)prk, 32, (void*)info1, 10, (void*)out, 8161), -1)
    return fails

def test_random(fails int) -> int:
    char[] a = fill(32, 0)
    char[] b = fill(32, 0)
    fails += check_int("random_bytes rc", random_bytes((void*)a, 32), 0)
    fails += check_int("random_bytes rc second", random_bytes((void*)b, 32), 0)
    fails += check_int("random_bytes distinct", buffers_differ((char*)a, (char*)b, 32), 1)

    char[] nz = fill(32, 0)
    int64 i = 0
    int nonzero = 0
    while i < 32:
        if nz[i] != (char)0:
            nonzero = 1
        i += 1
    random_bytes((void*)nz, 32)
    i = 0
    while i < 32:
        if nz[i] != (char)0:
            nonzero = 1
        i += 1
    fails += check_int("random_bytes wrote bytes", nonzero, 1)

    int int8_ok = 1
    int64 int32_ok = 1
    i = 0
    while i < 16:
        int v8 = random_u8()
        if v8 < 0:
            int8_ok = 0
        if v8 > 255:
            int8_ok = 0
        int64 v32 = random_u32()
        if v32 < 0:
            int32_ok = 0
        if v32 > 4294967295:
            int32_ok = 0
        i += 1
    fails += check_int("random_u8 in 0..255", int8_ok, 1)
    fails += check_int("random_u32 in 0..2^32-1", (int)int32_ok, 1)
    fails += check_int("random_bits rc", random_bits((void*)a, 32), 0)

    char[] lo = fill(8, 0)
    char[] hi = fill(8, 0)
    fails += check_int("random_u128 rc", random_u128((void*)lo, (void*)hi), 0)
    return fails

def main() -> int:
    int fails = 0
    print("hash:")
    fails += test_hash(fails)
    print("kdf:")
    fails += test_kdf(fails)
    print("random:")
    fails += test_random(fails)
    if fails == 0:
        print("all cryptography vectors pass")
    else:
        print("FAILURES: " + str(fails))
    return fails
