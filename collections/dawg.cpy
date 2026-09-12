import stdlib
import string

# DAWG: a Directed Acyclic Word Graph, i.e. the minimal deterministic
# automaton accepting a stored word set. Words are first loaded into a trie;
# dawg_minimize() then canonicalizes nodes bottom-up: every node is assigned a
# signature built from its terminal flag and its sorted (char, canonical-id)
# edge set, and identical signatures are merged into one shared state.
# Cache-friendly build: nodes, edges and the signature registry are dense flat
# pools (one array per field) - minimization walks a contiguous stack and
# registry scans stride over small flat buffers instead of chasing mallocs.

#define dwell on sizes: registry grows on demand, node/edge pools double.

struct DAWG:
    size_t* nfirst
    char* nterm
    size_t* ncanon
    size_t ncap
    size_t nn
    char* ech
    size_t* echild
    size_t* enext
    size_t ecap
    size_t en
    char** regsig
    size_t* regid
    size_t* regrep
    size_t regcap
    size_t regn
    size_t head
    size_t count

struct DWStk:
    size_t* a
    size_t top
    size_t cap

public def create_dawg() -> DAWG:
    DAWG dw
    dw.ncap = (size_t)8
    dw.nfirst = (size_t*)malloc(dw.ncap * (size_t)sizeof(size_t))
    dw.nterm = (char*)malloc(dw.ncap * (size_t)sizeof(char))
    dw.ncanon = (size_t*)malloc(dw.ncap * (size_t)sizeof(size_t))
    dw.nn = (size_t)1
    dw.nfirst[0] = (size_t)0x7FFFFFFF
    dw.nterm[0] = (char)0
    dw.ncanon[0] = (size_t)0x7FFFFFFF
    dw.ecap = (size_t)8
    dw.ech = (char*)malloc(dw.ecap * (size_t)sizeof(char))
    dw.echild = (size_t*)malloc(dw.ecap * (size_t)sizeof(size_t))
    dw.enext = (size_t*)malloc(dw.ecap * (size_t)sizeof(size_t))
    dw.en = (size_t)0
    dw.regcap = (size_t)8
    dw.regsig = (char**)malloc(dw.regcap * (size_t)sizeof(char*))
    dw.regid = (size_t*)malloc(dw.regcap * (size_t)sizeof(size_t))
    dw.regrep = (size_t*)malloc(dw.regcap * (size_t)sizeof(size_t))
    dw.regn = (size_t)0
    dw.head = (size_t)0
    dw.count = (size_t)0
    return dw

public def _dw_ints(src size_t*, oldn size_t, newn size_t) -> size_t*:
    size_t* o = (size_t*)malloc(newn * (size_t)sizeof(size_t))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _dw_chars(src char*, oldn size_t, newn size_t) -> char*:
    char* o = (char*)malloc(newn * (size_t)sizeof(char))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _dw_chpps(src char**, oldn size_t, newn size_t) -> char**:
    char** o = (char**)malloc(newn * (size_t)sizeof(char*))
    size_t c = oldn
    if c > newn:
        c = newn
    size_t i = (size_t)0
    for i in range((int)c):
        o[i] = src[i]
    return o

public def _dw_npush(t DAWG, out size_t*) -> DAWG:
    if t.nn == t.ncap:
        size_t nc = t.ncap * (size_t)2
        if nc < (size_t)8:
            nc = (size_t)8
        t.nfirst = _dw_ints(t.nfirst, t.ncap, nc)
        t.nterm = _dw_chars(t.nterm, t.ncap, nc)
        t.ncanon = _dw_ints(t.ncanon, t.ncap, nc)
        t.ncap = nc
    size_t id = t.nn
    t.nfirst[id] = (size_t)0x7FFFFFFF
    t.nterm[id] = (char)0
    t.ncanon[id] = (size_t)0x7FFFFFFF
    t.nn = t.nn + (size_t)1
    (*out) = id
    return t

