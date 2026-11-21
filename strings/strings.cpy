# @std/strings — text utilities for cpyte.
#
# Shape of every builder here: cpy allocates the result with `new char[n + 1]`
# (so the runtime GC owns it) and a C helper fills it, NUL-terminated; the
# buffer is then handed back as a `str`. That keeps each operation a single
# pass instead of one reallocation per byte.
#
# Byte semantics: functions walk UTF-8 one byte at a time. Matching and
# comparison never split a multi-byte sequence, but case mapping and the
# `str_is_*` predicates are ASCII-only, as in C.

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <string.h>
    #include <strings.h>
    #include <ctype.h>

    int64_t cpy_slen(const char* s) {
        return s ? (int64_t)strlen(s) : (int64_t)0;
    }

    /* ── searching and comparing ─────────────────────────────── */

    int64_t cpy_str_find_at(const char* hay, const char* needle, int64_t start) {
        if (hay == NULL || needle == NULL || start < 0) return (int64_t)-1;
        size_t hl = strlen(hay);
        size_t nl = strlen(needle);
        if ((size_t)start > hl) return (int64_t)-1;
        if (nl == 0) return start;
        const char* p = strstr(hay + start, needle);
        return p ? (int64_t)(p - hay) : (int64_t)-1;
    }

    int64_t cpy_str_rfind(const char* hay, const char* needle) {
        if (hay == NULL || needle == NULL) return (int64_t)-1;
        size_t hl = strlen(hay), nl = strlen(needle);
        if (nl == 0) return (int64_t)hl;
        if (nl > hl) return (int64_t)-1;
        const char* last = NULL;
        for (const char* p = hay; p + nl <= hay + hl; p++) {
            if (memcmp(p, needle, nl) == 0) last = p;
        }
        return last ? (int64_t)(last - hay) : (int64_t)-1;
    }

    int64_t cpy_str_count(const char* hay, const char* needle) {
        if (hay == NULL || needle == NULL) return (int64_t)0;
        size_t nl = strlen(needle);
        if (nl == 0) return (int64_t)0;
        int64_t n = 0;
        const char* p = hay;
        for (;;) {
            p = strstr(p, needle);
            if (p == NULL) break;
            n++;
            p += nl;
        }
        return n;
    }

    int cpy_str_starts_with(const char* s, const char* pre) {
        if (s == NULL || pre == NULL) return 0;
        size_t pl = strlen(pre);
        return strlen(s) >= pl && memcmp(s, pre, pl) == 0;
    }

    int cpy_str_ends_with(const char* s, const char* suf) {
        if (s == NULL || suf == NULL) return 0;
        size_t sl = strlen(s), ul = strlen(suf);
        return sl >= ul && memcmp(s + sl - ul, suf, ul) == 0;
    }

    int cpy_str_cmp(const char* a, const char* b) {
        return strcmp(a ? a : "", b ? b : "");
    }

    int cpy_str_cmp_ci(const char* a, const char* b) {
        return strcasecmp(a ? a : "", b ? b : "");
    }

    /* 1 when s is non-empty and every byte is in `set`. */
    int cpy_str_all_in(const char* s, const char* set) {
        if (s == NULL || set == NULL || *s == '\0' || *set == '\0') return 0;
        size_t sl = strlen(s);
        for (size_t i = 0; i < sl; i++) {
            if (strchr(set, (int)(unsigned char)s[i]) == NULL) return 0;
        }
        return 1;
    }

    /* cls: 0 alpha, 1 digit, 2 alnum, 3 space, 4 upper, 5 lower, 6 punct,
       7 print, 8 xdigit. 1 when s is non-empty and every byte matches. */
    int cpy_str_class(const char* s, int cls) {
        if (s == NULL || *s == '\0') return 0;
        size_t sl = strlen(s);
        for (size_t i = 0; i < sl; i++) {
            int c = (int)(unsigned char)s[i];
            int ok = 0;
            switch (cls) {
                case 0: ok = isalpha(c); break;
                case 1: ok = isdigit(c); break;
                case 2: ok = isalnum(c); break;
                case 3: ok = isspace(c); break;
                case 4: ok = isupper(c); break;
                case 5: ok = islower(c); break;
                case 6: ok = ispunct(c); break;
                case 7: ok = isprint(c); break;
                default: ok = isxdigit(c); break;
            }
            if (!ok) return 0;
        }
        return 1;
    }

    /* ── bounds used by the trim family ──────────────────────── */

    static int in_set(const char* set, unsigned char c) {
        return set != NULL && *set != '\0' && strchr(set, (int)c) != NULL;
    }

    int64_t cpy_str_substring(const char* src, int64_t lo, int64_t hi, void* dst);

    /* First index whose byte is NOT in `set`, or strlen(s) when all match. */
    int64_t cpy_str_lstrip_at(const char* s, const char* set) {
        if (s == NULL) return (int64_t)0;
        size_t i = 0, sl = strlen(s);
        while (i < sl && in_set(set, (unsigned char)s[i])) i++;
        return (int64_t)i;
    }

    /* One past the last index whose byte is NOT in `set`. */
    int64_t cpy_str_rstrip_at(const char* s, const char* set) {
        if (s == NULL) return (int64_t)0;
        size_t sl = strlen(s), i = sl;
        while (i > 0 && in_set(set, (unsigned char)s[i - 1])) i--;
        return (int64_t)i;
    }

    int64_t cpy_str_trim_len(const char* s, const char* set, int mode) {
        int64_t lo = mode == 2 ? 0 : cpy_str_lstrip_at(s, set);
        int64_t hi = mode == 1 ? cpy_slen(s) : cpy_str_rstrip_at(s, set);
        return hi > lo ? hi - lo : (int64_t)0;
    }

    /* mode: 0 both ends, 1 left only, 2 right only. */
    int64_t cpy_str_trim(const char* s, const char* set, int mode, void* dst) {
        int64_t lo = mode == 2 ? 0 : cpy_str_lstrip_at(s, set);
        int64_t hi = mode == 1 ? cpy_slen(s) : cpy_str_rstrip_at(s, set);
        return cpy_str_substring(s, lo, hi, dst);
    }

    /* ── builders: each writes a NUL-terminated result into dst ─ */

    int64_t cpy_str_substring(const char* src, int64_t lo, int64_t hi, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (src == NULL || dst == NULL) { if (dst) d[0] = 0; return (int64_t)0; }
        int64_t n = cpy_slen(src);
        if (lo < 0) lo = 0;
        if (hi > n) hi = n;
        if (hi < lo) hi = lo;
        memcpy(d, src + lo, (size_t)(hi - lo));
        d[hi - lo] = 0;
        return hi - lo;
    }

    int64_t cpy_str_from_byte(int64_t byte, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        d[0] = (unsigned char)(byte & 0xFF);
        d[1] = 0;
        return (int64_t)1;
    }

    /* mode: 0 lower, 1 upper, 2 swap, 3 capitalize first, 4 title case. */
    int64_t cpy_str_case(const char* src, int mode, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (src == NULL || dst == NULL) { if (dst) d[0] = 0; return (int64_t)0; }
        int64_t i = 0, o = 0;
        int at_start = mode == 3 ? 0 : 1;
        while (src[i]) {
            int c = (int)(unsigned char)src[i];
            int upper_first = mode == 3 ? (i == 0) : (mode == 4 && at_start);
            int want;
            if (upper_first) want = 1;
            else if (mode == 0 || mode == 3 || mode == 4) want = 0;
            else if (mode == 1) want = 1;
            else want = -1;                       /* swap */
            if (want == 1 && c >= 'a' && c <= 'z') c -= 32;
            if (want == 0 && c >= 'A' && c <= 'Z') c += 32;
            if (want == -1) {
                if (c >= 'a' && c <= 'z') c -= 32;
                else if (c >= 'A' && c <= 'Z') c += 32;
            }
            d[o++] = (unsigned char)c;
            if (mode == 4)
                at_start = (c == ' ' || c == '\t' || c == '\n' || c == '\r');
            i++;
        }
        d[o] = 0;
        return o;
    }

    int64_t cpy_str_reverse(const char* src, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (src == NULL || dst == NULL) { if (dst) d[0] = 0; return (int64_t)0; }
        int64_t n = cpy_slen(src);
        for (int64_t i = 0; i < n; i++) d[i] = (unsigned char)src[n - 1 - i];
        d[n] = 0;
        return n;
    }

    int64_t cpy_str_repeat_len(const char* src, int64_t times) {
        if (src == NULL || times <= 0) return (int64_t)0;
        return cpy_slen(src) * times;
    }

    int64_t cpy_str_repeat(const char* src, int64_t times, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (src == NULL || dst == NULL || times <= 0) {
            if (dst) d[0] = 0;
            return (int64_t)0;
        }
        size_t sl = strlen(src);
        int64_t o = 0;
        for (int64_t i = 0; i < times; i++) {
            memcpy(d + o, src, sl);
            o += (int64_t)sl;
        }
        d[o] = 0;
        return o;
    }

    /* side: 0 left, 1 right, 2 center. */
    int64_t cpy_str_pad(const char* src, int64_t width, const char* pad,
                        int side, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (dst == NULL) return (int64_t)0;
        if (src == NULL) src = "";
        int64_t sl = cpy_slen(src);
        int64_t missing = width - sl;
        if (missing < 0) missing = 0;
        int64_t pl = (pad && *pad) ? cpy_slen(pad) : 0;
        if (pl == 0) missing = 0;
        int64_t left = 0, right = 0;
        if (side == 0) left = missing;
        else if (side == 1) right = missing;
        else { left = missing / 2; right = missing - left; }
        int64_t o = 0;
        for (int64_t i = 0; i < left; i++) d[o++] = (unsigned char)pad[i % pl];
        memcpy(d + o, src, (size_t)sl);
        o += sl;
        for (int64_t i = 0; i < right; i++) d[o++] = (unsigned char)pad[i % pl];
        d[o] = 0;
        return o;
    }

    static int64_t replace_occurrences(const char* src, const char* from,
                                       const char* to, int all) {
        if (src == NULL || from == NULL || *from == '\0') return (int64_t)-1;
        int64_t sl = cpy_slen(src), fl = cpy_slen(from);
        int64_t tl = to ? cpy_slen(to) : (int64_t)0;
        int64_t extra = tl - fl, n = 0;
        const char* p = src;
        for (;;) {
            p = strstr(p, from);
            if (p == NULL) break;
            n++;
            p += fl;
            if (!all && n >= 1) break;
        }
        if (n == 0) return sl;
        return sl + n * extra;
    }

    /* Byte length of `replace(src, from, to)`; -1 when `from` is empty.
       Returns 0 length for an exact match so callers can size the buffer. */
    int64_t cpy_str_replace_len(const char* src, const char* from,
                                const char* to, int all) {
        int64_t n = replace_occurrences(src, from, to, all);
        return n < 0 ? cpy_slen(src) : n;
    }

    int64_t cpy_str_replace(const char* src, const char* from, const char* to,
                            int all, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (dst == NULL) return (int64_t)0;
        if (src == NULL) src = "";
        int64_t sl = cpy_slen(src);
        if (from == NULL || *from == '\0') {
            memcpy(d, src, (size_t)sl);
            d[sl] = 0;
            return sl;
        }
        if (to == NULL) to = "";
        int64_t fl = cpy_slen(from), tl = cpy_slen(to);
        const char* p = src;
        int64_t o = 0;
        int done = 0;
        while (!done) {
            const char* at = strstr(p, from);
            if (at == NULL) break;
            int64_t chunk = (int64_t)(at - p);
            memcpy(d + o, p, (size_t)chunk);
            o += chunk;
            memcpy(d + o, to, (size_t)tl);
            o += tl;
            p = at + fl;
            if (!all) done = 1;
        }
        int64_t tail = sl - (int64_t)(p - src);
        memcpy(d + o, p, (size_t)tail);
        o += tail;
        d[o] = 0;
        return o;
    }

    int64_t cpy_str_split_count(const char* s, const char* sep) {
        if (s == NULL || *s == '\0') return (int64_t)0;
        if (sep == NULL || *sep == '\0') return (int64_t)1;
        return cpy_str_count(s, sep) + 1;
    }

    static int64_t join_length(void* parts, int64_t count, const char* sep) {
        const char** p = (const char**)parts;
        int64_t total = 0;
        int64_t sl = sep ? (int64_t)strlen(sep) : (int64_t)0;
        for (int64_t i = 0; i < count; i++) {
            if (i > 0) total += sl;
            if (p != NULL && p[i] != NULL) total += (int64_t)strlen(p[i]);
        }
        return total;
    }

    int64_t cpy_str_join_len(void* parts, int64_t count, const char* sep) {
        return join_length(parts, count, sep);
    }

    int64_t cpy_str_join(void* parts, int64_t count, const char* sep, void* dst) {
        const char** p = (const char**)parts;
        unsigned char* d = (unsigned char*)dst;
        if (dst == NULL) return (int64_t)0;
        int64_t o = 0;
        int64_t sl = sep ? (int64_t)strlen(sep) : (int64_t)0;
        for (int64_t i = 0; i < count; i++) {
            if (i > 0 && sl > 0) { memcpy(d + o, sep, (size_t)sl); o += sl; }
            if (p != NULL && p[i] != NULL) {
                int64_t l = (int64_t)strlen(p[i]);
                memcpy(d + o, p[i], (size_t)l);
                o += l;
            }
        }
        d[o] = 0;
        return o;
    }

