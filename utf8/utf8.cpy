# @std/utf8 — strict UTF-8 validation, codepoint charmaps, charset conversion.
#
# API shape (same as @std/encoding): byte buffers are `char[]` values whose
# `len()` is the exact byte count, so embedded NULs and truncated sequences
# survive intact. Codepoint buffers are `int[]` (one i32 per Unicode scalar
# value). Every result is a freshly GC-allocated array; failure is signalled by
# an empty array or a negative integer, never by a partially decoded value.
#
# Validation follows Unicode 15 Table 3-7: overlong forms, UTF-16 surrogates
# and scalars above U+10FFFF are rejected. Lossy helpers replace each invalid
# *maximal subpart* (Unicode Standard §3.9.6, definition D93b — an
# interoperability recommendation, not a conformance requirement) with U+FFFD.
#
# Pointer/buffer contract for the C helpers: a length of 0 permits a NULL
# pointer; a positive length requires a readable (or writable) buffer with at
# least that many bytes/elements. A NULL output pointer is allowed only for
# length-query calls. `decode_at` needs a two-element int32 output buffer.
# UTF-16 input must have an even byte length, UTF-32 input a length divisible
# by four; byte order is selected explicitly and BOMs are not consumed.

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <string.h>

    /* ── decoder core ─────────────────────────────────────────────── */

    static int u8_is_cont(unsigned char b) { return (b & 0xC0) == 0x80; }

    static int u8_lead_len(unsigned char b) {
        if (b <= 0x7F) return 1;
        if (b >= 0xC2 && b <= 0xDF) return 2;
        if (b >= 0xE0 && b <= 0xEF) return 3;
        if (b >= 0xF0 && b <= 0xF4) return 4;
        return 0;                       /* C0/C1, F5..FF, stray continuation */
    }

    /* Restricted ranges for the second byte (Unicode Table 3-7). */
    static unsigned char u8_second_lo(unsigned char b0) {
        if (b0 == 0xE0) return 0xA0;    /* no overlong 3-byte forms */
        if (b0 == 0xF0) return 0x90;    /* no overlong 4-byte forms */
        return 0x80;
    }
    static unsigned char u8_second_hi(unsigned char b0) {
        if (b0 == 0xED) return 0x9F;    /* no UTF-16 surrogates */
        if (b0 == 0xF4) return 0x8F;    /* no scalars above U+10FFFF */
        return 0xBF;
    }

    /* Decode one scalar at i. Returns bytes consumed (> 0), or a negative
       error: -1 bad lead/continuation, -2 truncated, -3 overlong,
       -4 surrogate, -5 above U+10FFFF. Bytes that ARE present are validated
       before a missing byte is reported as truncation, so E2 28 is a bad
       continuation and E0 80 is overlong rather than "truncated". */
    static int u8_decode_one(const unsigned char* s, int64_t n, int64_t i, int32_t* cp) {
        if (i < 0 || i >= n) return -2;
        unsigned char b0 = s[i];
        int len = u8_lead_len(b0);
        if (len == 0) return -1;
        if (len == 1) { *cp = (int32_t)b0; return 1; }

        if (i + 1 >= n) return -2;      /* no second byte at all */
        unsigned char b1 = s[i + 1];
        if (!u8_is_cont(b1)) return -1;
        if (b1 < u8_second_lo(b0) || b1 > u8_second_hi(b0)) {
            if (b0 == 0xE0 || b0 == 0xF0) return -3;
            if (b0 == 0xED) return -4;
            return -5;                  /* b0 == 0xF4 */
        }
        if (len == 2) {
            *cp = (int32_t)(((uint32_t)(b0 & 0x1F) << 6) | (uint32_t)(b1 & 0x3F));
            return 2;
        }

        if (i + 2 >= n) return -2;      /* no third byte at all */
        unsigned char b2 = s[i + 2];
        if (!u8_is_cont(b2)) return -1;
        if (len == 3) {
            *cp = (int32_t)(((uint32_t)(b0 & 0x0F) << 12) |
                            ((uint32_t)(b1 & 0x3F) << 6) |
                            (uint32_t)(b2 & 0x3F));
            return 3;
        }

        if (i + 3 >= n) return -2;      /* no fourth byte at all */
        unsigned char b3 = s[i + 3];
        if (!u8_is_cont(b3)) return -1;
        *cp = (int32_t)(((uint32_t)(b0 & 0x07) << 18) |
                        ((uint32_t)(b1 & 0x3F) << 12) |
                        ((uint32_t)(b2 & 0x3F) << 6) |
                        (uint32_t)(b3 & 0x3F));
        return 4;
    }

    /* Length of the maximal invalid subsequence at i: lead plus as many
       bytes as are still a valid prefix of that lead's sequence. */
    static int64_t u8_bad_run(const unsigned char* s, int64_t n, int64_t i) {
        int len = u8_lead_len(s[i]);
        if (len <= 1) return 1;
        int64_t j = i + 1;
        int64_t limit = i + len;
        while (j < n && j < limit) {
            unsigned char b = s[j];
            unsigned char lo = (j == i + 1) ? u8_second_lo(s[i]) : 0x80;
            unsigned char hi = (j == i + 1) ? u8_second_hi(s[i]) : 0xBF;
            if (b < lo || b > hi) break;
            j++;
        }
        return j - i;
    }

    /* Encode one scalar. Returns 0 for surrogates and out-of-range values. */
    static int u8_encode_one(int32_t cp, unsigned char* out) {
        if (cp < 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) return 0;
        if (cp <= 0x7F) {
            if (out) out[0] = (unsigned char)cp;
            return 1;
        }
        if (cp <= 0x7FF) {
            if (out) { out[0] = (unsigned char)(0xC0 | (cp >> 6));
                       out[1] = (unsigned char)(0x80 | (cp & 0x3F)); }
            return 2;
        }
        if (cp <= 0xFFFF) {
            if (out) { out[0] = (unsigned char)(0xE0 | (cp >> 12));
                       out[1] = (unsigned char)(0x80 | ((cp >> 6) & 0x3F));
                       out[2] = (unsigned char)(0x80 | (cp & 0x3F)); }
            return 3;
        }
        if (out) { out[0] = (unsigned char)(0xF0 | (cp >> 18));
                   out[1] = (unsigned char)(0x80 | ((cp >> 12) & 0x3F));
                   out[2] = (unsigned char)(0x80 | ((cp >> 6) & 0x3F));
                   out[3] = (unsigned char)(0x80 | (cp & 0x3F)); }
        return 4;
    }

    /* ── byte/text plumbing ───────────────────────────────────────── */

    int64_t cpy_u8_strlen(const char* s) {
        return s ? (int64_t)strlen(s) : (int64_t)0;
    }

    int64_t cpy_u8_copy_bytes(const void* src, int64_t n, void* dst) {
        if (src == NULL || dst == NULL || n <= 0) return (int64_t)0;
        memcpy(dst, src, (size_t)n);
        return n;
    }

    int64_t cpy_u8_text(const void* src, int64_t n, void* dst) {
        unsigned char* d = (unsigned char*)dst;
        if (d == NULL) return (int64_t)0;
        if (src != NULL && n > 0) memcpy(d, src, (size_t)n);
        d[n > 0 ? n : 0] = 0;
        return n > 0 ? n : (int64_t)0;
    }

    /* ── validation and navigation ────────────────────────────────── */

    int64_t cpy_u8_first_error(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)0;
        while (i < n) {
            int32_t cp = 0;
            int k = u8_decode_one(s, n, i, &cp);
            if (k <= 0) return i;
            i += k;
        }
        return (int64_t)-1;             /* valid */
    }

    int cpy_u8_error_code(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0;
        if (n < 0 || (n > 0 && s == NULL)) return 1;
        while (i < n) {
            int32_t cp = 0;
            int k = u8_decode_one(s, n, i, &cp);
            if (k <= 0) return -k;      /* 1..5 */
            i += k;
        }
        return 0;
    }

    int64_t cpy_u8_count(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, count = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int k = u8_decode_one(s, n, i, &cp);
            if (k <= 0) return (int64_t)-1;
            count++;
            i += k;
        }
        return count;
    }

    int64_t cpy_u8_valid_prefix(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0;
        if (n <= 0 || s == NULL) return (int64_t)0;
        while (i < n) {
            int32_t cp = 0;
            int k = u8_decode_one(s, n, i, &cp);
            if (k <= 0) return i;
            i += k;
        }
        return n;
    }

    int64_t cpy_u8_cp_at(const void* src, int64_t n, int64_t index) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, k = 0;
        if (index < 0 || n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) return (int64_t)-1;
            if (k == index) return (int64_t)cp;
            k++;
            i += used;
        }
        return (int64_t)-1;
    }

    /* Byte offset of codepoint `index`; returns n for index == count. */
    int64_t cpy_u8_byte_at(const void* src, int64_t n, int64_t index) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, k = 0;
        if (index < 0 || n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            if (k == index) return i;
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) return (int64_t)-1;
            k++;
            i += used;
        }
        return (k == index) ? n : (int64_t)-1;
    }

    /* Strict decode-at: writes out[0] = scalar and out[1] = byte width on
       success (returns 1). Failures return 0 and zero both elements when the
       capacity is sufficient. The output pointer must hold at least two int32
       elements; a smaller capacity is rejected before any write. */
    int cpy_u8_decode_at(const void* src, int64_t n, int64_t i,
                         int32_t* out, int64_t out_cap) {
        const unsigned char* s = (const unsigned char*)src;
        int32_t cp = 0;
        int used;
        if (out == NULL || out_cap < 2) return 0;
        out[0] = 0;
        out[1] = 0;
        if (i < 0 || i >= n || n < 0 || s == NULL) return 0;
        used = u8_decode_one(s, n, i, &cp);
        if (used <= 0) return 0;
        out[0] = cp;
        out[1] = (int32_t)used;
        return 1;
    }

    int64_t cpy_u8_cp_bytes(int32_t cp) { return (int64_t)u8_encode_one(cp, NULL); }

    int64_t cpy_u8_encode_cp(int32_t cp, void* dst) {
        return (int64_t)u8_encode_one(cp, (unsigned char*)dst);
    }

    /* ── charmaps: UTF-8 <-> codepoint arrays ─────────────────────── */

    int64_t cpy_u8_decode(const void* src, int64_t n, int32_t* out) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, k = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) return (int64_t)-1;
            if (out != NULL) out[k] = cp;
            k++;
            i += used;
        }
        return k;
    }

    int64_t cpy_u8_lossy_count(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, k = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) { k++; i += u8_bad_run(s, n, i); }
            else { k++; i += used; }
        }
        return k;
    }

    int64_t cpy_u8_decode_lossy(const void* src, int64_t n, int32_t* out) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, k = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) {
                if (out != NULL) out[k] = 0xFFFD;
                i += u8_bad_run(s, n, i);
            } else {
                if (out != NULL) out[k] = cp;
                i += used;
            }
            k++;
        }
        return k;
    }

    /* len/emit for codepoints: lossy=1 replaces invalid scalars with U+FFFD. */
    int64_t cpy_u8_encode_len(const int32_t* cps, int64_t n, int lossy) {
        int64_t total = 0;
        if (n < 0 || (n > 0 && cps == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) {
            int k = u8_encode_one(cps[i], NULL);
            if (k == 0) {
                if (!lossy) return (int64_t)-1;
                total += 3;
            } else total += k;
        }
        return total;
    }

    int64_t cpy_u8_encode(const int32_t* cps, int64_t n, void* dst, int lossy) {
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        if (n < 0 || (n > 0 && cps == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) {
            int32_t cp = cps[i];
            int k = u8_encode_one(cp, out ? out + o : NULL);
            if (k == 0) {
                if (!lossy) return (int64_t)-1;
                k = u8_encode_one(0xFFFD, out ? out + o : NULL);
            }
            o += k;
        }
        return o;
    }

    int64_t cpy_u8_repair_len(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t i = 0, total = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) { total += 3; i += u8_bad_run(s, n, i); }
            else { total += used; i += used; }
        }
        return total;
    }

    int64_t cpy_u8_repair(const void* src, int64_t n, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t i = 0, o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) {
                if (out != NULL) { out[o] = 0xEF; out[o + 1] = 0xBF; out[o + 2] = 0xBD; }
                o += 3;
                i += u8_bad_run(s, n, i);
            } else {
                if (out != NULL) memcpy(out + o, s + i, (size_t)used);
                o += used;
                i += used;
            }
        }
        return o;
    }

    /* ── charmaps: legacy single-byte encodings ───────────────────── */

    int64_t cpy_u8_latin1_len(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t total = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) total += (s[i] < 0x80) ? 1 : 2;
        return total;
    }

    int64_t cpy_u8_latin1_to_utf8(const void* src, int64_t n, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) {
            o += u8_encode_one((int32_t)s[i], out ? out + o : NULL);
        }
        return o;
    }

    int64_t cpy_u8_utf8_to_latin1(const void* src, int64_t n, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t i = 0, o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0 || cp > 0xFF) return (int64_t)-1;
            if (out != NULL) out[o] = (unsigned char)cp;
            o++;
            i += used;
        }
        return o;
    }

    /* Windows-1252 0x80..0x9F; -1 means "undefined in this charset". */
    static const int32_t u8_cp1252_high[32] = {
        0x20AC, -1,     0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, -1,     0x017D, -1,
        -1,     0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, -1,     0x017E, 0x0178
    };

    static int32_t u8_cp1252_cp(unsigned char b) {
        if (b < 0x80) return (int32_t)b;
        if (b < 0xA0) return u8_cp1252_high[b - 0x80];  /* only 0x80..0x9F differ */
        return (int32_t)b;                             /* 0xA0..0xFF = Latin-1 */
    }

    int64_t cpy_u8_cp1252_len(const void* src, int64_t n) {
        const unsigned char* s = (const unsigned char*)src;
        int64_t total = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) {
            int32_t cp = u8_cp1252_cp(s[i]);
            if (cp < 0) return (int64_t)-1;
            total += u8_encode_one(cp, NULL);
        }
        return total;
    }

    int64_t cpy_u8_cp1252_to_utf8(const void* src, int64_t n, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        for (int64_t i = 0; i < n; i++) {
            int32_t cp = u8_cp1252_cp(s[i]);
            if (cp < 0) return (int64_t)-1;
            o += u8_encode_one(cp, out ? out + o : NULL);
        }
        return o;
    }

    int64_t cpy_u8_utf8_to_cp1252(const void* src, int64_t n, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t i = 0, o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            unsigned char b = 0;
            if (used <= 0) return (int64_t)-1;
            if (cp < 0x80 || (cp >= 0xA0 && cp <= 0xFF)) {
                b = (unsigned char)cp;                 /* CP1252 = Latin-1 here */
            } else {
                int found = 0;
                for (int j = 0; j < 32; j++) {
                    if (u8_cp1252_high[j] == cp) { b = (unsigned char)(0x80 + j); found = 1; break; }
                }
                if (!found) return (int64_t)-1;
            }
            if (out != NULL) out[o] = b;
            o++;
            i += used;
        }
        return o;
    }

    /* ── charmaps: UTF-16 / UTF-32 ────────────────────────────────── */

    static uint16_t u8_rd16(const unsigned char* p, int be) {
        return be ? (uint16_t)((uint16_t)(p[0] << 8) | p[1])
                  : (uint16_t)((uint16_t)p[0] | (uint16_t)(p[1] << 8));
    }
    static void u8_wr16(unsigned char* p, uint16_t v, int be) {
        if (be) { p[0] = (unsigned char)(v >> 8); p[1] = (unsigned char)(v & 0xFF); }
        else { p[0] = (unsigned char)(v & 0xFF); p[1] = (unsigned char)(v >> 8); }
    }
    static uint32_t u8_rd32(const unsigned char* p, int be) {
        if (be) return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
                       ((uint32_t)p[2] << 8) | (uint32_t)p[3];
        return ((uint32_t)p[3] << 24) | ((uint32_t)p[2] << 16) |
               ((uint32_t)p[1] << 8) | (uint32_t)p[0];
    }
    static void u8_wr32(unsigned char* p, uint32_t v, int be) {
        if (be) { p[0] = (unsigned char)(v >> 24); p[1] = (unsigned char)(v >> 16);
                  p[2] = (unsigned char)(v >> 8); p[3] = (unsigned char)v; }
        else { p[3] = (unsigned char)(v >> 24); p[2] = (unsigned char)(v >> 16);
               p[1] = (unsigned char)(v >> 8); p[0] = (unsigned char)v; }
    }

    /* Walk UTF-16 units; emit is NULL for a length-only query. */
    static int64_t u8_utf16_walk(const unsigned char* s, int64_t n, int be, unsigned char* out) {
        int64_t units, i = 0, o = 0;
        if (n < 0 || (n & 1) || (n > 0 && s == NULL)) return (int64_t)-1;
        units = n / 2;
        while (i < units) {
            uint16_t u = u8_rd16(s + 2 * (size_t)i, be);
            int32_t cp;
            if (u >= 0xD800 && u <= 0xDBFF) {
                uint16_t v;
                if (i + 1 >= units) return (int64_t)-1;
                v = u8_rd16(s + 2 * (size_t)(i + 1), be);
                if (v < 0xDC00 || v > 0xDFFF) return (int64_t)-1;
                cp = 0x10000 + (int32_t)(((uint32_t)(u - 0xD800) << 10) |
                                          (uint32_t)(v - 0xDC00));
                i += 2;
            } else if (u >= 0xDC00 && u <= 0xDFFF) {
                return (int64_t)-1;     /* orphan low surrogate */
            } else { cp = (int32_t)u; i++; }
            o += u8_encode_one(cp, out ? out + o : NULL);
        }
        return o;
    }

    int64_t cpy_u8_utf16_len(const void* src, int64_t n, int be) {
        return u8_utf16_walk((const unsigned char*)src, n, be, NULL);
    }
    int64_t cpy_u8_utf16_to_utf8(const void* src, int64_t n, int be, void* dst) {
        return u8_utf16_walk((const unsigned char*)src, n, be, (unsigned char*)dst);
    }

    /* Walk UTF-8 and emit UTF-16 units; emits 2 bytes per unit. */
    static int64_t u8_utf8_to_utf16_walk(const unsigned char* s, int64_t n, int be, unsigned char* out) {
        int64_t i = 0, o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) return (int64_t)-1;
            if (cp <= 0xFFFF) {
                if (out) u8_wr16(out + o, (uint16_t)cp, be);
                o += 2;
            } else {
                uint32_t v = (uint32_t)(cp - 0x10000);
                uint16_t hi = (uint16_t)(0xD800 + (v >> 10));
                uint16_t lo = (uint16_t)(0xDC00 + (v & 0x3FF));
                if (out) { u8_wr16(out + o, hi, be); u8_wr16(out + o + 2, lo, be); }
                o += 4;
            }
            i += used;
        }
        return o;
    }

    int64_t cpy_u8_utf8_to_utf16_len(const void* src, int64_t n) {
        return u8_utf8_to_utf16_walk((const unsigned char*)src, n, 0, NULL);
    }
    int64_t cpy_u8_utf8_to_utf16(const void* src, int64_t n, int be, void* dst) {
        return u8_utf8_to_utf16_walk((const unsigned char*)src, n, be, (unsigned char*)dst);
    }

    static int64_t u8_utf32_walk(const unsigned char* s, int64_t n, int be, unsigned char* out) {
        int64_t i = 0, o = 0;
        if (n < 0 || (n & 3) || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            uint32_t v = u8_rd32(s + (size_t)i, be);
            int k;
            if (v > 0x10FFFF || (v >= 0xD800 && v <= 0xDFFF)) return (int64_t)-1;
            k = u8_encode_one((int32_t)v, out ? out + o : NULL);
            o += k;
            i += 4;
        }
        return o;
    }

    int64_t cpy_u8_utf32_len(const void* src, int64_t n, int be) {
        return u8_utf32_walk((const unsigned char*)src, n, be, NULL);
    }
    int64_t cpy_u8_utf32_to_utf8(const void* src, int64_t n, int be, void* dst) {
        return u8_utf32_walk((const unsigned char*)src, n, be, (unsigned char*)dst);
    }

    int64_t cpy_u8_utf8_to_utf32_len(const void* src, int64_t n) {
        int64_t count = cpy_u8_count(src, n);
        if (count < 0) return (int64_t)-1;
        if (count > INT64_MAX / 4) return (int64_t)-1;  /* overflow guard */
        return count * 4;
    }
    int64_t cpy_u8_utf8_to_utf32(const void* src, int64_t n, int be, void* dst) {
        const unsigned char* s = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t i = 0, o = 0;
        if (n < 0 || (n > 0 && s == NULL)) return (int64_t)-1;
        while (i < n) {
            int32_t cp = 0;
            int used = u8_decode_one(s, n, i, &cp);
            if (used <= 0) return (int64_t)-1;
            if (out != NULL) u8_wr32(out + o, (uint32_t)cp, be);
            o += 4;
            i += used;
        }
        return o;
    }