public def _dw_epush(t DAWG, ch char, child size_t, par size_t) -> DAWG:
    if t.en == t.ecap:
        size_t ec = t.ecap * (size_t)2
        if ec < (size_t)8:
            ec = (size_t)8
        t.ech = _dw_chars(t.ech, t.ecap, ec)
        t.echild = _dw_ints(t.echild, t.ecap, ec)
        t.enext = _dw_ints(t.enext, t.ecap, ec)
        t.ecap = ec
    size_t id = t.en
    t.ech[id] = ch
    t.echild[id] = child
    t.enext[id] = t.nfirst[par]
    t.nfirst[par] = id
    t.en = id + (size_t)1
    return t

public def _dw_regpush(t DAWG, sig char*, rep size_t) -> DAWG:
    if t.regn == t.regcap:
        size_t rc = t.regcap * (size_t)2
        if rc < (size_t)8:
            rc = (size_t)8
        t.regsig = _dw_chpps(t.regsig, t.regcap, rc)
        t.regid = _dw_ints(t.regid, t.regcap, rc)
        t.regrep = _dw_ints(t.regrep, t.regcap, rc)
        t.regcap = rc
    t.regsig[t.regn] = sig
    t.regid[t.regn] = t.regn
    t.regrep[t.regn] = rep
    t.regn = t.regn + (size_t)1
    return t

public def _dw_stk_new() -> DWStk:
    DWStk st
    st.cap = (size_t)8
    st.a = (size_t*)malloc(st.cap * (size_t)sizeof(size_t))
    st.top = (size_t)0
    return st

public def _dw_stk_push(st DWStk, v size_t) -> DWStk:
    if st.top == st.cap:
        size_t nc = st.cap * (size_t)2
        st.a = _dw_ints(st.a, st.cap, nc)
        st.cap = nc
    st.a[st.top] = v
    st.top = st.top + (size_t)1
    return st

public def _dw_stk_pop(st DWStk) -> DWStk:
    st.top = st.top - (size_t)1
    return st

public def _dw_stk_top(st DWStk) -> size_t:
    return st.a[st.top - (size_t)1]

public def _dw_stk_len(st DWStk) -> size_t:
    return st.top

public def _dw_edge_for(t DAWG, n size_t, c char) -> size_t:
    size_t e = t.nfirst[n]
    while e != (size_t)0x7FFFFFFF:
        if t.ech[e] == c:
            return e
        e = t.enext[e]
    return (size_t)0x7FFFFFFF

public def _dw_digit(d size_t) -> char:
    if d < (size_t)10:
        return (char)(0x30 + d)
    return (char)(0x61 + d - (size_t)10)

public def _dw_reg_find(t DAWG, sig char*) -> size_t:
    size_t j = (size_t)0
    while j < t.regn:
        if strcmp(t.regsig[j], sig) == 0:
            return j
        j = j + (size_t)1
    return (size_t)0x7FFFFFFF

public def _dw_reg_byid(t DAWG, id size_t) -> size_t:
    size_t j = (size_t)0
    while j < t.regn:
        if t.regid[j] == id:
            return j
        j = j + (size_t)1
    return (size_t)0x7FFFFFFF

public def _dw_sig(t DAWG, n size_t) -> char*:
    char* b = (char*)malloc((size_t)600 * (size_t)sizeof(char))
    if t.nterm[n] == (char)1:
        b[0] = (char)0x31
    else:
        b[0] = (char)0x30
    size_t bi = (size_t)1
    int c = 0
    for c in range(128):
        char cc = (char)c
        size_t e = _dw_edge_for(t, n, cc)
        if e != (size_t)0x7FFFFFFF:
            b[bi] = (char)(c + 32)
            bi = bi + (size_t)1
            size_t nid = t.ncanon[t.echild[e]]
            size_t d0 = nid % (size_t)36
            size_t d1 = (nid / (size_t)36) % (size_t)36
            size_t d2 = (nid / (size_t)1296) % (size_t)36
            b[bi] = _dw_digit(d0)
            b[bi + (size_t)1] = _dw_digit(d1)
            b[bi + (size_t)2] = _dw_digit(d2)
            bi = bi + (size_t)3
    b[bi] = (char)0
    return b

