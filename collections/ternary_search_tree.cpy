import stdlib
import string

# Ternary Search Tree: a string dictionary where each node holds one char and
# three pointers (lo/eq/hi). Keys share prefixes in the eq-spine and diverge via
# lo/hi, giving O(key-length) lookup with a much smaller footprint than an
# explicit trie and no per-node edge tables.

struct TSTNode:
    char c
    TSTNode* lo
    TSTNode* eq
    TSTNode* hi
    int count

struct TST:
    TSTNode* root
    size_t size

public def create_tst() -> TST:
    TST t
    t.root = 0
    t.size = (size_t)0
    return t

public def _tst_insert(n TSTNode*, s char*, i size_t, len size_t) -> TSTNode*:
    if n == 0:
        n = new TSTNode
        n.c = s[i]
        n.lo = 0
        n.eq = 0
        n.hi = 0
        n.count = 0
    if s[i] < n.c:
        n.lo = _tst_insert(n.lo, s, i, len)
    elif s[i] > n.c:
        n.hi = _tst_insert(n.hi, s, i, len)
    else:
        size_t next = i + (size_t)1
        if next == len:
            n.count += 1
        else:
            n.eq = _tst_insert(n.eq, s, next, len)
    return n

public def tst_insert(t TST, s char*) -> TST:
    t.root = _tst_insert(t.root, s, (size_t)0, strlen(s))
    t.size += (size_t)1
    return t

public def _tst_search(n TSTNode*, s char*, i size_t, len size_t) -> TSTNode*:
    if n == 0:
        return 0
    if s[i] < n.c:
        return _tst_search(n.lo, s, i, len)
    if s[i] > n.c:
        return _tst_search(n.hi, s, i, len)
    size_t next = i + (size_t)1
    if next == len:
        return n
    return _tst_search(n.eq, s, next, len)

public def tst_search(t TST, s char*) -> int:
    TSTNode* n = _tst_search(t.root, s, (size_t)0, strlen(s))
    int r = 0
    if n != 0 and n.count > 0:
        r = 1
    return r

public def tst_prefix(t TST, s char*) -> int:
    TSTNode* n = _tst_search(t.root, s, (size_t)0, strlen(s))
    int r = 0
    if n != 0:
        r = 1
    return r

public def tst_size(t TST) -> size_t:
    return t.size