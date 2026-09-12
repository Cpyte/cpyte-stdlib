import stdlib

# AVL Tree: a strictly-balanced binary search tree of int keys.
# Every insert/delete keeps the tree balanced (|height(left)-height(right)|<=1)
# via single/double rotations, guaranteeing O(log n) search in the worst case.
# Self-contained: structs are passed by value, so every mutator returns the
# updated AvlTree (`t = avl_insert(t, k)`). Duplicate keys are rejected:
# inserting an existing key returns the tree unchanged and does not grow it.
# NOTE: the codegen cannot follow chained pointer fields (`n.left.key`); child
# pointers are always extracted into a local first or reached via (*l).key.
struct AvlNode:
    AvlNode* left
    AvlNode* right
    int key
    int height

struct AvlTree:
    AvlNode* root
    size_t size

public def create_avltree() -> AvlTree:
    AvlTree t
    t.root = 0
    t.size = (size_t)0
    return t

public def _avl_height(n AvlNode*) -> int:
    if n == 0:
        return 0
    return n.height

public def _avl_update(n AvlNode*) -> void:
    int l = _avl_height(n.left)
    int r = _avl_height(n.right)
    if l >= r:
        n.height = l + 1
    else:
        n.height = r + 1

public def _avl_bal(n AvlNode*) -> int:
    return _avl_height(n.left) - _avl_height(n.right)

public def _avl_rotate_right(y AvlNode*) -> AvlNode*:
    AvlNode* x = y.left
    y.left = x.right
    x.right = y
    _avl_update(y)
    _avl_update(x)
    return x

public def _avl_rotate_left(x AvlNode*) -> AvlNode*:
    AvlNode* y = x.right
    x.right = y.left
    y.left = x
    _avl_update(x)
    _avl_update(y)
    return y

public def _avl_fix(n AvlNode*) -> AvlNode*:
    _avl_update(n)
    int b = _avl_bal(n)
    if b > 1:
        if _avl_bal(n.left) < 0:
            n.left = _avl_rotate_left(n.left)
        return _avl_rotate_right(n)
    if b < -1:
        if _avl_bal(n.right) > 0:
            n.right = _avl_rotate_right(n.right)
        return _avl_rotate_left(n)
    return n

public def _avl_insert_rec(root AvlNode*, key int) -> AvlNode*:
    if root == 0:
        AvlNode* n = new AvlNode
        n.left = 0
        n.right = 0
        n.key = key
        n.height = 1
        return n
    if key < root.key:
        root.left = _avl_insert_rec(root.left, key)
    elif key > root.key:
        root.right = _avl_insert_rec(root.right, key)
    else:
        return root
    return _avl_fix(root)

public def _avl_contains_rec(root AvlNode*, key int) -> int:
    if root == 0:
        return 0
    if key == root.key:
        return 1
    if key < root.key:
        return _avl_contains_rec(root.left, key)
    return _avl_contains_rec(root.right, key)

public def _avl_erase_rec(root AvlNode*, key int) -> AvlNode*:
    if root == 0:
        return root
    if key < root.key:
        root.left = _avl_erase_rec(root.left, key)
    elif key > root.key:
        root.right = _avl_erase_rec(root.right, key)
    else:
        if root.left == 0:
            return root.right
        if root.right == 0:
            return root.left
        AvlNode* succ = root.right
        while succ.left != 0:
            succ = succ.left
        root.key = succ.key
        root.right = _avl_erase_rec(root.right, succ.key)
    return _avl_fix(root)

public def _avl_check(n AvlNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    int lc = 0
    int rc = 0
    int ok_l = _avl_check(n.left, &lc)
    int ok_r = _avl_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    int lh = _avl_height(n.left)
    int rh = _avl_height(n.right)
    int b = lh - rh
    if b > 1 or b < -1:
        return 0
    int ch = 1
    if lh >= rh:
        ch = lh + 1
    else:
        ch = rh + 1
    if ch != n.height:
        return 0
    *cnt = lc + rc + 1
    return 1

public def avl_contains(t AvlTree, key int) -> int:
    return _avl_contains_rec(t.root, key)

public def avl_insert(t AvlTree, key int) -> AvlTree:
    int present = _avl_contains_rec(t.root, key)
    if present == 1:
        return t
    t.root = _avl_insert_rec(t.root, key)
    t.size += (size_t)1
    return t

public def avl_erase(t AvlTree, key int) -> AvlTree:
    int present = _avl_contains_rec(t.root, key)
    if present == 0:
        return t
    t.root = _avl_erase_rec(t.root, key)
    if t.size > (size_t)0:
        t.size -= (size_t)1
    return t

# Smallest key (caller should check is_empty first).
public def avl_min(t AvlTree) -> int:
    AvlNode* cur = t.root
    AvlNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    if cur == 0:
        return 0
    return cur.key

# Largest key (caller should check is_empty first).
public def avl_max(t AvlTree) -> int:
    AvlNode* cur = t.root
    AvlNode* nxt = 0
    if cur != 0:
        nxt = cur.right
    while nxt != 0:
        cur = nxt
        nxt = cur.right
    if cur == 0:
        return 0
    return cur.key

public def avl_height(t AvlTree) -> int:
    return _avl_height(t.root)

public def avl_size(t AvlTree) -> size_t:
    return t.size

public def avl_is_empty(t AvlTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# 1 if the tree obeys the BST + AVL height/balance invariants.
public def avl_validate(t AvlTree) -> int:
    int cnt = 0
    return _avl_check(t.root, &cnt)