# @std/encoding — base64, hexadecimal and URL transfer encodings.
#
# Byte-oriented API: every function takes and returns `char[]` buffers whose
# `len()` is the exact number of encoded/decoded bytes, so binary data with
# embedded NULs round-trips. Buffers are allocated by cpy (`new char[n]`) and
# filled by the C helpers below, which keeps the GC in charge of the memory.
#
# Decoding is strict: a malformed input yields a zero-length result rather than
# partially decoded bytes.

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <string.h>

    static const char B64_ALPHABET[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /* -1 for anything outside the base64 alphabet, 0 for whitespace/padding. */
    static int b64_value(unsigned char c) {
        if (c == '=') return 0;
        if (c >= 'A' && c <= 'Z') return c - 'A';
        if (c >= 'a' && c <= 'z') return c - 'a' + 26;
        if (c >= '0' && c <= '9') return c - '0' + 52;
        if (c == '+') return 62;
        if (c == '/') return 63;
        if (c == '-') return 62;   /* also accept the URL-safe alphabet */
        if (c == '_') return 63;
        return -1;
    }

    int64_t cpy_b64_encoded_len(int64_t n) {
        if (n <= 0) return (int64_t)0;
        return ((n + 2) / 3) * 4;
    }

    int64_t cpy_b64_encoded_len_nopad(int64_t n) {
        if (n <= 0) return (int64_t)0;
        int64_t full = (n / 3) * 4;
        int64_t rest = n % 3;
        if (rest == 1) return full + 2;
        if (rest == 2) return full + 3;
        return full;
    }

    int64_t cpy_b64_encode(void* src, int64_t src_len, void* dst, int padded) {
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t i = 0, o = 0;
        if (src_len <= 0) return (int64_t)0;
        while (i + 3 <= src_len) {
            unsigned v = ((unsigned)in[i] << 16) | ((unsigned)in[i + 1] << 8) | in[i + 2];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 18) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 12) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 6) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[v & 63];
            i += 3;
        }
        int64_t rest = src_len - i;
        if (rest == 1) {
            unsigned v = (unsigned)in[i] << 16;
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 18) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 12) & 63];
            if (padded) { out[o++] = '='; out[o++] = '='; }
        } else if (rest == 2) {
            unsigned v = ((unsigned)in[i] << 16) | ((unsigned)in[i + 1] << 8);
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 18) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 12) & 63];
            out[o++] = (unsigned char)B64_ALPHABET[(v >> 6) & 63];
            if (padded) out[o++] = '=';
        }
        return o;
    }

    /* Returns the decoded byte count, or -1 when the input is not valid. */
    int64_t cpy_b64_decode(void* src, int64_t src_len, void* dst) {
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        unsigned acc = 0;
        int bits = 0;
        int seen_pad = 0;
        for (int64_t i = 0; i < src_len; i++) {
            unsigned char c = in[i];
            if (c == '\n' || c == '\r' || c == ' ' || c == '\t') continue;
            if (c == '=') { seen_pad = 1; bits = (bits + 6) % 8; continue; }
            if (seen_pad) return (int64_t)-1;      /* data after padding */
            int v = b64_value(c);
            if (v < 0) return (int64_t)-1;
            acc = (acc << 6) | (unsigned)v;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                out[o++] = (unsigned char)((acc >> bits) & 0xFF);
            }
        }
        /* Leftover bits must be zero padding of a final partial group. */
        if (bits >= 6) return (int64_t)-1;
        if (bits > 0 && ((acc & ((1u << bits) - 1u)) != 0)) return (int64_t)-1;
        return o;
    }

    int64_t cpy_b64_decoded_len(void* src, int64_t src_len) {
        const unsigned char* in = (const unsigned char*)src;
        int64_t payload = 0;
        for (int64_t i = 0; i < src_len; i++) {
            unsigned char c = in[i];
            if (c == '\n' || c == '\r' || c == ' ' || c == '\t') continue;
            if (c == '=') break;
            payload++;
        }
        return (payload * 6) / 8;
    }

    int64_t cpy_hex_encode(void* src, int64_t src_len, void* dst, int upper) {
        static const char LOWER[] = "0123456789abcdef";
        static const char UPPER[] = "0123456789ABCDEF";
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        const char* digits = upper ? UPPER : LOWER;
        for (int64_t i = 0; i < src_len; i++) {
            out[2 * i] = (unsigned char)digits[(in[i] >> 4) & 0xF];
            out[2 * i + 1] = (unsigned char)digits[in[i] & 0xF];
        }
        return src_len > 0 ? src_len * 2 : (int64_t)0;
    }

    static int hex_value(unsigned char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    }

    int64_t cpy_hex_decode(void* src, int64_t src_len, void* dst) {
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        if (src_len < 0 || (src_len % 2) != 0) return (int64_t)-1;
        for (int64_t i = 0; i < src_len; i += 2) {
            int hi = hex_value(in[i]), lo = hex_value(in[i + 1]);
            if (hi < 0 || lo < 0) return (int64_t)-1;
            out[i / 2] = (unsigned char)((hi << 4) | lo);
        }
        return src_len / 2;
    }

    /* RFC 3986 unreserved set: A-Z a-z 0-9 - _ . ~ */
    static int url_needs_escape(unsigned char c) {
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
            return 0;
        return 1;
    }

    /* form=1 keeps ' ' as '+' (application/x-www-form-urlencoded). */
    int64_t cpy_url_encoded_len(void* src, int64_t src_len, int form) {
        const unsigned char* in = (const unsigned char*)src;
        int64_t n = 0;
        for (int64_t i = 0; i < src_len; i++) {
            unsigned char c = in[i];
            if (form && c == ' ') n += 1;
            else n += url_needs_escape(c) ? 3 : 1;
        }
        return n;
    }

    int64_t cpy_url_encode(void* src, int64_t src_len, void* dst, int form) {
        static const char UPPER[] = "0123456789ABCDEF";
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        for (int64_t i = 0; i < src_len; i++) {
            unsigned char c = in[i];
            if (form && c == ' ') {
                out[o++] = '+';
            } else if (!url_needs_escape(c)) {
                out[o++] = c;
            } else {
                out[o++] = '%';
                out[o++] = (unsigned char)UPPER[(c >> 4) & 0xF];
                out[o++] = (unsigned char)UPPER[c & 0xF];
            }
        }
        return o;
    }

    int64_t cpy_url_decoded_len(void* src, int64_t src_len) {
        const unsigned char* in = (const unsigned char*)src;
        int64_t n = 0;
        for (int64_t i = 0; i < src_len; i++) {
            if (in[i] == '%' && i + 2 < src_len) { i += 2; n += 1; }
            else n += 1;
        }
        return n;
    }

    /* form=1 turns '+' into ' '. Returns byte count, or -1 on a bad escape. */
    int64_t cpy_url_decode(void* src, int64_t src_len, void* dst, int form) {
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* out = (unsigned char*)dst;
        int64_t o = 0;
        for (int64_t i = 0; i < src_len; i++) {
            unsigned char c = in[i];
            if (c == '%' ) {
                if (i + 2 >= src_len) return (int64_t)-1;
                int hi = hex_value(in[i + 1]), lo = hex_value(in[i + 2]);
                if (hi < 0 || lo < 0) return (int64_t)-1;
                out[o++] = (unsigned char)((hi << 4) | lo);
                i += 2;
            } else if (form && c == '+') {
                out[o++] = ' ';
            } else {
                out[o++] = c;
            }
        }
        return o;
    }

    int64_t cpy_bytes_len(const char* s) {
        return s ? (int64_t)strlen(s) : (int64_t)0;
    }

    int64_t cpy_bytes_copy(void* src, int64_t src_len, void* dst) {
        if (src == NULL || dst == NULL || src_len <= 0) return (int64_t)0;
        memcpy(dst, src, (size_t)src_len);
        return src_len;
    }

    /* Copy n bytes out and NUL-terminate, so a printable encoding can be
       handed back as a `str`. */
    int64_t cpy_bytes_text(void* src, int64_t src_len, void* dst) {
        const unsigned char* in = (const unsigned char*)src;
        unsigned char* d = (unsigned char*)dst;
        if (d == NULL) return (int64_t)0;
        if (src != NULL && src_len > 0) memcpy(d, in, (size_t)src_len);
        d[src_len > 0 ? src_len : 0] = 0;
        return src_len > 0 ? src_len : (int64_t)0;
    }

