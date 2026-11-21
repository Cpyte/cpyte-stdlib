# Self-check for @std/regex 2.1.0 (PCRE2 backend).
# Run from this directory:
#     cpy test_regex.cpy
#     cpy --opt 0 test_regex.cpy
#     cpy --opt 3 test_regex.cpy
#     cpy build --output regex_test test_regex.cpy && ./regex_test

import "regex.cpy"

def check_i(name str, got int, want int) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_i64(name str, got int64, want int64) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_s(name str, got str, want str) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_bool(name str, got bool, want bool) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def run_tests() -> int:
    int failures = 0

    # ── engine information ─────────────────────────────────────────
    failures += check_s("backend", regex_backend(), "pcre2")
    if regex_version() == "":
        print("FAIL version: empty")
        failures += 1
    if regex_valid("^ok$", 0) == false:
        print("FAIL valid pattern rejected")
        failures += 1
    if regex_valid("[abc", 0) == true:
        print("FAIL invalid pattern accepted")
        failures += 1
    if regex_last_error() == "":
        print("FAIL invalid pattern did not set last_error")
        failures += 1
    failures += check_i64("regex_len", regex_len("héllo"), (int64)6)

    # ── one-shot matching ─────────────────────────────────────────
    failures += check_i("literal hit", regex_match("^abc$", "abc"), 1)
    failures += check_i("literal miss", regex_match("^abc$", "abcd"), 0)
    failures += check_i("alternation", regex_match("^(cat|dog)$", "dog"), 1)
    failures += check_i("interval hit", regex_match("^a{2,4}$", "aaaa"), 1)
    failures += check_i("interval miss", regex_match("^a{2,4}$", "aaaaa"), 0)
    failures += check_i("shorthand class", regex_match("^\\d+$", "123"), 1)
    failures += check_i("unicode dot", regex_match("^.$", "é"), 1)
    failures += check_i("unicode word", regex_match("^\\w+$", "é"), 1)
    failures += check_i("invalid pattern", regex_match("[abc", "abc"), -1)
    failures += check_i("caseless", regex_match_flags("^abc$", "ABC", 1), 1)
    failures += check_i("unanchored", regex_match("abc", "xabc"), 1)
    failures += check_i("anchored flag", regex_match_flags("abc", "xabc", 16), 0)
    failures += check_i("search alias", regex_search("abc", "xabc", 0), 1)
    failures += check_i("fullmatch hit", regex_fullmatch("\\w+", "abc", 0), 1)
    failures += check_i("fullmatch miss", regex_fullmatch("abc", "xabc", 0), 0)
    failures += check_bool("is_match", regex_is_match("^a$", "a"), true)

    # ── compiled patterns, spans and captures ─────────────────────
    size_t h = regex_compile("^(?P<word>\\w+) (?P<num>\\d+)$", 0)
    failures += check_bool("compiled handle", regex_is_compiled(h), true)
    failures += check_s("pattern", regex_pattern(h), "^(?P<word>\\w+) (?P<num>\\d+)$")
    failures += check_i("capture count", regex_capture_count(h), 2)
    failures += check_i("named count", regex_named_count(h), 2)
    failures += check_s("group name 1", regex_group_name(h, 1), "word")
    failures += check_i("group index num", regex_group_index(h, "num"), 2)
    failures += check_i("matched compiled", regex_match_compiled(h, "abc 123"), 1)
    failures += check_bool("compiled test", regex_test(h, "abc 123"), true)

    int64[] whole = regex_find_span(h, "abc 123", (int64)0)
    failures += check_i64("whole span len", len(whole), (int64)2)
    failures += check_i64("whole start", whole[0], (int64)0)
    failures += check_i64("whole end", whole[1], (int64)7)
    failures += check_i64("find anchored miss", regex_find(h, "x abc 123", (int64)0), (int64)-1)
    size_t unanchored = regex_compile("\\w+ \\d+", 0)
    failures += check_i64("find", regex_find(unanchored, "x abc 123", (int64)0), (int64)2)
    regex_free(unanchored)

    int64[] g1 = regex_named_span(h, "abc 123", "word", (int64)0)
    failures += check_i64("word span len", len(g1), (int64)2)
    failures += check_i64("word start", g1[0], (int64)0)
    failures += check_i64("word end", g1[1], (int64)3)
    failures += check_s("word text", regex_named_text(h, "abc 123", "word", (int64)0), "abc")
    failures += check_s("num text", regex_named_text(h, "abc 123", "num", (int64)0), "123")
    failures += check_bool("group matched", regex_group_matched(h, "abc 123", 2, (int64)0), true)

    str[] caps = regex_captures(h, "abc 123", (int64)0)
    failures += check_i64("capture count result", len(caps), (int64)2)
    failures += check_s("capture 0", caps[0], "abc")
    failures += check_s("capture 1", caps[1], "123")
    int64[] allspans = regex_match_spans(h, "abc 123", (int64)0)
    failures += check_i64("match spans len", len(allspans), (int64)6)
    failures += check_i64("match span group0 start", allspans[0], (int64)0)
    failures += check_i64("match span group2 end", allspans[5], (int64)7)
    regex_free(h)
    failures += check_bool("freed handle", regex_is_compiled(h), false)

    # ── find_all / count / split ──────────────────────────────────
    size_t nums = regex_compile("\\d+", 0)
    failures += check_i64("count", regex_count(nums, "a12b345", (int64)0), (int64)2)
    int64[] spans = regex_find_all(nums, "a12b345", (int64)0)
    failures += check_i64("find_all len", len(spans), (int64)4)
    failures += check_i64("find_all s0", spans[0], (int64)1)
    failures += check_i64("find_all e0", spans[1], (int64)3)
    failures += check_i64("find_all s1", spans[2], (int64)4)
    failures += check_i64("find_all e1", spans[3], (int64)7)
    str[] found = regex_find_all_strings(nums, "a12b345", (int64)0)
    failures += check_i64("find_all_strings len", len(found), (int64)2)
    failures += check_s("find_all_strings 0", found[0], "12")
    failures += check_s("find_all_strings 1", found[1], "345")
    regex_free(nums)

    size_t delim = regex_compile(",\\s*", 0)
    str[] parts = regex_split(delim, "a, b,c", (int64)0)
    failures += check_i64("split len", len(parts), (int64)3)
    failures += check_s("split 0", parts[0], "a")
    failures += check_s("split 1", parts[1], "b")
    failures += check_s("split 2", parts[2], "c")
    regex_free(delim)

    # ── replace / quote ───────────────────────────────────────────
    size_t addr = regex_compile("(\\w+)@(\\w+)", 0)
    failures += check_s("replace groups", regex_replace(addr, "user@host", "$2.$1", (int64)0), "host.user")
    regex_free(addr)
    size_t digit = regex_compile("\\d", 0)
    failures += check_s("replace all", regex_replace_all(digit, "a1b2", "X", (int64)0), "aXbX")
    failures += check_s("replace no match", regex_replace_all(digit, "abc", "X", (int64)0), "abc")
    regex_free(digit)
    failures += check_s(
        "replace_text",
        regex_replace_text("\\d+", "a12b3", "#", 0, true),
        "a#b#",
    )
    failures += check_s("quote", regex_quote("a.b*"), "a\\.b\\*")
    failures += check_s("escape alias", regex_escape("a+b?"), "a\\+b\\?")

    # ── complex Unicode pattern from the tokenizer use case ───────
    str complex_pat = "[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]*[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?|[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]+[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?|\\p{N}{1,3}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n/]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+"
    size_t tok = regex_compile(complex_pat, 0)
    failures += check_bool("unicode tokenizer compiles", regex_is_compiled(tok), true)
    if regex_is_compiled(tok):
        failures += check_i("unicode tokenizer matches", regex_match_compiled(tok, "Hello, world! 123"), 1)
        regex_free(tok)

    if failures == 0:
        print("regex: PASS")
    else:
        print("regex: FAIL", failures)
    return failures

run_tests()
