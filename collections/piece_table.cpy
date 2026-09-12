import stdlib
import string

# Piece Table: a text-editor editing structure that never rewrites stable text.
# The buffer is kept as an ordered list of pieces referencing either the
# original document (origin) or an append-only add buffer. Insert/delete only
# split and relink pieces; get_text() flattens on demand.

struct Piece:
    int src
    size_t start
    size_t length
    Piece* next

struct PieceTable:
    char* origin
    char* add
    size_t add_len
    size_t add_cap
    Piece* head
    size_t length

public def create_piece_table(init char*) -> PieceTable:
    PieceTable pt
    pt.origin = init
    pt.add = (char*)malloc((size_t)16 * (size_t)sizeof(char))
    pt.add_len = (size_t)0
    pt.add_cap = (size_t)16
    pt.head = 0
    pt.length = (size_t)0
    size_t olen = strlen(init)
    if olen > (size_t)0:
        Piece* p = new Piece
        p.src = 0
        p.start = (size_t)0
        p.length = olen
        p.next = 0
        pt.head = p
        pt.length = olen
    return pt

public def piece_table_length(pt PieceTable) -> size_t:
    return pt.length

public def _pt_split(pt PieceTable, pos size_t) -> PieceTable:
    if pos >= pt.length:
        return pt
    Piece* p = pt.head
    size_t acc = (size_t)0
    while p != 0:
        size_t pn = (*p).length
        if acc + pn > pos:
            size_t off = pos - acc
            if off == (size_t)0:
                return pt
            Piece* right = new Piece
            right.src = (*p).src
            right.start = (*p).start + off
            right.length = (*p).length - off
            right.next = (*p).next
            (*p).length = off
            (*p).next = right
            return pt
        acc = acc + pn
        p = (*p).next
    return pt

public def _pt_add_text(pt PieceTable, s char*, n size_t) -> PieceTable:
    size_t need = pt.add_len + n
    if need > pt.add_cap:
        size_t new_cap = pt.add_cap * (size_t)2
        if new_cap < need:
            new_cap = need
        char* nd = (char*)malloc(new_cap * (size_t)sizeof(char))
        size_t i = (size_t)0
        for i in range((int)pt.add_len):
            nd[i] = pt.add[i]
        pt.add = nd
        pt.add_cap = new_cap
    size_t j = (size_t)0
    for j in range((int)n):
        pt.add[pt.add_len + j] = s[j]
    pt.add_len = need
    return pt

public def _pt_link(pt PieceTable, p Piece*, pos size_t) -> PieceTable:
    Piece* prev = 0
    Piece* q = pt.head
    size_t acc = (size_t)0
    int done = 0
    while done == 0:
        if q != 0:
            if acc == pos:
                done = 1
            else:
                acc = acc + (*q).length
                prev = q
                q = (*q).next
        else:
            done = 1
    p.next = q
    if prev != 0:
        (*prev).next = p
    else:
        pt.head = p
    return pt

public def piece_table_insert(pt PieceTable, pos size_t, s char*) -> PieceTable:
    if pos > pt.length:
        pos = pt.length
    pt = _pt_split(pt, pos)
    size_t n = strlen(s)
    if n == (size_t)0:
        return pt
    size_t off = pt.add_len
    pt = _pt_add_text(pt, s, n)
    Piece* p = new Piece
    p.src = 1
    p.start = off
    p.length = n
    pt = _pt_link(pt, p, pos)
    pt.length = pt.length + n
    return pt

public def piece_table_delete(pt PieceTable, pos size_t, n size_t) -> PieceTable:
    if pos > pt.length:
        pos = pt.length
    if pos + n > pt.length:
        n = pt.length - pos
    pt = _pt_split(pt, pos)
    pt = _pt_split(pt, pos + n)
    Piece* q = pt.head
    Piece* prevq = 0
    size_t run = (size_t)0
    while q != 0:
        size_t qn = (*q).length
        int rm = 0
        if run >= pos:
            if run + qn <= pos + n:
                rm = 1
        Piece* nx = (*q).next
        if rm == 1:
            if prevq != 0:
                (*prevq).next = nx
            else:
                pt.head = nx
        else:
            prevq = q
        run = run + qn
        q = nx
    pt.length = pt.length - n
    return pt

public def piece_table_text(pt PieceTable) -> char*:
    size_t n = pt.length
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    size_t o = (size_t)0
    Piece* p = pt.head
    while p != 0:
        size_t i = (size_t)0
        for i in range((int)(*p).length):
            char c
            if (*p).src == 1:
                c = pt.add[(*p).start + i]
            else:
                c = pt.origin[(*p).start + i]
            out[o] = c
            o += (size_t)1
        p = (*p).next
    out[o] = (char)0
    return out