public def _dw_canon(dw DAWG, n size_t) -> DAWG:
    size_t e = dw.nfirst[n]
    while e != (size_t)0x7FFFFFFF:
        size_t cid = dw.ncanon[dw.echild[e]]
        size_t r = _dw_reg_byid(dw, cid)
        if r != (size_t)0x7FFFFFFF:
            dw.echild[e] = dw.regrep[r]
        e = dw.enext[e]
    char* sig = _dw_sig(dw, n)
    size_t hit = _dw_reg_find(dw, sig)
    if hit != (size_t)0x7FFFFFFF:
        dw.ncanon[n] = dw.regid[hit]
        return dw
    dw = _dw_regpush(dw, sig, n)
    dw.ncanon[n] = dw.regn - (size_t)1
    return dw

public def dawg_minimize(dw DAWG) -> DAWG:
    DWStk st = _dw_stk_new()
    st = _dw_stk_push(st, (size_t)0)
    while _dw_stk_len(st) > (size_t)0:
        size_t c = _dw_stk_top(st)
        st = _dw_stk_pop(st)
        if dw.ncanon[c] >= (size_t)0x7FFFFFFF:
            int ready = 1
            size_t e = dw.nfirst[c]
            while e != (size_t)0x7FFFFFFF:
                if dw.ncanon[dw.echild[e]] >= (size_t)0x7FFFFFFF:
                    ready = 0
                e = dw.enext[e]
            if ready == 1:
                dw = _dw_canon(dw, c)
            else:
                st = _dw_stk_push(st, c)
                size_t e2 = dw.nfirst[c]
                while e2 != (size_t)0x7FFFFFFF:
                    st = _dw_stk_push(st, dw.echild[e2])
                    e2 = dw.enext[e2]
    size_t rr = _dw_reg_byid(dw, dw.ncanon[0])
    if rr != (size_t)0x7FFFFFFF:
        dw.head = dw.regrep[rr]
    else:
        dw.head = (size_t)0
    return dw

public def _dw_child(t DAWG, n size_t, c char) -> size_t:
    size_t e = _dw_edge_for(t, n, c)
    if e != (size_t)0x7FFFFFFF:
        return t.echild[e]
    return (size_t)0x7FFFFFFF

public def dawg_has(dw DAWG, s char*) -> int:
    size_t n = dw.head
    size_t slen = strlen(s)
    size_t i = (size_t)0
    int found = 0
    while found == 0:
        if i == slen:
            if dw.nterm[n] == (char)1:
                return 1
            return 0
        char c = s[i]
        size_t nx = _dw_child(dw, n, c)
        if nx != (size_t)0x7FFFFFFF:
            n = nx
            i = i + (size_t)1
        else:
            return 0
    return 0

public def dawg_insert(dw DAWG, s char*) -> DAWG:
    size_t n = (size_t)0
    size_t i = (size_t)0
    size_t slen = strlen(s)
    int done = 0
    while done == 0:
        if i == slen:
            if dw.nterm[n] == (char)1:
                done = 1
            else:
                dw.nterm[n] = (char)1
                dw.count = dw.count + (size_t)1
                done = 1
        else:
            char c = s[i]
            size_t nx = _dw_child(dw, n, c)
            if nx != (size_t)0x7FFFFFFF:
                n = nx
                i = i + (size_t)1
            else:
                size_t leaf = (size_t)0
                dw = _dw_npush(dw, &leaf)
                dw = _dw_epush(dw, c, leaf, n)
                n = leaf
                i = i + (size_t)1
                while i < slen:
                    size_t nl = (size_t)0
                    dw = _dw_npush(dw, &nl)
                    dw = _dw_epush(dw, s[i], nl, n)
                    n = nl
                    i = i + (size_t)1
                dw.nterm[n] = (char)1
                dw.count = dw.count + (size_t)1
                done = 1
    return dw

public def dawg_size(dw DAWG) -> size_t:
    return dw.count

public def dawg_nodes(dw DAWG) -> size_t:
    return dw.regn