# ── length and indexing ─────────────────────────────────────────

public def str_byte_length(s str) -> int:
    return (int)cpy_slen(s)

public def str_byte_at(s str, index int) -> int:
    if index < 0 or (int64)index >= cpy_slen(s):
        return -1
    return ((int)s[index]) & 255

public def str_from_byte(byte int) -> str:
    char[] buf = new char[2]
    cpy_str_from_byte((int64)byte, (void*)buf)
    return (str)buf

# ── searching ───────────────────────────────────────────────────

public def str_find(s str, needle str) -> int:
    int64 at = (int64)0
    return (int)cpy_str_find_at(s, needle, at)

public def str_find_from(s str, needle str, start int) -> int:
    int64 at = (int64)start
    return (int)cpy_str_find_at(s, needle, at)

public def str_rfind(s str, needle str) -> int:
    return (int)cpy_str_rfind(s, needle)

public def str_contains(s str, needle str) -> bool:
    return str_find(s, needle) >= 0

public def str_count(s str, needle str) -> int:
    return (int)cpy_str_count(s, needle)

# ── comparison ──────────────────────────────────────────────────

public def str_starts_with(s str, prefix str) -> bool:
    return cpy_str_starts_with(s, prefix) == 1

public def str_ends_with(s str, suffix str) -> bool:
    return cpy_str_ends_with(s, suffix) == 1

