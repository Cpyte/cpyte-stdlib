import stdlib
import string

# Radix Tree: a compressed trie, cache-friendly build. Every edge and node
# lives in a dense flat pool (one array per field) instead of separately
# malloc'd structs, so scans stride linearly through a few contiguous buffers.
# Children of a node form an index-linked chain headed by nfirst[node]; the
# BIG sentinel means "no next entry". Each edge owns a small label buffer.

struct Radix:
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

public def create_radix() -> Radix:
    Radix rx
    rx.ncap = (size_t)8
    rx.nfirst = (size_t*)malloc(rx.ncap * (size_t)sizeof(size_t))
    rx.nterm = (char*)malloc(rx.ncap * (size_t)sizeof(char))
    rx.nn = (size_t)1
    rx.nfirst[0] = (size_t)0x7FFFFFFF
    rx.nterm[0] = (char)0
    rx.ecap = (size_t)8
    rx.elbl = (char**)malloc(rx.ecap * (size_t)sizeof(char*))
    rx.elen = (size_t*)malloc(rx.ecap * (size_t)sizeof(size_t))
    rx.echild = (size_t*)malloc(rx.ecap * (size_t)sizeof(size_t))
    rx.enext = (size_t*)malloc(rx.ecap * (size_t)sizeof(size_t))
    rx.en = (size_t)0
    rx.count = (size_t)0
    return rx

public def _rx_ints(src size_t*, oldn size_t, newn size_t) -> size_t*:
    size_t* o = (size_t*)malloc(newn * (size_t)sizeof(size_t))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _rx_chars(src char*, oldn size_t, newn size_t) -> char*:
    char* o = (char*)malloc(newn * (size_t)sizeof(char))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _rx_chpps(src char**, oldn size_t, newn size_t) -> char**:
    char** o = (char**)malloc(newn * (size_t)sizeof(char*))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _rx_npush(t Radix, out size_t*) -> Radix:
    if t.nn == t.ncap:
        size_t nc = t.ncap * (size_t)2
        if nc < (size_t)8:
            nc = (size_t)8
        t.nfirst = _rx_ints(t.nfirst, t.ncap, nc)
        t.nterm = _rx_chars(t.nterm, t.ncap, nc)
        t.ncap = nc
    size_t id = t.nn
    t.nfirst[id] = (size_t)0x7FFFFFFF
    t.nterm[id] = (char)0
    t.nn = t.nn + (size_t)1
    (*out) = id
    return t

public def _rx_epush(t Radix, label char*, len size_t, child size_t, par size_t) -> Radix:
    if t.en == t.ecap:
        size_t ec = t.ecap * (size_t)2
        if ec < (size_t)8:
            ec = (size_t)8
        t.elbl = _rx_chpps(t.elbl, t.ecap, ec)
        t.elen = _rx_ints(t.elen, t.ecap, ec)
        t.echild = _rx_ints(t.echild, t.ecap, ec)
        t.enext = _rx_ints(t.enext, t.ecap, ec)
        t.ecap = ec
    size_t id = t.en
    t.elbl[id] = label
    t.elen[id] = len
    t.echild[id] = child
    t.enext[id] = t.nfirst[par]
    t.nfirst[par] = id
    t.en = id + (size_t)1
    return t

public def _rx_label(s char*, off size_t, n size_t) -> char*:
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    size_t i = (size_t)0
    for i in range((int)n):
        out[i] = s[off + i]
    out[n] = (char)0
    return out

public def _rx_common(label char*, s char*, off size_t) -> size_t:
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

public def _rx_match(t Radix, n size_t, s char*, off size_t) -> size_t:
    size_t e = t.nfirst[n]
    while e != (size_t)0x7FFFFFFF:
        size_t m = _rx_common(t.elbl[e], s, off)
        if m > (size_t)0:
            return e
        e = t.enext[e]
    return (size_t)0x7FFFFFFF

public def radix_search(rt Radix, s char*) -> int:
    size_t n = (size_t)0
    size_t off = (size_t)0
    size_t slen = strlen(s)
    int found = 0
    while found == 0:
        size_t e = _rx_match(rt, n, s, off)
        if e != (size_t)0x7FFFFFFF:
            size_t m = _rx_common(rt.elbl[e], s, off)
            size_t rl = slen - off
            if m == rl:
                if m == rt.elen[e]:
                    if rt.nterm[rt.echild[e]] == (char)1:
                        return 1
                    return 0
                return 0
            if m != rt.elen[e]:
                return 0
            off = off + m
            n = rt.echild[e]
        else:
            return 0
    return 0

public def radix_starts(rt Radix, s char*) -> int:
    size_t n = (size_t)0
    size_t off = (size_t)0
    size_t slen = strlen(s)
    int found = 0
    while found == 0:
        if off >= slen:
            return 1
        size_t e = _rx_match(rt, n, s, off)
        if e != (size_t)0x7FFFFFFF:
            size_t m = _rx_common(rt.elbl[e], s, off)
            size_t rl = slen - off
            if m == rl:
                return 1
            if m != rt.elen[e]:
                return 0
            off = off + m
            n = rt.echild[e]
        else:
            return 0
    return 0

public def radix_size(rt Radix) -> size_t:
    return rt.count

public def radix_insert(rt Radix, s char*) -> Radix:
    if radix_search(rt, s) == 1:
        return rt
    size_t n = (size_t)0
    size_t off = (size_t)0
    size_t slen = strlen(s)
    int done = 0
    while done == 0:
        size_t e = _rx_match(rt, n, s, off)
        if e != (size_t)0x7FFFFFFF:
            size_t m = _rx_common(rt.elbl[e], s, off)
            if m == rt.elen[e]:
                off = off + m
                if s[off] == (char)0:
                    rt.nterm[rt.echild[e]] = (char)1
                    done = 1
                else:
                    size_t e2 = _rx_match(rt, rt.echild[e], s, off)
                    if e2 != (size_t)0x7FFFFFFF:
                        n = rt.echild[e]
                    else:
                        size_t leaf = (size_t)0
                        rt = _rx_npush(rt, &leaf)
                        rt.nterm[leaf] = (char)1
                        rt = _rx_epush(rt, _rx_label(s, off, slen - off), slen - off, leaf, rt.echild[e])
                        done = 1
            else:
                size_t mid = (size_t)0
                rt = _rx_npush(rt, &mid)
                rt = _rx_epush(rt, _rx_label(rt.elbl[e], m, rt.elen[e] - m), rt.elen[e] - m, rt.echild[e], mid)
                size_t leaf = (size_t)0
                rt = _rx_npush(rt, &leaf)
                rt.nterm[leaf] = (char)1
                rt = _rx_epush(rt, _rx_label(s, off + m, slen - off - m), slen - off - m, leaf, mid)
                rt.elbl[e] = _rx_label(rt.elbl[e], (size_t)0, m)
                rt.elen[e] = m
                rt.echild[e] = mid
                done = 1
        else:
            size_t leaf = (size_t)0
            rt = _rx_npush(rt, &leaf)
            rt.nterm[leaf] = (char)1
            rt = _rx_epush(rt, _rx_label(s, off, slen - off), slen - off, leaf, n)
            done = 1
    rt.count = rt.count + (size_t)1
    return rt