# ── text helpers ────────────────────────────────────────────────

# Encoders return exactly the encoded bytes with no terminator, so printable
# results need this step to become a `str`.
public def bytes_to_text(data char[]) -> str:
    int64 n = len(data)
    char[] buf = new char[n + (int64)1]
    cpy_bytes_text((void*)data, n, (void*)buf)
    return (str)buf

public def base64_text(data char[]) -> str:
    return bytes_to_text(base64_encode(data))

public def base64_nopad_text(data char[]) -> str:
    return bytes_to_text(base64_encode_nopad(data))

public def hex_text(data char[]) -> str:
    return bytes_to_text(hex_encode(data))

public def hex_text_upper(data char[]) -> str:
    return bytes_to_text(hex_encode_upper(data))

public def url_text(data char[]) -> str:
    return bytes_to_text(url_encode(data))

public def url_text_form(data char[]) -> str:
    return bytes_to_text(url_encode_form(data))

public def text_to_bytes(s str) -> char[]:
    int64 n = cpy_bytes_len(s)
    char[] out = new char[n]
    cpy_bytes_copy((void*)s, n, (void*)out)
    return out

# ── base64 ──────────────────────────────────────────────────────

public def base64_encode(data char[]) -> char[]:
    int64 n = len(data)
    int64 out_n = cpy_b64_encoded_len(n)
    char[] out = new char[out_n]
    cpy_b64_encode((void*)data, n, (void*)out, 1)
    return out

