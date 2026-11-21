# Self-check for @std/strings. Exits non-zero on the first failing count, so
# ci_test.py / `cpy` runs treat the printed line as the source of truth.

import "strings.cpy"

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

def test_bytes() -> int:
    int n = 0
    n += check_i("byte_length ascii", str_byte_length("hello"), 5)
    n += check_i("byte_length empty", str_byte_length(""), 0)
    n += check_i("byte_length utf8", str_byte_length("é"), 2)
    n += check_i("byte_at", str_byte_at("abc", 1), 98)
    n += check_i("byte_at unsigned", str_byte_at("é", 0), 195)
    n += check_i("byte_at oob", str_byte_at("abc", 9), -1)
    n += check_s("from_byte", str_from_byte(65), "A")
    n += check_s("from_byte round", str_from_byte(str_byte_at("z", 0)), "z")
    return n

def test_search() -> int:
    int n = 0
    n += check_i("find", str_find("hello world", "o"), 4)
    n += check_i("find missing", str_find("hello", "z"), -1)
    n += check_i("find empty needle", str_find("abc", ""), 0)
    n += check_i("find whole", str_find("abc", "abc"), 0)
    n += check_i("find_from", str_find_from("banana", "a", 2), 3)
    n += check_i("find_from past end", str_find_from("abc", "a", 4), -1)
    n += check_i("rfind", str_rfind("hello world", "o"), 7)
    n += check_i("rfind missing", str_rfind("abc", "z"), -1)
    n += check_i("count", str_count("banana", "na"), 2)
    n += check_i("count aaa", str_count("aaaa", "aa"), 2)
    n += check_i("count none", str_count("abc", "z"), 0)
    n += check_b("contains", str_contains("hello", "ell"), true)
    n += check_b("not contains", str_contains("hello", "ellz"), false)
    return n

def test_compare() -> int:
    int n = 0
    n += check_b("starts_with", str_starts_with("hello", "he"), true)
    n += check_b("starts_with long", str_starts_with("he", "hello"), false)
    n += check_b("ends_with", str_ends_with("hello", "lo"), true)
    n += check_b("ends_with short", str_ends_with("lo", "hello"), false)
    n += check_b("equals", str_equals("abc", "abc"), true)
    n += check_b("equals diff", str_equals("abc", "abd"), false)
    n += check_b("equals_ci", str_equals_ci("AbC", "aBc"), true)
    n += check_i("compare eq", str_compare("abc", "abc"), 0)
    if str_compare("abc", "abd") >= 0:
        print("FAIL compare order")
        n += 1
    if str_compare("abd", "abc") <= 0:
        print("FAIL compare order 2")
        n += 1
    n += check_b("compare_ci shorter", str_compare_ci("ABC", "abd") < 0, true)
    return n

def test_classify() -> int:
    int n = 0
    n += check_b("is_empty", str_is_empty(""), true)
    n += check_b("is_empty no", str_is_empty("a"), false)
    n += check_b("is_alpha", str_is_alpha("abcXYZ"), true)
    n += check_b("is_alpha digit", str_is_alpha("ab1"), false)
    n += check_b("is_alpha empty", str_is_alpha(""), false)
    n += check_b("is_digit", str_is_digit("0139"), true)
    n += check_b("is_digit sign", str_is_digit("-1"), false)
    n += check_b("is_alnum", str_is_alnum("abc123"), true)
    n += check_b("is_space", str_is_space(" \t\n"), true)
    n += check_b("is_upper", str_is_upper("ABC"), true)
    n += check_b("is_lower", str_is_lower("abc"), true)
    n += check_b("is_punct", str_is_punct("!?,-"), true)
    n += check_b("is_print", str_is_print("a Z9"), true)
    n += check_b("is_hex", str_is_hex("deadBEEF"), true)
    n += check_b("is_hex no", str_is_hex("deadbeeg"), false)
    n += check_b("is_all_of", str_is_all_of("abc", "acb"), true)
    n += check_b("is_all_of no", str_is_all_of("abd", "acb"), false)
    return n

def test_slice() -> int:
    int n = 0
    n += check_s("substring", str_substring("hello", 1, 3), "el")
    n += check_s("substring clamp hi", str_substring("hello", 3, 99), "lo")
    n += check_s("substring clamp lo", str_substring("hello", -5, 2), "he")
    n += check_s("substring inverted", str_substring("hello", 3, 2), "")
    n += check_s("substring whole", str_substring("hello", 0, 5), "hello")
    n += check_s("slice_from", str_slice_from("abcdef", 3), "def")
    n += check_s("slice_to", str_slice_to("abcdef", 3), "abc")
    n += check_s("utf8 both bytes", str_substring("é", 0, 2), "é")
    return n