# ── byte/text helpers ────────────────────────────────────────────

# NUL-terminate a byte buffer so it can be printed as a `str`.
public def bytes_to_text(data char[]) -> str:
    int64 n = len(data)
    char[] buf = new char[n + (int64)1]
    cpy_u8_text((void*)data, n, (void*)buf)
    return (str)buf

public def text_bytes(s str) -> char[]:
    int64 n = cpy_u8_strlen(s)
    char[] out = new char[n]
    cpy_u8_copy_bytes((void*)s, n, (void*)out)
    return out

# ── validation ───────────────────────────────────────────────────

public def is_valid(data char[]) -> bool:
    return cpy_u8_first_error((void*)data, len(data)) < (int64)0

# -1 when valid, otherwise the 0-based byte index of the first bad byte.
public def first_error(data char[]) -> int64:
    return cpy_u8_first_error((void*)data, len(data))

# 0=valid, 1=bad lead/continuation, 2=truncated, 3=overlong,
# 4=surrogate, 5=above U+10FFFF.
public def error_code(data char[]) -> int:
    return cpy_u8_error_code((void*)data, len(data))

# Number of Unicode scalar values, or -1 if the input is malformed.
public def count_codepoints(data char[]) -> int64:
    return cpy_u8_count((void*)data, len(data))

