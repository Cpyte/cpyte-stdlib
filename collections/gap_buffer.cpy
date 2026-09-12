import stdlib
import string

# GapBuffer: a flat char buffer with a single gap of unused space; the cursor
# moves with the gap so insert/delete in place is near-O(gap) with no shifting
# of the whole text. Classic text-editor editing structure.

struct GapBuffer:
    char* data
    size_t capacity
    size_t length
    size_t gap_start
    size_t gap_len

public def create_gap(cap size_t) -> GapBuffer:
    assert cap >= (size_t)1, "Value Error: You cannot create a gap buffer below capacity 1"
    GapBuffer gb
    gb.capacity = cap
    gb.data = (char*)malloc(cap * (size_t)sizeof(char))
    gb.length = (size_t)0
    gb.gap_start = (size_t)0
    gb.gap_len = cap
    return gb

public def gap_length(gb GapBuffer) -> size_t:
    return gb.length

public def _gap_move(gb GapBuffer, pos size_t) -> GapBuffer:
    size_t target = pos
    if target > gb.length:
        target = gb.length
    while gb.gap_start > target:
        gb.gap_start -= (size_t)1
        size_t gi = gb.gap_start + gb.gap_len
        gb.data[gi] = gb.data[gb.gap_start]
    while gb.gap_start < target:
        size_t gi = gb.gap_start + gb.gap_len
        gb.data[gb.gap_start] = gb.data[gi]
        gb.gap_start += (size_t)1
    return gb

public def _gap_grow(gb GapBuffer, new_cap size_t) -> GapBuffer:
    char* nd = (char*)malloc(new_cap * (size_t)sizeof(char))
    size_t left_len = gb.gap_start
    size_t right_len = gb.length - gb.gap_start
    size_t old_gap = gb.gap_len
    size_t new_gap = old_gap + (new_cap - gb.capacity)
    size_t i = (size_t)0
    for i in range((int)left_len):
        nd[i] = gb.data[i]
    size_t old_from = gb.gap_start + old_gap
    size_t new_off = gb.gap_start + new_gap
    size_t j = (size_t)0
    for j in range((int)right_len):
        nd[new_off + j] = gb.data[old_from + j]
    gb.data = nd
    gb.capacity = new_cap
    gb.gap_len = new_gap
    return gb

public def _gap_ensure(gb GapBuffer, need size_t) -> GapBuffer:
    size_t free_space = gb.capacity - gb.length
    if need > free_space:
        size_t total = gb.length + need
        size_t new_cap = gb.capacity * (size_t)2
        if new_cap < total:
            new_cap = total
        gb = _gap_grow(gb, new_cap)
    return gb

public def gap_insert(gb GapBuffer, pos size_t, text char*) -> GapBuffer:
    gb = _gap_move(gb, pos)
    size_t tlen = strlen(text)
    gb = _gap_ensure(gb, tlen)
    size_t i = (size_t)0
    for i in range((int)tlen):
        gb.data[gb.gap_start + i] = text[i]
    gb.gap_start += tlen
    gb.gap_len -= tlen
    gb.length += tlen
    return gb

public def gap_delete(gb GapBuffer, pos size_t, n size_t) -> GapBuffer:
    gb = _gap_move(gb, pos)
    if n > gb.length - pos:
        n = gb.length - pos
    gb.gap_len += n
    gb.length -= n
    return gb

public def gap_char_at(gb GapBuffer, pos size_t) -> char:
    if pos < gb.gap_start:
        return gb.data[pos]
    return gb.data[pos + gb.gap_len]

public def gap_get(gb GapBuffer) -> char*:
    size_t n = gb.length
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    size_t o = (size_t)0
    size_t i = (size_t)0
    for i in range((int)gb.gap_start):
        out[o] = gb.data[i]
        o += (size_t)1
    size_t gi = gb.gap_start + gb.gap_len
    while o < n:
        out[o] = gb.data[gi]
        gi += (size_t)1
        o += (size_t)1
    out[o] = (char)0
    return out