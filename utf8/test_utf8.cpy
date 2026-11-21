# Self-check for @std/utf8. Run from this directory:
#     cpy test_utf8.cpy
# The vectors below live in C string literals so that `\xNN` produces raw
# bytes; a cpy-level `"\xNN"` is a Unicode codepoint re-encoded as UTF-8.

import "utf8.cpy"

ccode:
    #include <stdint.h>
    #include <string.h>

    const char* u8t_vec(int id) {
        switch (id) {
            case 0:  return "";                                   /* empty */
            case 1:  return "A";                                  /* ASCII */
            case 2:  return "\xC3\xA9";                           /* U+00E9 */
            case 3:  return "\xE2\x82\xAC";                       /* U+20AC */
            case 4:  return "\xF0\x9D\x84\x9E";                   /* U+1D11E */
            case 5:  return "\xED\xA0\x80";                       /* surrogate */
            case 6:  return "\xC0\xAF";                           /* overlong C0 */
            case 7:  return "\xE0\x80\xAF";                       /* overlong E0 */
            case 8:  return "\xF4\x90\x80\x80";                   /* > U+10FFFF */
            case 9:  return "\xF0\x9D\x84";                       /* truncated */
            case 10: return "\xE2\x28\xA1";                       /* bad continuation */
            case 11: return "\x80";                               /* stray continuation */
            case 12: return "\xC3";                               /* truncated 2-byte */
            case 13: return "\x41\x00\x42";                       /* embedded NUL */
            case 14: return "\xC3\xA9\xE2\x82\xAC\xF0\x9D\x84\x9E";
            case 15: return "\xED\xBF\xBF";                       /* surrogate DFFF */
            case 16: return "\xF5\x80\x80\x80";                   /* invalid lead F5 */
            case 17: return "\xE2\x82\xAC\x41\xC3";               /* valid + bad tail */
            case 18: return "\xEF\xBF\xBD";                       /* U+FFFD */
            case 19: return "\xC2\x80";                           /* U+0080 */
            case 20: return "\xDF\xBF";                           /* U+07FF */
            case 21: return "\xE0\xA0\x80";                       /* U+0800 */
            case 22: return "\xF4\x8F\xBF\xBF";                   /* U+10FFFF */
            case 23: return "\xF0\x9F\x98\x80";                   /* U+1F600 */
            case 24: return "\x00\xC3\xA9\xE2\x82\xAC\xF0\x9D\x84\x9E";
            case 25: return "\xE2\x82\xAC\x41\xEF\xBF\xBD";       /* repair of 17 */
            case 26: return "\x41\xE9\xFF";                       /* Latin-1 */
            case 27: return "\x41\xC3\xA9\xC3\xBF";               /* Latin-1 -> UTF-8 */
            case 28: return "\x80\x91\x99\x9F";                   /* CP1252 */
            case 29: return "\xE2\x82\xAC\xE2\x80\x98\xE2\x84\xA2\xC5\xB8";
            case 30: return "\x41\x00\xE9\x00\x3D\xD8\x00\xDE";   /* UTF-16LE */
            case 31: return "\x41\xC3\xA9\xF0\x9F\x98\x80";       /* A, e-acute, emoji */
            case 32: return "\x00\x41\x00\xE9\xD8\x3D\xDE\x00";   /* UTF-16BE */
            case 33: return "\x3D\xD8";                           /* lone high surrogate */
            case 34: return "\x00\xDE";                           /* lone low surrogate */
            case 35: return "\x41";                               /* odd UTF-16 length */
            case 36: return "\x41\x00\x00\x00\xE9\x00\x00\x00\x00\xF6\x01\x00";
            case 37: return "\x00\x00\x00\x41\x00\x00\x00\xE9\x00\x01\xF6\x00";
            case 38: return "\x00\xD8\x00\x00";                   /* UTF-32 surrogate */
            case 39: return "\x81";                               /* CP1252 undefined */
            case 40: return "\x80\x80";                           /* two bad bytes */
            case 41: return "\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD";
            case 42: return "\x80";                               /* Euro in CP1252 */
            case 43: return "\x00";                               /* a single NUL byte */
            case 44: return "\xFF";                               /* CP1252/Latin-1 0xFF */
            case 45: return "\xC3\xBF";                           /* U+00FF in UTF-8 */
            case 46: return "\xE2\x28";                           /* bad continuation, no 3rd byte */
            case 47: return "\xE0\x80";                           /* overlong, no 3rd byte */
            case 48: return "\xED\xA0";                           /* surrogate, no 3rd byte */
            case 49: return "\xF4\x90";                           /* > U+10FFFF, no 3rd byte */
            default: return "";
        }
    }

    int64_t u8t_vec_len(int id) {
        if (id == 13) return (int64_t)3;    /* contains an embedded NUL */
        if (id == 24) return (int64_t)10;
        if (id == 30 || id == 32) return (int64_t)8;
        if (id == 36 || id == 37) return (int64_t)12;
        if (id == 38) return (int64_t)4;
        if (id == 43) return (int64_t)1;
        return (int64_t)strlen(u8t_vec(id));
    }

    void u8t_copy(void* dst, const char* src, int64_t n) {
        memcpy(dst, src, (size_t)n);
    }