# Byte length of the longest well-formed prefix.
public def valid_prefix(data char[]) -> int64:
    return cpy_u8_valid_prefix((void*)data, len(data))

public def is_scalar(cp int) -> bool:
    return cpy_u8_cp_bytes(cp) > (int64)0

# UTF-8 byte width of a scalar (1..4), 0 for invalid scalars.
public def cp_bytes(cp int) -> int:
    return (int)cpy_u8_cp_bytes(cp)

# ── codepoint charmaps ───────────────────────────────────────────

# Strict: an empty array on any malformed sequence.
public def decode(data char[]) -> int[]:
    int64 n = cpy_u8_count((void*)data, len(data))
    if n < (int64)0:
        return new int[(int64)0]
    int[] out = new int[n]
    cpy_u8_decode((void*)data, len(data), (int*)out)
    return out

# Lenient: one U+FFFD per maximal invalid subsequence.
public def decode_lossy(data char[]) -> int[]:
    int64 n = cpy_u8_lossy_count((void*)data, len(data))
    if n < (int64)0:
        return new int[(int64)0]
    int[] out = new int[n]
    cpy_u8_decode_lossy((void*)data, len(data), (int*)out)
    return out

# Strict: an empty array if any value is not a Unicode scalar.
public def encode(cps int[]) -> char[]:
    int64 n = cpy_u8_encode_len((int*)cps, len(cps), 0)
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_encode((int*)cps, len(cps), (void*)out, 0)
    return out