public def str_equals(a str, b str) -> bool:
    return cpy_str_cmp(a, b) == 0

public def str_equals_ci(a str, b str) -> bool:
    return cpy_str_cmp_ci(a, b) == 0

public def str_compare(a str, b str) -> int:
    return cpy_str_cmp(a, b)

public def str_compare_ci(a str, b str) -> int:
    return cpy_str_cmp_ci(a, b)

# ── classification ──────────────────────────────────────────────

public def str_is_empty(s str) -> bool:
    return cpy_slen(s) == (int64)0

public def str_is_alpha(s str) -> bool:
    return cpy_str_class(s, 0) == 1

public def str_is_digit(s str) -> bool:
    return cpy_str_class(s, 1) == 1

public def str_is_alnum(s str) -> bool:
    return cpy_str_class(s, 2) == 1

public def str_is_space(s str) -> bool:
    return cpy_str_class(s, 3) == 1

public def str_is_upper(s str) -> bool:
    return cpy_str_class(s, 4) == 1

public def str_is_lower(s str) -> bool:
    return cpy_str_class(s, 5) == 1

public def str_is_punct(s str) -> bool:
    return cpy_str_class(s, 6) == 1

public def str_is_print(s str) -> bool:
    return cpy_str_class(s, 7) == 1

public def str_is_hex(s str) -> bool:
    return cpy_str_class(s, 8) == 1

