import stdlib
import string

# Suffix Tree: a compressed trie of every suffix of every added string,
# cache-friendly build. Nodes and edges live in dense flat pools (one array
# per field) instead of separately malloc'd structs; child scans walk a few
# small contiguous buffers. A node's children form an index-linked chain
# headed by nfirst[node]; the BIG sentinel means "no next entry".

struct SuffixTree:
    size_t* nfirst
    char* nterm
    size_t ncap
    size_t nn
    char** elbl
    size_t* elen
    size_t* echild
    size_t* enext
    size_t ecap
    size_t en
    size_t count

public def create_suffix_tree() -> SuffixTree:
    SuffixTree st
    st.ncap = (size_t)8
    st.nfirst = (size_t*)malloc(st.ncap * (size_t)sizeof(size_t))
    st.nterm = (char*)malloc(st.ncap * (size_t)sizeof(char))
    st.nn = (size_t)1
    st.nfirst[0] = (size_t)0x7FFFFFFF
    st.nterm[0] = (char)0
    st.ecap = (size_t)8
    st.elbl = (char**)malloc(st.ecap * (size_t)sizeof(char*))
    st.elen = (size_t*)malloc(st.ecap * (size_t)sizeof(size_t))
    st.echild = (size_t*)malloc(st.ecap * (size_t)sizeof(size_t))
    st.enext = (size_t*)malloc(st.ecap * (size_t)sizeof(size_t))
    st.en = (size_t)0
    st.count = (size_t)0
    return st

public def _st_ints(src size_t*, oldn size_t, newn size_t) -> size_t*:
    size_t* o = (size_t*)malloc(newn * (size_t)sizeof(size_t))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _st_chars(src char*, oldn size_t, newn size_t) -> char*:
    char* o = (char*)malloc(newn * (size_t)sizeof(char))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _st_chpps(src char**, oldn size_t, newn size_t) -> char**:
    char** o = (char**)malloc(newn * (size_t)sizeof(char*))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _st_npush(t SuffixTree, out size_t*) -> SuffixTree:
    if t.nn == t.ncap:
        size_t nc = t.ncap * (size_t)2
        if nc < (size_t)8:
            nc = (size_t)8
        t.nfirst = _st_ints(t.nfirst, t.ncap, nc)
        t.nterm = _st_chars(t.nterm, t.ncap, nc)
        t.ncap = nc
    size_t id = t.nn
    t.nfirst[id] = (size_t)0x7FFFFFFF
    t.nterm[id] = (char)0
    t.nn = t.nn + (size_t)1
    (*out) = id
    return t

public def _st_epush(t SuffixTree, label char*, len size_t, child size_t, par size_t) -> SuffixTree:
    if t.en == t.ecap:
        size_t ec = t.ecap * (size_t)2
        if ec < (size_t)8:
            ec = (size_t)8
        t.elbl = _st_chpps(t.elbl, t.ecap, ec)
        t.elen = _st_ints(t.elen, t.ecap, ec)
        t.echild = _st_ints(t.echild, t.ecap, ec)
        t.enext = _st_ints(t.enext, t.ecap, ec)
        t.ecap = ec
    size_t id = t.en
    t.elbl[id] = label
    t.elen[id] = len
    t.echild[id] = child
    t.enext[id] = t.nfirst[par]
    t.nfirst[par] = id
    t.en = id + (size_t)1
    return t

public def _st_label(s char*, off size_t, n size_t) -> char*:
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    size_t i = (size_t)0
    for i in range((int)n):
        out[i] = s[off + i]
    out[n] = (char)0
    return out

public def _st_common(label char*, s char*, off size_t) -> size_t:
    size_t la = strlen(label)
    size_t tail = strlen(s)
    if tail > off:
        tail = tail - off
    else:
        tail = (size_t)0
    size_t max = la
    if tail < max:
        max = tail
    size_t i = (size_t)0
    for i in range((int)max):
        if label[i] != s[off + i]:
            return (size_t)i
    return max

public def _st_match(t SuffixTree, n size_t, s char*, off size_t) -> size_t:
    size_t e = t.nfirst[n]
    while e != (size_t)0x7FFFFFFF:
        size_t m = _st_common(t.elbl[e], s, off)
        if m > (size_t)0:
            return e
        e = t.enext[e]
    return (size_t)0x7FFFFFFF

public def _st_has(st SuffixTree, s char*, off size_t) -> int:
    size_t n = (size_t)0
    size_t slen = strlen(s)
    int found = 0
    while found == 0:
        if off >= slen:
            return 1
        size_t e = _st_match(st, n, s, off)
        if e != (size_t)0x7FFFFFFF:
            size_t m = _st_common(st.elbl[e], s, off)
            size_t rl = slen - off
            if m == rl:
                return 1
            if m != st.elen[e]:
                return 0
            off = off + m
            n = st.echild[e]
        else:
            return 0
    return 0

public def suffix_contains(st SuffixTree, s char*) -> int:
    return _st_has(st, s, (size_t)0)

public def _st_ins(st SuffixTree, s char*, off size_t) -> SuffixTree:
    size_t n = (size_t)0
    size_t slen = strlen(s)
    int done = 0
    while done == 0:
        size_t e = _st_match(st, n, s, off)
        if e != (size_t)0x7FFFFFFF:
            size_t m = _st_common(st.elbl[e], s, off)
            if m == st.elen[e]:
                off = off + m
                if off >= slen:
                    st.nterm[st.echild[e]] = (char)1
                    done = 1
                else:
                    size_t e2 = _st_match(st, st.echild[e], s, off)
                    if e2 != (size_t)0x7FFFFFFF:
                        n = st.echild[e]
                    else:
                        size_t leaf = (size_t)0
                        st = _st_npush(st, &leaf)
                        st.nterm[leaf] = (char)1
                        st = _st_epush(st, _st_label(s, off, slen - off), slen - off, leaf, st.echild[e])
                        done = 1
            else:
                size_t mid = (size_t)0
                st = _st_npush(st, &mid)
                st = _st_epush(st, _st_label(st.elbl[e], m, st.elen[e] - m), st.elen[e] - m, st.echild[e], mid)
                size_t leaf = (size_t)0
                st = _st_npush(st, &leaf)
                st.nterm[leaf] = (char)1
                st = _st_epush(st, _st_label(s, off + m, slen - off - m), slen - off - m, leaf, mid)
                st.elbl[e] = _st_label(st.elbl[e], (size_t)0, m)
                st.elen[e] = m
                st.echild[e] = mid
                done = 1
        else:
            size_t leaf = (size_t)0
            st = _st_npush(st, &leaf)
            st.nterm[leaf] = (char)1
            st = _st_epush(st, _st_label(s, off, slen - off), slen - off, leaf, n)
            done = 1
    return st

public def suffix_add(st SuffixTree, s char*) -> SuffixTree:
    size_t slen = strlen(s)
    size_t k = (size_t)0
    while k < slen:
        if _st_has(st, s, k) == 0:
            st = _st_ins(st, s, k)
            st.count = st.count + (size_t)1
        k += (size_t)1
    return st

public def suffix_size(st SuffixTree) -> size_t:
    return st.count