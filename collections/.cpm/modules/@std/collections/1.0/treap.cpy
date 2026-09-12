import stdlib

# Treap: a randomized BST where every node has a (pseudo-random, deterministic
# here) priority kept as a max-heap on top of the usual BST order. Expected
# O(log n) insert/erase/contains; priorities come from a fixed hash of the key
# so behaviour is reproducible and the heap+order invariants are checkable.
# Self-contained; structs are passed by value so callers write
# `t = treap_insert(t, k)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field.
struct TrNode:
    TrNode* left
    TrNode* right
    int key
    int prio

struct Treap:
    TrNode* root
    size_t size

public def create_treap() -> Treap:
    Treap t
    t.root = 0
    t.size = (size_t)0
    return t

public def _tr_prio(key int) -> int:
    return (key * 1103515245 + 12345) & 0x7fffffff

public def _tr_rotate_right(y TrNode*) -> TrNode*:
    TrNode* x = y.left
    y.left = x.right
    x.right = y
    return x

public def _tr_rotate_left(x TrNode*) -> TrNode*:
    TrNode* y = x.right
    x.right = y.left
    y.left = x
    return y

public def _tr_insert_rec(root TrNode*, key int, prio int, created int*) -> TrNode*:
    if root == 0:
        TrNode* n = new TrNode
        n.left = 0
        n.right = 0
        n.key = key
        n.prio = prio
        *created = 1
        return n
    if key == root.key:
        *created = 0
        return root
    if key < root.key:
        root.left = _tr_insert_rec(root.left, key, prio, created)
        if (*root.left).prio > root.prio:
            root = _tr_rotate_right(root)
    else:
        root.right = _tr_insert_rec(root.right, key, prio, created)
        if (*root.right).prio > root.prio:
            root = _tr_rotate_left(root)
    return root

public def _tr_erase_rec(root TrNode*, key int, found int*) -> TrNode*:
    if root == 0:
        return root
    if key == root.key:
        *found = 1
        if root.left == 0:
            return root.right
        if root.right == 0:
            return root.left
        if (*root.left).prio > (*root.right).prio:
            root = _tr_rotate_right(root)
            root.right = _tr_erase_rec(root.right, key, found)
        else:
            root = _tr_rotate_left(root)
            root.left = _tr_erase_rec(root.left, key, found)
        return root
    if key < root.key:
        root.left = _tr_erase_rec(root.left, key, found)
    else:
        root.right = _tr_erase_rec(root.right, key, found)
    return root

public def _tr_contains_rec(root TrNode*, key int) -> int:
    if root == 0:
        return 0
    if key == root.key:
        return 1
    if key < root.key:
        return _tr_contains_rec(root.left, key)
    return _tr_contains_rec(root.right, key)

public def _tr_find_min(n TrNode*) -> TrNode*:
    TrNode* cur = n
    TrNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    return cur

public def _tr_find_max(n TrNode*) -> TrNode*:
    TrNode* cur = n
    TrNode* nxt = 0
    if cur != 0:
        nxt = cur.right
    while nxt != 0:
        cur = nxt
        nxt = cur.right
    return cur

public def _tr_check(n TrNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0:
        if (*n.left).key >= n.key:
            return 0
        if (*n.left).prio > n.prio:
            return 0
    if n.right != 0:
        if (*n.right).key <= n.key:
            return 0
        if (*n.right).prio > n.prio:
            return 0
    int lc = 0
    int rc = 0
    int ok_l = _tr_check(n.left, &lc)
    int ok_r = _tr_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    *cnt = lc + rc + 1
    return 1

public def treap_insert(t Treap, key int) -> Treap:
    int created = 0
    t.root = _tr_insert_rec(t.root, key, _tr_prio(key), &created)
    if created == 1:
        t.size += (size_t)1
    return t

public def treap_erase(t Treap, key int) -> Treap:
    int found = 0
    t.root = _tr_erase_rec(t.root, key, &found)
    if found == 1:
        if t.size > (size_t)0:
            t.size -= (size_t)1
    return t

public def treap_contains(t Treap, key int) -> int:
    return _tr_contains_rec(t.root, key)

public def treap_size(t Treap) -> size_t:
    return t.size

public def treap_is_empty(t Treap) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# Smallest key (caller should check is_empty first).
public def treap_min(t Treap) -> int:
    TrNode* n = _tr_find_min(t.root)
    if n == 0:
        return 0
    return n.key

# Largest key (caller should check is_empty first).
public def treap_max(t Treap) -> int:
    TrNode* n = _tr_find_max(t.root)
    if n == 0:
        return 0
    return n.key

public def treap_validate(t Treap) -> int:
    int cnt = 0
    int ok = _tr_check(t.root, &cnt)
    if ok == 0:
        return 0
    if (size_t)cnt != t.size:
        return 0
    return 1