public def base64_encode_nopad(data char[]) -> char[]:
    int64 n = len(data)
    int64 out_n = cpy_b64_encoded_len_nopad(n)
    char[] out = new char[out_n]
    cpy_b64_encode((void*)data, n, (void*)out, 0)
    return out

public def base64_encoded_length(data_len int64) -> int64:
    return cpy_b64_encoded_len(data_len)

public def base64_decode(data char[]) -> char[]:
    int64 n = len(data)
    int64 cap = cpy_b64_decoded_len((void*)data, n)
    if cap < 0:
        cap = (int64)0
    char[] out = new char[cap]
    int64 written = cpy_b64_decode((void*)data, n, (void*)out)
    if written < 0:
        return new char[(int64)0]
    return out

public def base64_is_valid(data char[]) -> bool:
    int64 n = len(data)
    char[] scratch = new char[n]
    return cpy_b64_decode((void*)data, n, (void*)scratch) >= (int64)0

# ── hexadecimal ─────────────────────────────────────────────────

public def hex_encode(data char[]) -> char[]:
    int64 n = len(data)
    char[] out = new char[n * (int64)2]
    cpy_hex_encode((void*)data, n, (void*)out, 0)
    return out

public def hex_encode_upper(data char[]) -> char[]:
    int64 n = len(data)
    char[] out = new char[n * (int64)2]
    cpy_hex_encode((void*)data, n, (void*)out, 1)
    return out

public def hex_decode(data char[]) -> char[]:
    int64 n = len(data)
    char[] out = new char[n / (int64)2]
    int64 written = cpy_hex_decode((void*)data, n, (void*)out)
    if written < 0:
        return new char[(int64)0]
    return out

public def hex_is_valid(data char[]) -> bool:
    int64 n = len(data)
    char[] scratch = new char[n / (int64)2 + (int64)1]
    return cpy_hex_decode((void*)data, n, (void*)scratch) >= (int64)0

# ── percent encoding ────────────────────────────────────────────

public def url_encode(data char[]) -> char[]:
    int64 n = len(data)
    int64 out_n = cpy_url_encoded_len((void*)data, n, 0)
    char[] out = new char[out_n]
    cpy_url_encode((void*)data, n, (void*)out, 0)
    return out

public def url_encode_form(data char[]) -> char[]:
    int64 n = len(data)
    int64 out_n = cpy_url_encoded_len((void*)data, n, 1)
    char[] out = new char[out_n]
    cpy_url_encode((void*)data, n, (void*)out, 1)
    return out

public def url_decode(data char[]) -> char[]:
    int64 n = len(data)
    char[] out = new char[cpy_url_decoded_len((void*)data, n)]
    int64 written = cpy_url_decode((void*)data, n, (void*)out, 0)
    if written < 0:
        return new char[(int64)0]
    return out

public def url_decode_form(data char[]) -> char[]:
    int64 n = len(data)
    char[] out = new char[cpy_url_decoded_len((void*)data, n)]
    int64 written = cpy_url_decode((void*)data, n, (void*)out, 1)
    if written < 0:
        return new char[(int64)0]
    return out