# Lenient: invalid values become U+FFFD.
public def encode_lossy(cps int[]) -> char[]:
    int64 n = cpy_u8_encode_len((int*)cps, len(cps), 1)
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_encode((int*)cps, len(cps), (void*)out, 1)
    return out

# One scalar encoded by itself; empty for an invalid value.
public def encode_cp(cp int) -> char[]:
    int64 n = cpy_u8_cp_bytes(cp)
    if n == (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_encode_cp(cp, (void*)out)
    return out

# Scalar value at a codepoint index (-1 on error/out of range; U+0000 is 0).
public def codepoint_at(data char[], index int64) -> int:
    return (int)cpy_u8_cp_at((void*)data, len(data), index)

# Byte offset of a codepoint index; n for index == count, -1 on error.
public def byte_at(data char[], index int64) -> int64:
    return cpy_u8_byte_at((void*)data, len(data), index)

# Strict decode of one sequence at a byte position. `out` must hold at least
# two elements: on success out[0] is the scalar and out[1] its byte width.
# Too-small buffers return false without writing; malformed sequences return
# false and zero both elements.
public def decode_at(data char[], pos int64, out int[]) -> bool:
    return cpy_u8_decode_at((void*)data, len(data), pos, (int*)out, len(out)) != 0

# Replace invalid subsequences with U+FFFD while copying valid bytes verbatim.
public def repair(data char[]) -> char[]:
    int64 n = cpy_u8_repair_len((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_repair((void*)data, len(data), (void*)out)
    return out

# ── legacy charmaps ──────────────────────────────────────────────

public def latin1_to_utf8(data char[]) -> char[]:
    int64 n = cpy_u8_latin1_len((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_latin1_to_utf8((void*)data, len(data), (void*)out)
    return out

public def utf8_to_latin1(data char[]) -> char[]:
    int64 n = cpy_u8_count((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    int64 written = cpy_u8_utf8_to_latin1((void*)data, len(data), (void*)out)
    if written < (int64)0:
        return new char[(int64)0]
    return out

public def cp1252_to_utf8(data char[]) -> char[]:
    int64 n = cpy_u8_cp1252_len((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_cp1252_to_utf8((void*)data, len(data), (void*)out)
    return out

public def utf8_to_cp1252(data char[]) -> char[]:
    int64 n = cpy_u8_count((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    int64 written = cpy_u8_utf8_to_cp1252((void*)data, len(data), (void*)out)
    if written < (int64)0:
        return new char[(int64)0]
    return out

public def utf16_to_utf8(data char[], big_endian bool) -> char[]:
    int be = big_endian ? 1 : 0
    int64 n = cpy_u8_utf16_len((void*)data, len(data), be)
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_utf16_to_utf8((void*)data, len(data), be, (void*)out)
    return out

public def utf8_to_utf16(data char[], big_endian bool) -> char[]:
    int64 n = cpy_u8_utf8_to_utf16_len((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    int be = big_endian ? 1 : 0
    cpy_u8_utf8_to_utf16((void*)data, len(data), be, (void*)out)
    return out

public def utf32_to_utf8(data char[], big_endian bool) -> char[]:
    int be = big_endian ? 1 : 0
    int64 n = cpy_u8_utf32_len((void*)data, len(data), be)
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    cpy_u8_utf32_to_utf8((void*)data, len(data), be, (void*)out)
    return out

public def utf8_to_utf32(data char[], big_endian bool) -> char[]:
    int64 n = cpy_u8_utf8_to_utf32_len((void*)data, len(data))
    if n < (int64)0:
        return new char[(int64)0]
    char[] out = new char[n]
    int be = big_endian ? 1 : 0
    cpy_u8_utf8_to_utf32((void*)data, len(data), be, (void*)out)
    return out

# ── str conveniences ─────────────────────────────────────────────

public def text_is_valid(s str) -> bool:
    return is_valid(text_bytes(s))

public def text_count(s str) -> int64:
    return count_codepoints(text_bytes(s))

public def text_decode(s str) -> int[]:
    return decode(text_bytes(s))

public def text_encode(cps int[]) -> str:
    return bytes_to_text(encode(cps))

public def text_repair(s str) -> str:
    return bytes_to_text(repair(text_bytes(s)))
