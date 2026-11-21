# @std/regex

Production regex support for Cpyte, backed by the prebuilt **PCRE2** shared
library. The engine is loaded at runtime with `dlopen()` on POSIX and
`LoadLibraryA()` on Windows, so the package has no link-time dependency and
works with both the JIT and native AOT builds.

## Behaviour

- Patterns and subjects are UTF-8 (`PCRE2_UTF`).
- `\d`, `\w`, and `\s` use Unicode properties (`PCRE2_UCP`).
- `$` matches only at the end of the subject (`PCRE2_DOLLAR_ENDONLY`).
- `regex_match*` returns:
  - `1` — match
  - `0` — no match
  - `-1` — invalid pattern/subject, invalid handle, or engine unavailable
- `regex_backend()` returns `"pcre2"` when the engine is loaded, otherwise `""`.
- Spans are byte offsets into the UTF-8 subject, as `[start, end]` pairs.
  An empty `int64[]` means "no match".

## Library discovery

The loader tries, in order:

1. `CPYTE_REGEX_PCRE2_LIBRARY` — exact path or library name.
2. Platform library name:
   - Windows: `pcre2-8.dll`
   - POSIX: `libpcre2-8.so.0`, `libpcre2-8.dylib`, `libpcre2-8.so`
3. `CPYTE_REGEX_PCRE2_LIBDIR/<library name>`.
4. Common Homebrew and Linux multiarch locations.

If PCRE2 is not installed, matching returns `-1`; programs can check
`regex_backend()` and report a friendly error.

## Flags

`flags` is a bitmask:

| Bit | Meaning |
| ---: | --- |
| 1 | case-insensitive |
| 2 | `^`/`$` match at line boundaries |
| 4 | `.` matches newlines |
| 8 | extended/verbose pattern syntax |
| 16 | anchor the match at the start of the subject |
| 32 | require the match to end at the end of the subject |

## API

### Engine information

```cpyte
regex_backend() -> str
regex_version() -> str
regex_last_error() -> str
regex_error_code() -> int
regex_error_offset() -> int64
regex_len(text str) -> int64
regex_next(text str, pos int64) -> int64
```

### Compile and inspect patterns

```cpyte
regex_compile(pat str, flags int) -> size_t
regex_valid(pat str, flags int) -> bool
regex_is_compiled(handle size_t) -> bool
regex_pattern(handle size_t) -> str
regex_capture_count(handle size_t) -> int
regex_named_count(handle size_t) -> int
regex_group_name(handle size_t, group int) -> str
regex_group_index(handle size_t, name str) -> int
regex_free(handle size_t) -> void
```

`regex_compile()` returns `0` on failure. Compiled handles stay valid until
`regex_free()` is called; handles are not reused.

### Match

```cpyte
regex_match(pat str, text str) -> int
regex_match_flags(pat str, text str, flags int) -> int
regex_search(pat str, text str, flags int) -> int
regex_fullmatch(pat str, text str, flags int) -> int
regex_is_match(pat str, text str) -> bool

regex_match_compiled(handle size_t, text str) -> int
regex_test(handle size_t, text str) -> bool
regex_find(handle size_t, text str, start int64) -> int64
regex_find_span(handle size_t, text str, start int64) -> int64[]
```

### Captures and matches

```cpyte
regex_group_span(handle size_t, text str, group int, start int64) -> int64[]
regex_named_span(handle size_t, text str, name str, start int64) -> int64[]
regex_group_matched(handle size_t, text str, group int, start int64) -> bool
regex_group_text(handle size_t, text str, group int, start int64) -> str
regex_named_text(handle size_t, text str, name str, start int64) -> str
regex_match_spans(handle size_t, text str, start int64) -> int64[]
regex_captures(handle size_t, text str, start int64) -> str[]
```

### Find all, split, replace, quote

```cpyte
regex_count(handle size_t, text str, start int64) -> int64
regex_find_all(handle size_t, text str, start int64) -> int64[]
regex_find_all_strings(handle size_t, text str, start int64) -> str[]
regex_split(handle size_t, text str, start int64) -> str[]

regex_replace_ex(handle size_t, text str, replacement str, start int64, replace_all bool) -> str
regex_replace(handle size_t, text str, replacement str, start int64) -> str
regex_replace_all(handle size_t, text str, replacement str, start int64) -> str
regex_replace_text(pat str, text str, replacement str, flags int, replace_all bool) -> str
regex_split_text(pat str, text str, flags int, start int64) -> str[]
regex_find_all_text(pat str, text str, flags int, start int64) -> int64[]

regex_quote(s str) -> str
regex_escape(s str) -> str
```

Replacement strings support `$0`/`$1`/... and `${name}` for named groups;
use `$$` for a literal dollar sign.

## Example

```cpyte
import "@std/regex"

if regex_backend() == "":
    print("PCRE2 is required for @std/regex")
else:
    print(regex_match("^[a-z]+$", "hello"))       # 1
    print(regex_match_flags("^abc$", "ABC", 1))   # 1

    size_t h = regex_compile("^(?P<word>\\w+) (?P<num>\\d+)$", 0)
    print(regex_named_text(h, "abc 123", "num", (int64)0))  # 123
    print(regex_replace_all(h, "abc 123", "X", (int64)0))   # X
    regex_free(h)
```

## Tests

```bash
cd /path/to/WEW-stdlib/regex
cpy test_regex.cpy
cpy --opt 0 test_regex.cpy
cpy --opt 3 test_regex.cpy
cpy build --output regex_test test_regex.cpy && ./regex_test
```
