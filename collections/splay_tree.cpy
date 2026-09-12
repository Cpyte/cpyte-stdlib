import stdlib

# SplayTree: a BST that moves every accessed key to the root via splay
# rotations (zig, zig-zig, zig-zag), giving amortized O(log n) access. Great
# for frequently-accessed keys. Nodes carry parent links for bottom-up splay.
# Self-contained; structs are passed by value so callers write
# `t = splay_insert(t, k)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field.
struct SplNode:
    SplNode* left
    SplNode* right
    SplNode* parent
    int key

struct SplayTree:
    SplNode* root
    size_t size

public def create_splaytree() -> SplayTree:
    SplayTree t
    t.root = 0
    t.size = (size_t)0
    return t

# Rotate x up over its parent; returns the new whole-tree root.
public def _spl_rot(x SplNode*, root SplNode*) -> SplNode*:
    SplNode* p = x.parent
    if p == 0:
        return root
    if x == p.left:
        p.left = x.right
        if x.right != 0:
            (*x.right).parent = p
        x.parent = p.parent
        if p.parent != 0:
            if p == (*p.parent).left:
                (*p.parent).left = x
            else:
                (*p.parent).right = x
        x.right = p
        p.parent = x
    else:
        p.right = x.left
        if x.left != 0:
            (*x.left).parent = p
        x.parent = p.parent
        if p.parent != 0:
            if p == (*p.parent).left:
                (*p.parent).left = x
            else:
                (*p.parent).right = x
        x.left = p
        p.parent = x
    if x.parent == 0:
        return x
    return root

# Bottom-up splay: brings x to the root of `root`.
public def _spl_splay(root SplNode*, x SplNode*) -> SplNode*:
    while x.parent != 0:
        SplNode* p = x.parent
        SplNode* g = p.parent
        if g == 0:
            root = _spl_rot(x, root)
        else:
            if (p == g.left and x == p.left) or (p == g.right and x == p.right):
                root = _spl_rot(p, root)
                root = _spl_rot(x, root)
            else:
                root = _spl_rot(x, root)
                root = _spl_rot(x, root)
    return root

public def _spl_insert_do(root SplNode*, key int, created int*) -> SplNode*:
    SplNode* z = new SplNode
    z.left = 0
    z.right = 0
    z.parent = 0
    z.key = key
    SplNode* y = 0
    SplNode* x = root
    while x != 0:
        y = x
        if key < x.key:
            x = x.left
        elif key > x.key:
            x = x.right
        else:
            *created = 0
            root = _spl_splay(root, x)
            return root
    if y == 0:
        root = z
    elif z.key < y.key:
        y.left = z
        z.parent = y
    else:
        y.right = z
        z.parent = y
    *created = 1
    root = _spl_splay(root, z)
    return root

# Search for key; splays the found node, or the last examined node when absent.
public def _spl_find_splay(root SplNode*, key int) -> SplNode*:
    SplNode* x = root
    SplNode* last = 0
    while x != 0:
        last = x
        if key == x.key:
            return _spl_splay(root, x)
        if key < x.key:
            x = x.left
        else:
            x = x.right
    if last != 0:
        return _spl_splay(root, last)
    return root

public def _spl_find_max(n SplNode*) -> SplNode*:
    SplNode* x = n
    while x.right != 0:
        x = x.right
    return x

public def _spl_find_min(n SplNode*) -> SplNode*:
    SplNode* x = n
    while x.left != 0:
        x = x.left
    return x

public def _spl_erase_do(root SplNode*, key int, removed int*) -> SplNode*:
    root = _spl_find_splay(root, key)
    if root == 0:
        *removed = 0
        return root
    if root.key != key:
        *removed = 0
        return root
    *removed = 1
    if root.left == 0:
        SplNode* nr = root.right
        if nr != 0:
            nr.parent = 0
        return nr
    if root.right == 0:
        SplNode* nl = root.left
        nl.parent = 0
        return nl
    SplNode* lmax = _spl_find_max(root.left)
    SplNode* left_root = _spl_splay(root.left, lmax)
    left_root.right = root.right
    (*root.right).parent = left_root
    left_root.parent = 0
    return left_root


public def splay_insert(t SplayTree, key int) -> SplayTree:
    int created = 0
    t.root = _spl_insert_do(t.root, key, &created)
    if created == 1:
        t.size += (size_t)1
    return t

# Non-mutating membership test: does NOT splay (use splay_find to bucket the
# key at the root).
public def splay_contains(t SplayTree, key int) -> int:
    SplNode* x = t.root
    while x != 0:
        if key == x.key:
            return 1
        if key < x.key:
            x = x.left
        else:
            x = x.right
    return 0

# Mutating look-up: splays `key` (or the last node on the search path) to the
# root and returns the updated tree. Check `splay_find_contains` on the result.
public def splay_find(t SplayTree, key int) -> SplayTree:
    t.root = _spl_find_splay(t.root, key)
    return t

public def splay_erase(t SplayTree, key int) -> SplayTree:
    int removed = 0
    t.root = _spl_erase_do(t.root, key, &removed)
    if removed == 1:
        if t.size > (size_t)0:
            t.size -= (size_t)1
    return t

public def splay_size(t SplayTree) -> size_t:
    return t.size

public def splay_is_empty(t SplayTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# Smallest key (caller should check is_empty first).
public def splay_min(t SplayTree) -> int:
    if t.root == 0:
        return 0
    SplNode* m = _spl_find_min(t.root)
    return m.key

# Largest key (caller should check is_empty first).
public def splay_max(t SplayTree) -> int:
    if t.root == 0:
        return 0
    SplNode* m = _spl_find_max(t.root)
    return m.key

public def _spl_check(n SplNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    if n.left != 0 and (*n.left).parent != n:
        return 0
    if n.right != 0 and (*n.right).parent != n:
        return 0
    int lc = 0
    int rc = 0
    int ok_l = _spl_check(n.left, &lc)
    int ok_r = _spl_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    *cnt = lc + rc + 1
    return 1

public def splay_validate(t SplayTree) -> int:
    if t.root == 0:
        return 1
    if (*t.root).parent != 0:
        return 0
    int cnt = 0
    int ok = _spl_check(t.root, &cnt)
    if ok == 0:
        return 0
    if (size_t)cnt != t.size:
        return 0
    return 1