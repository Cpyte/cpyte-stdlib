# Self-check for @std/encoding, using the RFC 4648 base64 vectors.

import "encoding.cpy"

ccode:
    #include <stdint.h>
    void cpy_t_put(void* dst, int64_t i, int c) {
        ((unsigned char*)dst)[i] = (unsigned char)c;
    }

# Exact byte vectors: a `\xNN` literal in cpy source is a Unicode codepoint
# re-encoded as UTF-8, so it cannot express bytes >= 0x80.
def bytes_of(a int, b int, c int) -> char[]:
    char[] out = new char[3]
    cpy_t_put((void*)out, (int64)0, a)
    cpy_t_put((void*)out, (int64)1, b)
    cpy_t_put((void*)out, (int64)2, c)
    return out

def bytes_sum(data char[]) -> int:
    int acc = 0
    int i = 0
    while i < (int)len(data):
        acc = acc * 256 + (((int)data[i]) & 255)
        i = i + 1
    return acc

def check_s(name str, got str, want str) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_i(name str, got int, want int) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_b(name str, got bool, want bool) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def test_base64() -> int:
    int n = 0
    # RFC 4648 section 10
    n += check_s("b64 ''", base64_text(text_to_bytes("")), "")
    n += check_s("b64 f", base64_text(text_to_bytes("f")), "Zg==")
    n += check_s("b64 fo", base64_text(text_to_bytes("fo")), "Zm8=")
    n += check_s("b64 foo", base64_text(text_to_bytes("foo")), "Zm9v")
    n += check_s("b64 foob", base64_text(text_to_bytes("foob")), "Zm9vYg==")
    n += check_s("b64 fooba", base64_text(text_to_bytes("fooba")), "Zm9vYmE=")
    n += check_s("b64 foobar", base64_text(text_to_bytes("foobar")), "Zm9vYmFy")
    n += check_s("b64 nopad f", base64_nopad_text(text_to_bytes("f")), "Zg")
    n += check_s("b64 nopad fo", base64_nopad_text(text_to_bytes("fo")), "Zm8")
    n += check_s("b64 nopad foo", base64_nopad_text(text_to_bytes("foo")), "Zm9v")
    n += check_i("b64 encoded_length", (int)base64_encoded_length((int64)6), 8)
    n += check_i("b64 encoded_length 0", (int)base64_encoded_length((int64)0), 0)
    n += check_i("b64 bytes len", (int)len(base64_encode(text_to_bytes("foobar"))), 8)
    # decoding
    n += check_s("b64 decode", bytes_to_text(base64_decode(text_to_bytes("Zm9vYmFy"))), "foobar")
    n += check_s("b64 decode pad1", bytes_to_text(base64_decode(text_to_bytes("Zm9vYmE="))), "fooba")
    n += check_s("b64 decode nopad", bytes_to_text(base64_decode(text_to_bytes("Zm9vYmE"))), "fooba")
    # 62 and 63 are '/' and '+' in the standard alphabet, '-' and '_' url-safe,
    # so both spellings must decode to the same three bytes 00 FF 80.
    n += check_i("b64 decode std", bytes_sum(base64_decode(text_to_bytes("AP+A"))), 65408)
    n += check_i("b64 decode urlsafe", bytes_sum(base64_decode(text_to_bytes("AP-A"))), 65408)
    n += check_i("b64 decode urlsafe pair", bytes_sum(base64_decode(text_to_bytes("A-_="))),
                 bytes_sum(base64_decode(text_to_bytes("A+/="))))
    n += check_i("b64 round exact", bytes_sum(base64_decode(base64_encode(bytes_of(0, 255, 128)))), 65408)
    n += check_i("hex round exact", bytes_sum(hex_decode(hex_encode(bytes_of(9, 10, 13)))), 592397)
    n += check_b("b64 valid", base64_is_valid(text_to_bytes("Zm9vYmFy")), true)
    n += check_b("b64 invalid char", base64_is_valid(text_to_bytes("Zm9v!")), false)
    n += check_b("b64 data after pad", base64_is_valid(text_to_bytes("Zm=v")), false)
    n += check_i("b64 decode invalid len", (int)len(base64_decode(text_to_bytes("!!!!"))), 0)
    return n

def test_hex() -> int:
    int n = 0
    n += check_s("hex lower", hex_text(text_to_bytes("jkl")), "6a6b6c")
    n += check_s("hex upper", hex_text_upper(text_to_bytes("jkl")), "6A6B6C")
    n += check_s("hex empty", hex_text(text_to_bytes("")), "")
    n += check_s("hex exact", hex_text(bytes_of(255, 0, 127)), "ff007f")
    n += check_s("hex decode", bytes_to_text(hex_decode(text_to_bytes("6a6b6c"))), "jkl")
    n += check_s("hex decode upper", bytes_to_text(hex_decode(text_to_bytes("6A6B6C"))), "jkl")
    n += check_s("hex round", bytes_to_text(hex_decode(hex_encode(text_to_bytes("\x01\x7f\xff")))),
                 "\x01\x7f\xff")
    n += check_b("hex valid", hex_is_valid(text_to_bytes("deadBEEF")), true)
    n += check_b("hex odd invalid", hex_is_valid(text_to_bytes("414")), false)
    n += check_b("hex chars invalid", hex_is_valid(text_to_bytes("zz")), false)
    n += check_i("hex decode invalid", (int)len(hex_decode(text_to_bytes("4g"))), 0)
    return n

def test_url() -> int:
    int n = 0
    n += check_s("url encode", url_text(text_to_bytes("a b/c?d=e&f")),
                 "a%20b%2Fc%3Fd%3De%26f")
    n += check_s("url form", url_text_form(text_to_bytes("a b/c?d=e&f")),
                 "a+b%2Fc%3Fd%3De%26f")
    n += check_s("url unreserved", url_text(text_to_bytes("aZ9-_.~")), "aZ9-_.~")
    n += check_s("url empty", url_text(text_to_bytes("")), "")
    n += check_s("url control byte", url_text(text_to_bytes("\x01")), "%01")
    n += check_s("url decode", bytes_to_text(url_decode(text_to_bytes("a%20b%2Fc"))), "a b/c")
    n += check_s("url decode form", bytes_to_text(url_decode_form(text_to_bytes("a+b"))), "a b")
    n += check_s("url decode plus raw", bytes_to_text(url_decode(text_to_bytes("a+b"))), "a+b")
    n += check_i("url decode lower", (int)len(url_decode(text_to_bytes("%c3"))), 1)
    n += check_s("url round", bytes_to_text(url_decode(url_encode(text_to_bytes("x=1&y=2 %")))),
                 "x=1&y=2 %")
    n += check_i("url bad escape", (int)len(url_decode(text_to_bytes("100%"))), 0)
    n += check_i("url bad hex", (int)len(url_decode(text_to_bytes("%zz"))), 0)
    return n

public def main() -> int:
    int n = 0
    n += test_base64()
    n += test_hex()
    n += test_url()
    if n == 0:
        print("encoding: PASS")
    else:
        print("encoding: FAIL", n)
    return n
