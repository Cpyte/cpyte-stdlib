import stdlib

# TreeSet: an ordered set of unique int values, backed by an AVL-balanced BST.
# "Ordered unique values" — iteration order is sorted; membership/insert/
# remove are O(log n). Mutators return the updated TreeSet; inserting an
# existing value is a no-op.
# Self-contained; structs are passed by value so callers write
# `s = treeset_insert(s, v)`.
# NOTE: the codegen cannot follow chained pointer fields (`n.left.key`); child
# pointers are reached via (*l).key or extracted into a local first.
struct TsNode:
    TsNode* left
    TsNode* right
    int key
    int height

struct TreeSet:
    TsNode* root
    size_t size

public def create_treeset() -> TreeSet:
    TreeSet s
    s.root = 0
    s.size = (size_t)0
    return s

public def _ts_height(n TsNode*) -> int:
    if n == 0:
        return 0
    return n.height

public def _ts_update(n TsNode*) -> void:
    int l = _ts_height(n.left)
    int r = _ts_height(n.right)
    if l >= r:
        n.height = l + 1
    else:
        n.height = r + 1

public def _ts_rotate_right(y TsNode*) -> TsNode*:
    TsNode* x = y.left
    y.left = x.right
    x.right = y
    _ts_update(y)
    _ts_update(x)
    return x

public def _ts_rotate_left(x TsNode*) -> TsNode*:
    TsNode* y = x.right
    x.right = y.left
    y.left = x
    _ts_update(x)
    _ts_update(y)
    return y

public def _ts_fix(n TsNode*) -> TsNode*:
    _ts_update(n)
    int b = _ts_height(n.left) - _ts_height(n.right)
    if b > 1:
        TsNode* l = n.left
        if _ts_height(l.right) > _ts_height(l.left):
            n.left = _ts_rotate_left(n.left)
        return _ts_rotate_right(n)
    if b < -1:
        TsNode* r = n.right
        if _ts_height(r.left) > _ts_height(r.right):
            n.right = _ts_rotate_right(n.right)
        return _ts_rotate_left(n)
    return n

public def _ts_insert_rec(root TsNode*, key int) -> TsNode*:
    if root == 0:
        TsNode* n = new TsNode
        n.left = 0
        n.right = 0
        n.key = key
        n.height = 1
        return n
    if key < root.key:
        root.left = _ts_insert_rec(root.left, key)
    elif key > root.key:
        root.right = _ts_insert_rec(root.right, key)
    else:
        return root
    return _ts_fix(root)

public def _ts_contains_rec(root TsNode*, key int) -> int:
    if root == 0:
        return 0
    if key == root.key:
        return 1
    if key < root.key:
        return _ts_contains_rec(root.left, key)
    return _ts_contains_rec(root.right, key)

public def _ts_erase_rec(root TsNode*, key int) -> TsNode*:
    if root == 0:
        return root
    if key < root.key:
        root.left = _ts_erase_rec(root.left, key)
    elif key > root.key:
        root.right = _ts_erase_rec(root.right, key)
    else:
        if root.left == 0:
            return root.right
        if root.right == 0:
            return root.left
        TsNode* succ = root.right
        while succ.left != 0:
            succ = succ.left
        root.key = succ.key
        root.right = _ts_erase_rec(root.right, succ.key)
    return _ts_fix(root)

public def treeset_insert(s TreeSet, key int) -> TreeSet:
    int present = _ts_contains_rec(s.root, key)
    if present == 1:
        return s
    s.root = _ts_insert_rec(s.root, key)
    s.size += (size_t)1
    return s

public def treeset_contains(s TreeSet, key int) -> int:
    return _ts_contains_rec(s.root, key)

public def treeset_erase(s TreeSet, key int) -> TreeSet:
    int present = _ts_contains_rec(s.root, key)
    if present == 0:
        return s
    s.root = _ts_erase_rec(s.root, key)
    if s.size > (size_t)0:
        s.size -= (size_t)1
    return s

public def treeset_min(s TreeSet) -> int:
    TsNode* cur = s.root
    TsNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    if cur == 0:
        return 0
    return cur.key

public def treeset_max(s TreeSet) -> int:
    TsNode* cur = s.root
    TsNode* nxt = 0
    if cur != 0:
        nxt = cur.right
    while nxt != 0:
        cur = nxt
        nxt = cur.right
    if cur == 0:
        return 0
    return cur.key

public def _ts_collect(n TsNode*, buf int*, pos int*) -> void:
    if n == 0:
        return
    _ts_collect(n.left, buf, pos)
    buf[*pos] = n.key
    *pos = *pos + 1
    _ts_collect(n.right, buf, pos)

# Dump values in sorted order into `buf` (must hold at least size() ints).
public def treeset_to_buffer(s TreeSet, buf int*) -> void:
    int pos = 0
    _ts_collect(s.root, buf, &pos)

# Union: a new set with every value present in a or b.
public def treeset_union(a TreeSet, b TreeSet) -> TreeSet:
    TreeSet out = a
    int* keys = (int*)malloc(b.size * (size_t)sizeof(int))
    int pos = 0
    _ts_collect(b.root, keys, &pos)
    int i = 0
    while i < (int)b.size:
        out = treeset_insert(out, keys[i])
        i = i + 1
    return out

# Intersection: a new set with values present in both a and b.
public def treeset_intersect(a TreeSet, b TreeSet) -> TreeSet:
    TreeSet out = create_treeset()
    int* keys = (int*)malloc(a.size * (size_t)sizeof(int))
    int pos = 0
    _ts_collect(a.root, keys, &pos)
    int i = 0
    while i < (int)a.size:
        int in_b = _ts_contains_rec(b.root, keys[i])
        if in_b == 1:
            out = treeset_insert(out, keys[i])
        i = i + 1
    return out

# Difference: a new set with values present in a but not in b.
public def treeset_difference(a TreeSet, b TreeSet) -> TreeSet:
    TreeSet out = create_treeset()
    int* keys = (int*)malloc(a.size * (size_t)sizeof(int))
    int pos = 0
    _ts_collect(a.root, keys, &pos)
    int i = 0
    while i < (int)a.size:
        int in_b = _ts_contains_rec(b.root, keys[i])
        if in_b == 0:
            out = treeset_insert(out, keys[i])
        i = i + 1
    return out

# 1 if every value of a is also in b.
public def treeset_is_subset(a TreeSet, b TreeSet) -> int:
    int ok = 1
    int* keys = (int*)malloc(a.size * (size_t)sizeof(int))
    int pos = 0
    _ts_collect(a.root, keys, &pos)
    int i = 0
    while i < (int)a.size:
        int in_b = _ts_contains_rec(b.root, keys[i])
        if in_b == 0:
            ok = 0
        i = i + 1
    return ok

public def treeset_size(s TreeSet) -> size_t:
    return s.size

public def treeset_is_empty(s TreeSet) -> int:
    int e = 0
    if s.size == (size_t)0:
        e = 1
    return e

public def _ts_check(n TsNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    int lc = 0
    int rc = 0
    int ok_l = _ts_check(n.left, &lc)
    int ok_r = _ts_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    int b = _ts_height(n.left) - _ts_height(n.right)
    if b > 1 or b < -1:
        return 0
    *cnt = lc + rc + 1
    return 1

# 1 if the set obeys BST + AVL invariants.
public def treeset_validate(s TreeSet) -> int:
    int cnt = 0
    return _ts_check(s.root, &cnt)