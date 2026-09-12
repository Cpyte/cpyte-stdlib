import stdlib
import string

# Cache-friendly trie. Nodes and edges live in dense flat pools (one array per
# field) instead of separately malloc'd linked structs, so child scans stride
# linearly through small contiguous buffers rather than hopping across the
# heap. A node's children form an index-linked chain keyed off nfirst[node];
# the BIG sentinel means "no next entry".

struct Trie:
    size_t* nfirst
    char* nterm
    size_t ncap
    size_t nn
    size_t* echild
    size_t* enext
    char* ech
    size_t ecap
    size_t en
    size_t count

public def create_trie() -> Trie:
    Trie t
    t.ncap = (size_t)8
    t.nfirst = (size_t*)malloc(t.ncap * (size_t)sizeof(size_t))
    t.nterm = (char*)malloc(t.ncap * (size_t)sizeof(char))
    t.nn = (size_t)1
    t.nfirst[0] = (size_t)0x7FFFFFFF
    t.nterm[0] = (char)0
    t.ecap = (size_t)8
    t.echild = (size_t*)malloc(t.ecap * (size_t)sizeof(size_t))
    t.enext = (size_t*)malloc(t.ecap * (size_t)sizeof(size_t))
    t.ech = (char*)malloc(t.ecap * (size_t)sizeof(char))
    t.en = (size_t)0
    t.count = (size_t)0
    return t

public def _tr_ints(src size_t*, oldn size_t, newn size_t) -> size_t*:
    size_t* o = (size_t*)malloc(newn * (size_t)sizeof(size_t))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _tr_chars(src char*, oldn size_t, newn size_t) -> char*:
    char* o = (char*)malloc(newn * (size_t)sizeof(char))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _tr_npush(t Trie, out size_t*) -> Trie:
    if t.nn == t.ncap:
        size_t nc = t.ncap * (size_t)2
        if nc < (size_t)8:
            nc = (size_t)8
        t.nfirst = _tr_ints(t.nfirst, t.ncap, nc)
        t.nterm = _tr_chars(t.nterm, t.ncap, nc)
        t.ncap = nc
    size_t id = t.nn
    t.nfirst[id] = (size_t)0x7FFFFFFF
    t.nterm[id] = (char)0
    t.nn = t.nn + (size_t)1
    (*out) = id
    return t

public def _tr_epush(t Trie, ch char, child size_t, par size_t) -> Trie:
    if t.en == t.ecap:
        size_t ec = t.ecap * (size_t)2
        if ec < (size_t)8:
            ec = (size_t)8
        t.echild = _tr_ints(t.echild, t.ecap, ec)
        t.enext = _tr_ints(t.enext, t.ecap, ec)
        t.ech = _tr_chars(t.ech, t.ecap, ec)
        t.ecap = ec
    size_t id = t.en
    t.ech[id] = ch
    t.echild[id] = child
    t.enext[id] = t.nfirst[par]
    t.nfirst[par] = id
    t.en = id + (size_t)1
    return t

public def _tr_find(t Trie, node size_t, ch char) -> size_t:
    size_t e = t.nfirst[node]
    while e != (size_t)0x7FFFFFFF:
        if t.ech[e] == ch:
            return e
        e = t.enext[e]
    return (size_t)0x7FFFFFFF

public def trie_insert(t Trie, s char*) -> Trie:
    size_t node = (size_t)0
    size_t i = (size_t)0
    size_t slen = strlen(s)
    int done = 0
    while done == 0:
        if i == slen:
            if t.nterm[node] == (char)1:
                done = 1
            else:
                t.nterm[node] = (char)1
                t.count = t.count + (size_t)1
                done = 1
        else:
            size_t e = _tr_find(t, node, s[i])
            if e != (size_t)0x7FFFFFFF:
                node = t.echild[e]
                i = i + (size_t)1
            else:
                size_t nid = (size_t)0
                t = _tr_npush(t, &nid)
                t = _tr_epush(t, s[i], nid, node)
                node = nid
                i = i + (size_t)1
                while i < slen:
                    size_t k = (size_t)0
                    t = _tr_npush(t, &k)
                    t = _tr_epush(t, s[i], k, node)
                    node = k
                    i = i + (size_t)1
                t.nterm[node] = (char)1
                t.count = t.count + (size_t)1
                done = 1
    return t

public def trie_search(t Trie, s char*) -> int:
    size_t node = (size_t)0
    size_t i = (size_t)0
    size_t slen = strlen(s)
    while i < slen:
        size_t e = _tr_find(t, node, s[i])
        if e == (size_t)0x7FFFFFFF:
            return 0
        node = t.echild[e]
        i = i + (size_t)1
    if t.nterm[node] == (char)1:
        return 1
    return 0

public def trie_starts_with(t Trie, s char*) -> int:
    size_t node = (size_t)0
    size_t i = (size_t)0
    size_t slen = strlen(s)
    while i < slen:
        size_t e = _tr_find(t, node, s[i])
        if e == (size_t)0x7FFFFFFF:
            return 0
        node = t.echild[e]
        i = i + (size_t)1
    return 1

public def trie_size(t Trie) -> size_t:
    return t.count

public def trie_count(t Trie) -> size_t:
    return t.count