def vec(id int) -> char[]:
    int64 n = u8t_vec_len(id)
    char[] out = new char[n]
    u8t_copy((void*)out, u8t_vec(id), n)
    return out

def check_i(name str, got int64, want int64) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_s(name str, got str, want str) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_b(name str, got bool, want bool) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_bytes(name str, got char[], want char[]) -> int:
    if len(got) != len(want):
        print("FAIL", name, "length want", len(want), "got", len(got))
        return 1
    int i = 0
    while i < (int)len(got):
        if (((int)got[i]) & 255) != (((int)want[i]) & 255):
            print("FAIL", name, "at byte", i)
            return 1
        i = i + 1
    return 0

def valid_vec(name str, id int, cps int64) -> int:
    int n = 0
    char[] b = vec(id)
    n += check_b(name + " valid", is_valid(b), true)
    n += check_i(name + " first_error", first_error(b), (int64)-1)
    n += check_i(name + " error_code", (int64)error_code(b), (int64)0)
    n += check_i(name + " count", count_codepoints(b), cps)
    n += check_i(name + " prefix", valid_prefix(b), len(b))
    return n

def invalid_vec(name str, id int, pos int64, code int) -> int:
    int n = 0
    char[] b = vec(id)
    n += check_b(name + " invalid", is_valid(b), false)
    n += check_i(name + " first_error", first_error(b), pos)
    n += check_i(name + " error_code", (int64)error_code(b), (int64)code)
    n += check_i(name + " count", count_codepoints(b), (int64)-1)
    n += check_i(name + " prefix", valid_prefix(b), pos)
    return n

def test_validation() -> int:
    int n = 0
    n += valid_vec("empty", 0, (int64)0)
    n += valid_vec("ascii", 1, (int64)1)
    n += valid_vec("two-byte", 2, (int64)1)
    n += valid_vec("three-byte", 3, (int64)1)
    n += valid_vec("four-byte", 4, (int64)1)
    n += valid_vec("nul", 13, (int64)3)
    n += valid_vec("mixed", 14, (int64)3)
    n += valid_vec("u0080", 19, (int64)1)
    n += valid_vec("u07ff", 20, (int64)1)
    n += valid_vec("u0800", 21, (int64)1)
    n += valid_vec("u10ffff", 22, (int64)1)
    n += valid_vec("ufffd", 18, (int64)1)
    n += valid_vec("emoji", 23, (int64)1)

    n += invalid_vec("surrogate-d800", 5, (int64)0, 4)
    n += invalid_vec("surrogate-dfff", 15, (int64)0, 4)
    n += invalid_vec("overlong-c0", 6, (int64)0, 1)
    n += invalid_vec("overlong-e0", 7, (int64)0, 3)
    n += invalid_vec("too-large", 8, (int64)0, 5)
    n += invalid_vec("truncated-four", 9, (int64)0, 2)
    n += invalid_vec("truncated-two", 12, (int64)0, 2)
    n += invalid_vec("bad-continuation", 10, (int64)0, 1)
    n += invalid_vec("stray-continuation", 11, (int64)0, 1)
    n += invalid_vec("invalid-lead-f5", 16, (int64)0, 1)
    n += invalid_vec("bad-tail", 17, (int64)4, 2)
    n += invalid_vec("partial-bad-cont", 46, (int64)0, 1)
    n += invalid_vec("partial-overlong", 47, (int64)0, 3)
    n += invalid_vec("partial-surrogate", 48, (int64)0, 4)
    n += invalid_vec("partial-too-large", 49, (int64)0, 5)

    n += check_b("scalar nul", is_scalar(0), true)
    n += check_b("scalar max", is_scalar(0x10FFFF), true)
    n += check_b("scalar surrogate", is_scalar(0xD800), false)
    n += check_b("scalar too large", is_scalar(0x110000), false)
    n += check_b("scalar negative", is_scalar(-1), false)
    n += check_i("width ascii", cp_bytes(0x41), 1)
    n += check_i("width 2", cp_bytes(0x80), 2)
    n += check_i("width 3", cp_bytes(0x800), 3)
    n += check_i("width 4", cp_bytes(0x10000), 4)
    n += check_i("width invalid", cp_bytes(0xD800), 0)
    return n

