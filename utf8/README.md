# @std/utf8

Strict UTF-8 validation, codepoint charmaps and legacy charset conversion for
cpyte. Self-contained (C helpers in a `ccode:` block); no dependencies.

Install it like the other stdlib packages, then import it:

```cpy
import "@std/utf8"

public def main() -> int:
    str s = "héllo ☃"
    print(text_is_valid(s), text_count(s))   # 1 7
    int[] cps = text_decode(s)
    print(cps[1], cps[6])                    # 233 9731
    print(text_encode(cps))                  # héllo ☃
    return 0
```

## Conventions

- Byte buffers are `char[]`; their `len()` is the exact byte count, so
  embedded NULs and truncated sequences round-trip. Codepoint buffers are
  `int[]` (one i32 per Unicode scalar).
- Results are freshly GC-allocated arrays. Failure is reported as an empty
  array or a negative integer — never as a partially decoded value.
- Validation implements Unicode 15 Table 3-7: overlong encodings, UTF-16
  surrogates and values above U+10FFFF are rejected. Bytes that are present
  are classified before a missing byte is reported as truncation, so `E2 28`
  is a bad continuation and `E0 80` is overlong.
- Lossy helpers replace each *maximal invalid subsequence* (Unicode Standard
  §3.9.6, definition D93b) with one U+FFFD. This is an interoperability
  practice, not a Unicode conformance requirement.
- `bytes_to_text` NUL-terminates a byte buffer; it is only appropriate for
  text that contains no embedded NUL.
- Buffer contract: `len() == 0` permits a null pointer; a positive length
  requires a buffer with at least that many bytes/elements. A null output
  pointer is allowed only for length queries.
- UTF-16 input must have an even byte length; UTF-32 input must have a byte
  length divisible by four. Byte order is selected explicitly by the
  `big_endian` argument; BOM detection is not implemented.

## Validation and navigation

| Function | Result |
|---|---|
| `is_valid(data char[]) -> bool` | strict UTF-8 check |
| `first_error(data char[]) -> int64` | first bad byte index, or `-1` if valid |
| `error_code(data char[]) -> int` | `0` valid, `1` bad lead/continuation, `2` truncated, `3` overlong, `4` surrogate, `5` above U+10FFFF |
| `count_codepoints(data char[]) -> int64` | scalar count, or `-1` if malformed |
| `valid_prefix(data char[]) -> int64` | byte length of the longest well-formed prefix |
| `is_scalar(cp int) -> bool` | valid Unicode scalar (not a surrogate, ≤ U+10FFFF) |
| `cp_bytes(cp int) -> int` | encoded width 1..4, or `0` for an invalid scalar |

## Codepoint charmaps

| Function | Result |
|---|---|
| `decode(data char[]) -> int[]` | codepoints; empty if malformed |
| `decode_lossy(data char[]) -> int[]` | codepoints with U+FFFD for bad subsequences |
| `encode(cps int[]) -> char[]` | UTF-8 bytes; empty if any value is not a scalar |
| `encode_lossy(cps int[]) -> char[]` | invalid values become U+FFFD |
| `encode_cp(cp int) -> char[]` | one scalar as bytes |
| `codepoint_at(data char[], index int64) -> int` | scalar at a codepoint index (`-1` on error) |
| `byte_at(data char[], index int64) -> int64` | byte offset of a codepoint index (`n` for `index == count`) |
| `decode_at(data, pos int64, out int[]) -> bool` | `out[0]` scalar, `out[1]` byte width; `out` must hold at least two elements (otherwise `false`, no write) |
| `repair(data char[]) -> char[]` | valid bytes verbatim, bad subsequences → U+FFFD |

## Legacy charmaps

All conversions are strict: malformed input or an unmappable character
yields an empty array.

- `latin1_to_utf8` / `utf8_to_latin1`
- `cp1252_to_utf8` / `utf8_to_cp1252` (undefined bytes 81, 8D, 8F, 90, 9D rejected)
- `utf16_to_utf8(data, big_endian bool)` / `utf8_to_utf16(data, big_endian bool)`
  (surrogate pairs handled)
- `utf32_to_utf8(data, big_endian bool)` / `utf8_to_utf32(data, big_endian bool)`

These take byte buffers, not `str`: a cpy `str` is already UTF-8, so passing
one through a legacy decoder would double-encode it.

## `str` conveniences

`text_bytes`, `bytes_to_text`, `text_is_valid`, `text_count`, `text_decode`,
`text_encode`, `text_repair`.

## Tests

```sh
cpy test_utf8.cpy          # prints "utf8: PASS"
cpy build test_utf8.cpy    # native AOT, same output
```
