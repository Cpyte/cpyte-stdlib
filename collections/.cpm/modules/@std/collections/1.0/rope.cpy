import stdlib
import string

# Rope: a binary tree of immutable string chunks (leaves), each node carrying
# the total char count of its subtree. The left subtree size decides descent,
# so mid-text insert/delete split/retrim leaves in place without shifting the
# whole buffer. Weight convention: weight(n) = total chars under n.

struct RopeNode:
    char* str
    RopeNode* left
    RopeNode* right
    size_t weight

struct Rope:
    RopeNode* root
    size_t length

public def create_rope() -> Rope:
    Rope r
    r.root = 0
    r.length = (size_t)0
    return r

public def _rope_size(n RopeNode*) -> size_t:
    if n == 0:
        return (size_t)0
    return n.weight

public def _rope_leaf(s char*, n size_t) -> RopeNode*:
    RopeNode* leaf = new RopeNode
    leaf.str = s
    leaf.left = 0
    leaf.right = 0
    leaf.weight = n
    return leaf

public def _rope_fold(l RopeNode*, r RopeNode*) -> RopeNode*:
    RopeNode* f = new RopeNode
    f.str = 0
    f.left = l
    f.right = r
    f.weight = _rope_size(l) + _rope_size(r)
    return f

public def rope_append(r Rope, s char*) -> Rope:
    size_t n = strlen(s)
    if r.root == 0:
        r.root = _rope_leaf(s, n)
    else:
        r.root = _rope_fold(r.root, _rope_leaf(s, n))
    r.length = r.length + n
    return r

public def _rope_copy(out char*, src char*, doff size_t, soff size_t, n size_t):
    size_t i = (size_t)0
    for i in range((int)n):
        out[doff + i] = src[soff + i]

public def _rope_sub(s char*, from size_t, n size_t) -> char*:
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    _rope_copy(out, s, (size_t)0, from, n)
    out[n] = (char)0
    return out

public def _rope_at(n RopeNode*, i size_t) -> char:
    if n.left == 0:
        return n.str[i]
    if i < _rope_size(n.left):
        return _rope_at(n.left, i)
    return _rope_at(n.right, i - _rope_size(n.left))

public def rope_at(r Rope, i size_t) -> char:
    return _rope_at(r.root, i)

public def _rope_collect(n RopeNode*, out char*, off size_t) -> size_t:
    if n.left == 0:
        _rope_copy(out, n.str, off, (size_t)0, n.weight)
        return n.weight
    size_t l = _rope_collect(n.left, out, off)
    return l + _rope_collect(n.right, out, off + l)

public def rope_to_string(r Rope) -> char*:
    size_t n = r.length
    char* out = (char*)malloc((n + (size_t)1) * (size_t)sizeof(char))
    if n > (size_t)0:
        _rope_collect(r.root, out, (size_t)0)
    out[n] = (char)0
    return out

public def rope_length(r Rope) -> size_t:
    return r.length

public def _rope_ins(node RopeNode*, pos size_t, s char*, sn size_t) -> RopeNode*:
    if node.left == 0:
        if pos == (size_t)0:
            return _rope_fold(_rope_leaf(s, sn), node)
        if pos >= node.weight:
            return _rope_fold(node, _rope_leaf(s, sn))
        RopeNode* a = _rope_leaf(_rope_sub(node.str, (size_t)0, pos), pos)
        RopeNode* b = _rope_leaf(_rope_sub(node.str, pos, node.weight - pos), node.weight - pos)
        RopeNode* mid = _rope_fold(a, _rope_leaf(s, sn))
        return _rope_fold(mid, b)
    if pos <= _rope_size(node.left):
        node.left = _rope_ins(node.left, pos, s, sn)
    else:
        node.right = _rope_ins(node.right, pos - _rope_size(node.left), s, sn)
    node.weight = _rope_size(node.left) + _rope_size(node.right)
    return node

public def rope_insert(r Rope, pos size_t, s char*) -> Rope:
    if pos > r.length:
        pos = r.length
    size_t sn = strlen(s)
    if r.root == 0:
        r.root = _rope_leaf(s, sn)
        r.length = sn
        return r
    r.root = _rope_ins(r.root, pos, s, sn)
    r.length = r.length + sn
    return r

public def _rope_del(node RopeNode*, pos size_t, n size_t, rem size_t*) -> RopeNode*:
    if node.left == 0:
        if pos >= node.weight:
            return node
        size_t take = node.weight - pos
        if take > *rem:
            take = *rem
        *rem = *rem - take
        size_t keep0 = pos
        size_t keep1 = node.weight - pos - take
        if keep0 + keep1 == (size_t)0:
            return 0
        char* ns = (char*)malloc((keep0 + keep1 + (size_t)1) * (size_t)sizeof(char))
        _rope_copy(ns, node.str, (size_t)0, (size_t)0, keep0)
        _rope_copy(ns, node.str, keep0, pos + take, keep1)
        ns[keep0 + keep1] = (char)0
        return _rope_leaf(ns, keep0 + keep1)
    size_t lw = _rope_size(node.left)
    if pos < lw:
        node.left = _rope_del(node.left, pos, n, rem)
        if *rem > (size_t)0 and node.right != 0:
            node.right = _rope_del(node.right, (size_t)0, n, rem)
    else:
        node.right = _rope_del(node.right, pos - lw, n, rem)
    if node.left == 0:
        if node.right == 0:
            return 0
        return node.right
    if node.right == 0:
        return node.left
    node.weight = _rope_size(node.left) + _rope_size(node.right)
    return node

public def rope_delete(r Rope, pos size_t, n size_t) -> Rope:
    if pos > r.length:
        pos = r.length
    if pos + n > r.length:
        n = r.length - pos
    size_t rem = n
    r.root = _rope_del(r.root, pos, n, &rem)
    r.length = r.length - n
    return r