def test_codepoints() -> int:
    int n = 0
    int[] cps = decode(vec(14))
    n += check_i("decode len", (int64)len(cps), (int64)3)
    n += check_i("decode 0", (int64)cps[0], (int64)0xE9)
    n += check_i("decode 1", (int64)cps[1], (int64)0x20AC)
    n += check_i("decode 2", (int64)cps[2], (int64)0x1D11E)
    n += check_i("decode strict invalid", (int64)len(decode(vec(5))), (int64)0)

    int[] with_nul = decode(vec(13))
    n += check_i("decode nul len", (int64)len(with_nul), (int64)3)
    n += check_i("decode nul 0", (int64)with_nul[0], (int64)65)
    n += check_i("decode nul 1", (int64)with_nul[1], (int64)0)
    n += check_i("decode nul 2", (int64)with_nul[2], (int64)66)

    int[] lossy = decode_lossy(vec(5))
    n += check_i("lossy surrogate len", (int64)len(lossy), (int64)3)
    n += check_i("lossy surrogate 0", (int64)lossy[0], (int64)0xFFFD)
    n += check_i("lossy surrogate 2", (int64)lossy[2], (int64)0xFFFD)
    int[] lossy2 = decode_lossy(vec(17))
    n += check_i("lossy tail len", (int64)len(lossy2), (int64)3)
    n += check_i("lossy tail cp", (int64)lossy2[0], (int64)0x20AC)
    n += check_i("lossy tail bad", (int64)lossy2[2], (int64)0xFFFD)
    int[] lossy3 = decode_lossy(vec(40))
    n += check_i("lossy two stray", (int64)len(lossy3), (int64)2)

    int[] three = new int[3]
    three[0] = 0xE9
    three[1] = 0x20AC
    three[2] = 0x1D11E
    n += check_bytes("encode round", encode(three), vec(14))
    n += check_bytes("encode nul", encode_cp(0), vec(43))
    n += check_i("encode nul len", (int64)len(encode_cp(0)), (int64)1)
    n += check_bytes("encode emoji", encode_cp(0x1F600), vec(23))
    int[] bad_cp = new int[1]
    bad_cp[0] = 0xD800
    n += check_i("strict encode invalid", (int64)len(encode(bad_cp)), (int64)0)
    n += check_bytes("lossy encode invalid", encode_lossy(bad_cp), vec(18))

    n += check_i("cp at 0", (int64)codepoint_at(vec(14), (int64)0), (int64)0xE9)
    n += check_i("cp at 1", (int64)codepoint_at(vec(14), (int64)1), (int64)0x20AC)
    n += check_i("cp at 2", (int64)codepoint_at(vec(14), (int64)2), (int64)0x1D11E)
    n += check_i("cp at 3", (int64)codepoint_at(vec(14), (int64)3), (int64)-1)
    n += check_i("byte at 0", byte_at(vec(14), (int64)0), (int64)0)
    n += check_i("byte at 1", byte_at(vec(14), (int64)1), (int64)2)
    n += check_i("byte at 2", byte_at(vec(14), (int64)2), (int64)5)
    n += check_i("byte at end", byte_at(vec(14), (int64)3), (int64)9)
    n += check_i("byte at past end", byte_at(vec(14), (int64)4), (int64)-1)

    int[] one = new int[2]
    n += check_b("decode_at ok", decode_at(vec(14), (int64)2, one), true)
    n += check_i("decode_at cp", (int64)one[0], (int64)0x20AC)
    n += check_i("decode_at size", (int64)one[1], (int64)3)
    n += check_b("decode_at bad", decode_at(vec(14), (int64)3, one), false)
    int[] small = new int[1]
    small[0] = 123
    n += check_b("decode_at small buffer", decode_at(vec(14), (int64)0, small), false)
    n += check_i("decode_at small no write", (int64)small[0], (int64)123)

    n += check_bytes("repair surrogate", repair(vec(5)), vec(41))
    n += check_bytes("repair tail", repair(vec(17)), vec(25))
    n += check_bytes("repair valid", repair(vec(14)), vec(14))
    return n

