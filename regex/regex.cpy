# regex 1.0.0 - cross-platform regex (small ERE subset)

ccode:
    #include <stdint.h>
    #include <stddef.h>
    #include <string.h>
    #include <ctype.h>

    static int rx_in_class(char ch, const char* cls_start, const char* cls_end) {
        int neg = 0;
        const char* p = cls_start;
        if (p < cls_end && *p == '^') { neg = 1; p++; }
        int found = 0;
        while (p < cls_end) {
            if (p + 2 < cls_end && p[1] == '-') {
                char a = p[0], b = p[2];
                if (ch >= a && ch <= b) found = 1;
                p += 3;
            } else {
                if (ch == *p) found = 1;
                p++;
            }
        }
        return neg ? !found : found;
    }

    static int rx_atom_matches(char ch, const char** pat_pp) {
        const char* p = *pat_pp;
        if (*p == 0) { *pat_pp = p; return 0; }
        if (*p == '\\') {
            p++;
            if (*p == 0) { *pat_pp = p; return -1; }
            char e = *p++;
            *pat_pp = p;
            if (e == 'd') return isdigit((unsigned char)ch) ? 1 : 0;
            if (e == 'D') return isdigit((unsigned char)ch) ? 0 : 1;
            if (e == 'w') return (isalnum((unsigned char)ch) || ch == '_') ? 1 : 0;
            if (e == 'W') return (isalnum((unsigned char)ch) || ch == '_') ? 0 : 1;
            if (e == 's') return isspace((unsigned char)ch) ? 1 : 0;
            if (e == 'S') return isspace((unsigned char)ch) ? 0 : 1;
            if (e == 'n') return ch == '\n' ? 1 : 0;
            if (e == 't') return ch == '\t' ? 1 : 0;
            if (e == 'r') return ch == '\r' ? 1 : 0;
            return ch == e ? 1 : 0;
        }
        if (*p == '.') { *pat_pp = p + 1; return 1; }
        if (*p == '[') {
            p++;
            const char* start = p;
            while (*p) {
                if (*p == '\\') { p++; if (*p) p++; continue; }
                if (*p == ']') break;
                p++;
            }
            if (*p != ']') { *pat_pp = p; return -1; }
            int m = rx_in_class(ch, start, p);
            p++;
            *pat_pp = p;
            return m;
        }
        if (ch == *p) { *pat_pp = p + 1; return 1; }
        *pat_pp = p + 1;
        return 0;
    }

    static int rx_match_from(const char* pat, const char* text);

    static int rx_match_quant(const char* atom_pat, const char* after_quant, char q, const char* text) {
        if (q == '*') {
            const char* t = text;
            for (;;) {
                if (rx_match_from(after_quant, t)) return 1;
                if (*t == 0) return 0;
                {
                    const char* ap = atom_pat;
                    int m = rx_atom_matches(*t, &ap);
                    if (m < 0) return 0;
                    if (!m) return 0;
                }
                t++;
            }
        } else if (q == '+') {
            if (*text == 0) return 0;
            {
                const char* ap = atom_pat;
                int m = rx_atom_matches(*text, &ap);
                if (m <= 0) return 0;
            }
            const char* t = text + 1;
            for (;;) {
                if (rx_match_from(after_quant, t)) return 1;
                if (*t == 0) return 0;
                {
                    const char* ap = atom_pat;
                    int m = rx_atom_matches(*t, &ap);
                    if (m <= 0) return 0;
                }
                t++;
            }
        } else if (q == '?') {
            if (rx_match_from(after_quant, text)) return 1;
            if (*text != 0) {
                const char* ap = atom_pat;
                int m = rx_atom_matches(*text, &ap);
                if (m > 0) {
                    if (rx_match_from(after_quant, text + 1)) return 1;
                }
            }
            return 0;
        }
        return 0;
    }

    static int rx_match_from(const char* pat, const char* text) {
        if (pat[0] == 0) return 1;
        if (pat[0] == '$' && pat[1] == 0) return *text == 0 ? 1 : 0;

        const char* atom_pat = pat;
        const char* after_atom = pat;
        if (*after_atom == '\\') {
            after_atom++;
            if (!*after_atom) return 0;
            after_atom++;
        } else if (*after_atom == '[') {
            after_atom++;
            if (*after_atom == '^') after_atom++;
            while (*after_atom) {
                if (*after_atom == '\\') { after_atom++; if (*after_atom) after_atom++; continue; }
                if (*after_atom == ']') { after_atom++; break; }
                if (after_atom[1] == '-' && after_atom[2] && after_atom[2] != ']') after_atom += 3;
                else after_atom++;
            }
        } else {
            after_atom++;
        }
        char q = 0;
        if (*after_atom == '*' || *after_atom == '+' || *after_atom == '?') {
            q = *after_atom;
            after_atom++;
        }
        if (q) {
            return rx_match_quant(atom_pat, after_atom, q, text);
        } else {
            if (*text == 0) return 0;
            {
                const char* ap = atom_pat;
                int m = rx_atom_matches(*text, &ap);
                if (m <= 0) return 0;
            }
            return rx_match_from(after_atom, text + 1);
        }
    }

    int64_t cpy_regex_match_c(const char* pat, const char* text) {
        if (!pat || !text) return (int64_t)-1;
        if (pat[0] == '^') {
            int ok = rx_match_from(pat + 1, text);
            return ok ? (int64_t)1 : (int64_t)0;
        }
        {
            const char* t = text;
            for (;;) {
                if (rx_match_from(pat, t)) return (int64_t)1;
                if (*t == 0) break;
                t++;
            }
        }
        return (int64_t)0;
    }

public def regex_match(pat str, text str) -> int:
    return (int)cpy_regex_match_c(pat, text)