public def str_is_all_of(s str, chars str) -> bool:
    return cpy_str_all_in(s, chars) == 1

# ── slicing ─────────────────────────────────────────────────────

# Bytes [start, end); out-of-range bounds are clamped, so this never fails.
public def str_substring(s str, start int, end int) -> str:
    int64 lo = (int64)start
    int64 hi = (int64)end
    int64 n = cpy_slen(s)
    if lo < (int64)0:
        lo = (int64)0
    if lo > n:
        lo = n
    if hi < lo:
        hi = lo
    if hi > n:
        hi = n
    # Parenthesized: chained `-`/`+` is right-associative in cpyte 4.6.9.
    char[] buf = new char[(hi - lo) + (int64)1]
    cpy_str_substring(s, lo, hi, (void*)buf)
    return (str)buf

public def str_slice_from(s str, start int) -> str:
    return str_substring(s, start, (int)cpy_slen(s))

public def str_slice_to(s str, end int) -> str:
    return str_substring(s, 0, end)

# ── case mapping (ASCII) ────────────────────────────────────────

def case_of(s str, mode int) -> str:
    int64 n = cpy_slen(s)
    char[] buf = new char[n + (int64)1]
    cpy_str_case(s, mode, (void*)buf)
    return (str)buf

public def str_lower(s str) -> str:
    return case_of(s, 0)