def test_text() -> int:
    int n = 0
    str s = "héllo ☃"                 # 10 bytes, 7 codepoints
    n += check_b("text valid", text_is_valid(s), true)
    n += check_i("text bytes", (int64)len(text_bytes(s)), (int64)10)
    n += check_i("text count", text_count(s), (int64)7)
    int[] cps = text_decode(s)
    n += check_i("text decode len", (int64)len(cps), (int64)7)
    n += check_i("text decode e-acute", (int64)cps[1], (int64)0xE9)
    n += check_i("text decode snowman", (int64)cps[6], (int64)0x2603)
    n += check_s("text round trip", text_encode(cps), s)
    n += check_s("text repair valid", text_repair(s), s)
    return n

def test_legacy() -> int:
    int n = 0
    n += check_bytes("latin1 to utf8", latin1_to_utf8(vec(26)), vec(27))
    n += check_bytes("utf8 to latin1", utf8_to_latin1(vec(27)), vec(26))
    n += check_i("utf8 to latin1 unmappable", (int64)len(utf8_to_latin1(vec(14))), (int64)0)

    n += check_bytes("cp1252 to utf8", cp1252_to_utf8(vec(28)), vec(29))
    n += check_bytes("utf8 to cp1252", utf8_to_cp1252(vec(29)), vec(28))
    n += check_i("cp1252 undefined", (int64)len(cp1252_to_utf8(vec(39))), (int64)0)
    n += check_bytes("cp1252 high byte", cp1252_to_utf8(vec(44)), vec(45))
    n += check_bytes("cp1252 reverse high", utf8_to_cp1252(vec(45)), vec(44))
    n += check_bytes("cp1252 euro", utf8_to_cp1252(vec(3)), vec(42))

    n += check_bytes("utf16le to utf8", utf16_to_utf8(vec(30), false), vec(31))
    n += check_bytes("utf16be to utf8", utf16_to_utf8(vec(32), true), vec(31))
    n += check_bytes("utf8 to utf16le", utf8_to_utf16(vec(31), false), vec(30))
    n += check_bytes("utf8 to utf16be", utf8_to_utf16(vec(31), true), vec(32))
    n += check_i("utf16 lone high", (int64)len(utf16_to_utf8(vec(33), false)), (int64)0)
    n += check_i("utf16 lone low", (int64)len(utf16_to_utf8(vec(34), false)), (int64)0)
    n += check_i("utf16 odd length", (int64)len(utf16_to_utf8(vec(35), false)), (int64)0)

    n += check_bytes("utf32le to utf8", utf32_to_utf8(vec(36), false), vec(31))
    n += check_bytes("utf32be to utf8", utf32_to_utf8(vec(37), true), vec(31))
    n += check_bytes("utf8 to utf32le", utf8_to_utf32(vec(31), false), vec(36))
    n += check_bytes("utf8 to utf32be", utf8_to_utf32(vec(31), true), vec(37))
    n += check_i("utf32 surrogate", (int64)len(utf32_to_utf8(vec(38), false)), (int64)0)
    n += check_i("utf32 len error", cpy_u8_utf8_to_utf32_len((void*)vec(5), len(vec(5))), (int64)-1)

    n += check_s("latin1 as text", bytes_to_text(latin1_to_utf8(vec(26))), "Aéÿ")
    n += check_s("cp1252 as text", bytes_to_text(cp1252_to_utf8(vec(28))), "€‘™Ÿ")
    return n

public def main() -> int:
    int n = 0
    n += test_validation()
    n += test_codepoints()
    n += test_text()
    n += test_legacy()
    if n == 0:
        print("utf8: PASS")
    else:
        print("utf8: FAIL", n)
    return n
