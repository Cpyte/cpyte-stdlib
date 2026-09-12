import stdlib

# TreeMap: an ordered key->value map backed by an AVL-balanced BST of int
# keys and int values. Insert/erase/contains are O(log n); ascending iteration
# order follows key order. Duplicate keys are rejected (put overwrites).
# Self-contained; structs are passed by value so callers write
# `m = treemap_put(m, k, v)`.
# NOTE: the codegen cannot follow chained pointer fields (`n.left.key`); child
# pointers are reached via (*child).field or extracted into a local first.
struct TmNode:
    TmNode* left
    TmNode* right
    int key
    int value
    int height

struct TreeMap:
    TmNode* root
    size_t size

public def create_treemap() -> TreeMap:
    TreeMap m
    m.root = 0
    m.size = (size_t)0
    return m

public def _tm_height(n TmNode*) -> int:
    if n == 0:
        return 0
    return n.height

public def _tm_update(n TmNode*) -> void:
    int l = _tm_height(n.left)
    int r = _tm_height(n.right)
    if l >= r:
        n.height = l + 1
    else:
        n.height = r + 1

public def _tm_rotate_right(y TmNode*) -> TmNode*:
    TmNode* x = y.left
    y.left = x.right
    x.right = y
    _tm_update(y)
    _tm_update(x)
    return x

public def _tm_rotate_left(x TmNode*) -> TmNode*:
    TmNode* y = x.right
    x.right = y.left
    y.left = x
    _tm_update(x)
    _tm_update(y)
    return y

public def _tm_fix(n TmNode*) -> TmNode*:
    _tm_update(n)
    int b = _tm_height(n.left) - _tm_height(n.right)
    if b > 1:
        TmNode* l = n.left
        if _tm_height(l.right) > _tm_height(l.left):
            n.left = _tm_rotate_left(n.left)
        return _tm_rotate_right(n)
    if b < -1:
        TmNode* r = n.right
        if _tm_height(r.left) > _tm_height(r.right):
            n.right = _tm_rotate_right(n.right)
        return _tm_rotate_left(n)
    return n

public def _tm_put_rec(root TmNode*, key int, value int, placed int*) -> TmNode*:
    if root == 0:
        TmNode* n = new TmNode
        n.left = 0
        n.right = 0
        n.key = key
        n.value = value
        n.height = 1
        *placed = 1
        return n
    if key < root.key:
        root.left = _tm_put_rec(root.left, key, value, placed)
    elif key > root.key:
        root.right = _tm_put_rec(root.right, key, value, placed)
    else:
        root.value = value
        return root
    return _tm_fix(root)

public def _tm_find_rec(root TmNode*, key int) -> TmNode*:
    if root == 0:
        return root
    if key == root.key:
        return root
    if key < root.key:
        return _tm_find_rec(root.left, key)
    return _tm_find_rec(root.right, key)

public def _tm_find_min(n TmNode*) -> TmNode*:
    TmNode* cur = n
    TmNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    return cur

public def _tm_erase_rec(root TmNode*, key int) -> TmNode*:
    if root == 0:
        return root
    if key < root.key:
        root.left = _tm_erase_rec(root.left, key)
    elif key > root.key:
        root.right = _tm_erase_rec(root.right, key)
    else:
        if root.left == 0:
            return root.right
        if root.right == 0:
            return root.left
        TmNode* succ = _tm_find_min(root.right)
        root.key = succ.key
        root.value = succ.value
        root.right = _tm_erase_rec(root.right, succ.key)
    return _tm_fix(root)

public def _tm_check(n TmNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    int lc = 0
    int rc = 0
    int ok_l = _tm_check(n.left, &lc)
    int ok_r = _tm_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    int lh = _tm_height(n.left)
    int rh = _tm_height(n.right)
    if lh - rh > 1 or rh - lh > 1:
        return 0
    int ch = _tm_height(n)
    int want = 1
    if lh >= rh:
        want = lh + 1
    else:
        want = rh + 1
    if ch != want:
        return 0
    *cnt = lc + rc + 1
    return 1

public def treemap_put(m TreeMap, key int, value int) -> TreeMap:
    int placed = 0
    m.root = _tm_put_rec(m.root, key, value, &placed)
    if placed == 1:
        m.size += (size_t)1
    return m

# Returns the value for `key`; 0 when absent. Caller may use contains() to
# disambiguate a stored 0 value.
public def treemap_get(m TreeMap, key int) -> int:
    TmNode* n = _tm_find_rec(m.root, key)
    if n == 0:
        return 0
    return n.value

public def treemap_contains(m TreeMap, key int) -> int:
    TmNode* n = _tm_find_rec(m.root, key)
    if n == 0:
        return 0
    return 1

public def treemap_erase(m TreeMap, key int) -> TreeMap:
    int present = treemap_contains(m, key)
    if present == 0:
        return m
    m.root = _tm_erase_rec(m.root, key)
    if m.size > (size_t)0:
        m.size -= (size_t)1
    return m

public def treemap_size(m TreeMap) -> size_t:
    return m.size

public def treemap_is_empty(m TreeMap) -> int:
    int e = 0
    if m.size == (size_t)0:
        e = 1
    return e

# Smallest key (caller should check is_empty first).
public def treemap_min(m TreeMap) -> int:
    TmNode* n = _tm_find_min(m.root)
    if n == 0:
        return 0
    return n.key

# Largest key (caller should check is_empty first).
public def treemap_max(m TreeMap) -> int:
    TmNode* cur = m.root
    TmNode* nxt = 0
    if cur != 0:
        nxt = cur.right
    while nxt != 0:
        cur = nxt
        nxt = cur.right
    if cur == 0:
        return 0
    return cur.key

public def treemap_validate(m TreeMap) -> int:
    int cnt = 0
    return _tm_check(m.root, &cnt)