def test_case() -> int:
    int n = 0
    n += check_s("lower", str_lower("Hello WORLD"), "hello world")
    n += check_s("upper", str_upper("Hello world"), "HELLO WORLD")
    n += check_s("lower empty", str_lower(""), "")
    n += check_s("swapcase", str_swapcase("AbC123"), "aBc123")
    n += check_s("capitalize", str_capitalize("hELLO"), "Hello")
    n += check_s("capitalize empty", str_capitalize(""), "")
    n += check_s("title", str_title("hello world"), "Hello World")
    n += check_s("title digits", str_title("v2 beta"), "V2 Beta")
    return n

def test_trim_pad() -> int:
    int n = 0
    n += check_s("trim", str_trim("  hi  "), "hi")
    n += check_s("trim tabs", str_trim("\t\n hi \r"), "hi")
    n += check_s("trim all space", str_trim("   "), "")
    n += check_s("trim none", str_trim("hi"), "hi")
    n += check_s("trim_left", str_trim_left("  hi  "), "hi  ")
    n += check_s("trim_right", str_trim_right("  hi  "), "  hi")
    n += check_s("strip_chars", str_strip_chars("xxhixx", "x"), "hi")
    n += check_s("strip_chars set", str_strip_chars("/-/abc/-/", "/-"), "abc")
    n += check_s("pad_left", str_pad_left("7", 3, "0"), "007")
    n += check_s("pad_left no-op", str_pad_left("abcdef", 3, "0"), "abcdef")
    n += check_s("pad_right", str_pad_right("ab", 5, "."), "ab...")
    n += check_s("pad_right empty pad", str_pad_right("ab", 5, ""), "ab")
    n += check_s("pad_center", str_pad_center("ab", 6, "*"), "**ab**")
    n += check_s("repeat", str_repeat("ab", 3), "ababab")
    n += check_s("repeat zero", str_repeat("x", 0), "")
    return n

def test_split_join() -> int:
    int n = 0
    str[] p = str_split_parts("a,b,c", ",")
    n += check_i("split len", (int)len(p), 3)
    n += check_s("split 0", p[0], "a")
    n += check_s("split 1", p[1], "b")
    n += check_s("split 2", p[2], "c")
    str[] e = str_split_parts("a,,b", ",")
    n += check_i("split empty part", (int)len(e), 3)
    n += check_s("split middle empty", e[1], "")
    str[] none = str_split_parts("", ",")
    n += check_i("split empty string", (int)len(none), 0)
    str[] once = str_split_parts("abc", ",")
    n += check_i("split no sep", (int)len(once), 1)
    n += check_s("split no sep part", once[0], "abc")
    str[] whole = str_split_parts("abc", "abc")
    n += check_i("split whole sep", (int)len(whole), 2)
    n += check_s("trailing sep", str_split_parts("a,", ",")[1], "")
    str[] lines = str_split_lines("a\r\nb\n")
    n += check_i("split_lines len", (int)len(lines), 3)
    n += check_s("split_lines 0", lines[0], "a")
    n += check_s("split_lines 1", lines[1], "b")
    str[] ws = str_split_parts("one two", " ")
    n += check_s("join", str_join(ws, "-"), "one-two")
    n += check_s("join empty sep", str_join(ws, ""), "onetwo")
    n += check_s("join one", str_join(once, ","), "abc")
    n += check_s("join zero", str_join(none, ","), "")
    n += check_s("split join round", str_join(str_split_parts("x,y,z", ","), "|"), "x|y|z")
    return n

def test_replace_misc() -> int:
    int n = 0
    n += check_s("replace", str_replace("banana", "na", "N"), "baNN")
    n += check_s("replace grow", str_replace("a-b-c", "-", " -> "), "a -> b -> c")
    n += check_s("replace missing", str_replace("abc", "z", "Y"), "abc")
    n += check_s("replace empty from", str_replace("abc", "", "Y"), "abc")
    n += check_s("replace all", str_replace("aaa", "a", "b"), "bbb")
    n += check_s("replace_first", str_replace_first("banana", "na", "N"), "baNna")
    n += check_s("replace_first missing", str_replace_first("abc", "z", "Y"), "abc")
    n += check_s("reverse", str_reverse("abc"), "cba")
    n += check_s("reverse empty", str_reverse(""), "")
    n += check_s("reverse one", str_reverse("a"), "a")
    return n

public def main() -> int:
    int n = 0
    n += test_bytes()
    n += test_search()
    n += test_compare()
    n += test_classify()
    n += test_slice()
    n += test_case()
    n += test_trim_pad()
    n += test_split_join()
    n += test_replace_misc()
    if n == 0:
        print("strings: PASS")
    else:
        print("strings: FAIL", n)
    return n
