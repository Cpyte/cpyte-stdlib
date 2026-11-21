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

## API

```cpyte
import "@std/regex"

regex_backend() -> str
regex_match(pat str, text str) -> int
regex_match_flags(pat str, text str, flags int) -> int
regex_compile(pat str, flags int) -> size_t
regex_match_compiled(handle size_t, text str) -> int
regex_is_compiled(handle size_t) -> bool
regex_free(handle size_t) -> void
```

`regex_compile()` returns `0` on failure. Compiled handles stay valid until
`regex_free()` is called; handles are not reused.

### Flags

`flags` is a bitmask:

| Bit | Meaning |
| ---: | --- |
| 1 | case-insensitive |
| 2 | `^`/`$` match at line boundaries |
| 4 | `.` matches newlines |
| 8 | extended/verbose pattern syntax |
| 16 | anchor the match at the start of the subject |
| 32 | require the match to end at the end of the subject |

## Example

```cpyte
import "@std/regex"

if regex_backend() == "":
    print("PCRE2 is required for @std/regex")
else:
    print(regex_match("^[a-z]+$", "hello"))       # 1
    print(regex_match_flags("^abc$", "ABC", 1))   # 1

    size_t h = regex_compile("^h[aeu]llo$", 0)
    print(regex_match_compiled(h, "hullo"))       # 1
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
