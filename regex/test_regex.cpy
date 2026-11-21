# Self-check for @std/regex. Run from this directory:
#     cpy test_regex.cpy
#
# It verifies that the production PCRE2 backend is loaded and that both the
# one-shot and compiled-pattern APIs work, including UTF-8/UCP behaviour.

import "regex.cpy"

def check_i(name str, got int, want int) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def run_tests() -> int:
    int failures = 0

    if regex_backend() != "pcre2":
        print("FAIL backend: want pcre2, got", regex_backend())
        failures += 1

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
    failures += check_i("anchored flag", regex_match_flags("abc", "xabc", 16), 0)
    failures += check_i("unanchored", regex_match("abc", "xabc"), 1)

    size_t h = regex_compile("^h[aeu]llo$", 0)
    int compiled = 0
    if regex_is_compiled(h):
        compiled = 1
    failures += check_i("compiled handle", compiled, 1)
    failures += check_i("compiled hit 1", regex_match_compiled(h, "hello"), 1)
    failures += check_i("compiled hit 2", regex_match_compiled(h, "hullo"), 1)
    failures += check_i("compiled miss", regex_match_compiled(h, "bye"), 0)
    regex_free(h)
    compiled = 0
    if regex_is_compiled(h):
        compiled = 1
    failures += check_i("freed handle", compiled, 0)
    failures += check_i("null handle", regex_match_compiled((size_t)0, "x"), -1)

    if failures == 0:
        print("regex: PASS")
    else:
        print("regex: FAIL", failures)
    return failures

run_tests()