public def str_upper(s str) -> str:
    return case_of(s, 1)

public def str_swapcase(s str) -> str:
    return case_of(s, 2)

public def str_capitalize(s str) -> str:
    return case_of(s, 3)

public def str_title(s str) -> str:
    return case_of(s, 4)

# ── trimming and padding ────────────────────────────────────────

def trim_to(s str, chars str, mode int) -> str:
    int64 n = cpy_str_trim_len(s, chars, mode)
    char[] buf = new char[n + (int64)1]
    cpy_str_trim(s, chars, mode, (void*)buf)
    return (str)buf

public def str_trim(s str) -> str:
    return trim_to(s, " \t\n\v\f\r", 0)

public def str_trim_left(s str) -> str:
    return trim_to(s, " \t\n\v\f\r", 1)

public def str_trim_right(s str) -> str:
    return trim_to(s, " \t\n\v\f\r", 2)

public def str_strip_chars(s str, chars str) -> str:
    return trim_to(s, chars, 0)

def pad_to(s str, width int, pad str, side int) -> str:
    int64 target = (int64)width
    int64 n = cpy_slen(s)
    if target < n:
        target = n
    char[] buf = new char[target + (int64)1]
    cpy_str_pad(s, target, pad, side, (void*)buf)
    return (str)buf

public def str_pad_left(s str, width int, pad str) -> str:
    return pad_to(s, width, pad, 0)

public def str_pad_right(s str, width int, pad str) -> str:
    return pad_to(s, width, pad, 1)

public def str_pad_center(s str, width int, pad str) -> str:
    return pad_to(s, width, pad, 2)

public def str_repeat(s str, times int) -> str:
    int64 n = cpy_str_repeat_len(s, (int64)times)
    char[] buf = new char[n + (int64)1]
    cpy_str_repeat(s, (int64)times, (void*)buf)
    return (str)buf

# ── replacing ───────────────────────────────────────────────────

def replace_in(s str, from str, to str, every int) -> str:
    int64 n = cpy_str_replace_len(s, from, to, every)
    char[] buf = new char[n + (int64)1]
    cpy_str_replace(s, from, to, every, (void*)buf)
    return (str)buf

public def str_replace(s str, from str, to str) -> str:
    return replace_in(s, from, to, 1)

public def str_replace_first(s str, from str, to str) -> str:
    return replace_in(s, from, to, 0)

# ── splitting and joining ───────────────────────────────────────

# A `str[]` grown with `append`; the separator is never kept in a part, and
# splitting the empty string yields no parts at all. Named `str_split_parts`
# because `str_split` is a cpy builtin that returns a `dynamic[]`.
public def str_split_parts(s str, sep str) -> str[]:
    str[] parts = new str[0]
    if cpy_slen(s) == (int64)0:
        return parts
    if cpy_slen(sep) == (int64)0:
        append(parts, s)
        return parts
    int n = (int)cpy_slen(s)
    int sep_len = (int)cpy_slen(sep)
    int start = 0
    int at = str_find_from(s, sep, start)
    while at >= 0:
        append(parts, str_substring(s, start, at))
        start = at + sep_len
        at = str_find_from(s, sep, start)
    append(parts, str_substring(s, start, n))
    return parts

public def str_join(parts str[], sep str) -> str:
    int64 count = len(parts)
    int64 n = cpy_str_join_len((void*)parts, count, sep)
    char[] buf = new char[n + (int64)1]
    cpy_str_join((void*)parts, count, sep, (void*)buf)
    return (str)buf

# ── misc ────────────────────────────────────────────────────────

public def str_reverse(s str) -> str:
    int64 n = cpy_slen(s)
    char[] buf = new char[n + (int64)1]
    cpy_str_reverse(s, (void*)buf)
    return (str)buf

# Kept after `str_replace` because it is built on top of it.
public def str_split_lines(s str) -> str[]:
    return str_split_parts(str_replace(s, "\r\n", "\n"), "\n")
