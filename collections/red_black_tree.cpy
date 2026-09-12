import stdlib

# RedBlackTree: self-balancing BST using red/black coloring (0 = red, 1 =
# black; null = black leaf). Guarantees height <= 2*log2(n+1). Implements CLRS
# insert with recolor+rotations and delete with the double-black (parent-
# tracked) fixup. Parent pointers are used for the fixups, so nodes carry
# left/right/parent links.
# Self-contained; structs are passed by value so callers write
# `t = rbt_insert(t, k)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field or
# locals.
struct RbtNode:
    RbtNode* left
    RbtNode* right
    RbtNode* parent
    int key
    int color

struct RedBlackTree:
    RbtNode* root
    size_t size

public def create_redblacktree() -> RedBlackTree:
    RedBlackTree t
    t.root = 0
    t.size = (size_t)0
    return t

public def _rbt_is_red(n RbtNode*) -> int:
    if n == 0:
        return 0
    if n.color == 0:
        return 1
    return 0

public def _rbt_is_black(n RbtNode*) -> int:
    if n == 0:
        return 1
    if n.color == 1:
        return 1
    return 0

public def _rbt_rotate_left(x RbtNode*, root RbtNode*) -> RbtNode*:
    RbtNode* y = x.right
    x.right = y.left
    if y.left != 0:
        (*y.left).parent = x
    y.parent = x.parent
    if x.parent != 0:
        if x == (*x.parent).left:
            (*x.parent).left = y
        else:
            (*x.parent).right = y
    y.left = x
    x.parent = y
    if y.parent == 0:
        return y
    return root

public def _rbt_rotate_right(x RbtNode*, root RbtNode*) -> RbtNode*:
    RbtNode* y = x.left
    x.left = y.right
    if y.right != 0:
        (*y.right).parent = x
    y.parent = x.parent
    if x.parent != 0:
        if x == (*x.parent).left:
            (*x.parent).left = y
        else:
            (*x.parent).right = y
    y.right = x
    x.parent = y
    if y.parent == 0:
        return y
    return root

public def _rbt_insert_fixup(root RbtNode*, z RbtNode*) -> RbtNode*:
    while _rbt_is_red(z.parent):
        RbtNode* p = z.parent
        RbtNode* g = p.parent
        if p == g.left:
            RbtNode* u = g.right
            if _rbt_is_red(u):
                p.color = 1
                u.color = 1
                g.color = 0
                z = g
            else:
                if z == p.right:
                    z = p
                    root = _rbt_rotate_left(z, root)
                p = z.parent
                g = p.parent
                p.color = 1
                g.color = 0
                root = _rbt_rotate_right(g, root)
        else:
            RbtNode* u = g.left
            if _rbt_is_red(u):
                p.color = 1
                u.color = 1
                g.color = 0
                z = g
            else:
                if z == p.left:
                    z = p
                    root = _rbt_rotate_right(z, root)
                p = z.parent
                g = p.parent
                p.color = 1
                g.color = 0
                root = _rbt_rotate_left(g, root)
    root.color = 1
    return root

public def _rbt_insert_do(root RbtNode*, key int, created int*) -> RbtNode*:
    RbtNode* z = new RbtNode
    z.left = 0
    z.right = 0
    z.parent = 0
    z.key = key
    z.color = 0
    RbtNode* y = 0
    RbtNode* x = root
    while x != 0:
        y = x
        if key < x.key:
            x = x.left
        elif key > x.key:
            x = x.right
        else:
            *created = 0
            return root
    z.parent = y
    if y == 0:
        root = z
    elif z.key < y.key:
        y.left = z
    else:
        y.right = z
    *created = 1
    root = _rbt_insert_fixup(root, z)
    return root

public def _rbt_find(root RbtNode*, key int) -> RbtNode*:
    RbtNode* x = root
    while x != 0:
        if key == x.key:
            return x
        if key < x.key:
            x = x.left
        else:
            x = x.right
    return x

public def _rbt_find_min(n RbtNode*) -> RbtNode*:
    RbtNode* x = n
    while x.left != 0:
        x = x.left
    return x

public def _rbt_transplant(root RbtNode*, u RbtNode*, v RbtNode*) -> RbtNode*:
    if u.parent == 0:
        root = v
    elif u == (*u.parent).left:
        (*u.parent).left = v
    else:
        (*u.parent).right = v
    if v != 0:
        v.parent = u.parent
    return root

public def _rbt_delete_fixup(root RbtNode*, x RbtNode*, xp RbtNode*) -> RbtNode*:
    int loop = 1
    while loop == 1:
        if x == root:
            break
        if x != 0 and x.color == 0:
            x.color = 1
            break
        # x is doubly black (a black node or a null leaf): move it toward root
        RbtNode* p = xp
        if p == 0:
            break
        if x == p.left:
            RbtNode* w = p.right
            if w != 0 and w.color == 0:
                w.color = 1
                p.color = 0
                root = _rbt_rotate_left(p, root)
                w = p.right
            if w == 0 or ((w.left == 0 or (*w.left).color == 1) and (w.right == 0 or (*w.right).color == 1)):
                if w != 0:
                    w.color = 0
                x = p
                xp = p.parent
                if x != 0 and x.color == 0:
                    x.color = 1
                    break
            else:
                if w == 0 or w.right == 0 or (*w.right).color == 1:
                    if w != 0:
                        if w.left != 0:
                            (*w.left).color = 1
                        w.color = 0
                        root = _rbt_rotate_right(w, root)
                        w = p.right
                if w != 0:
                    w.color = p.color
                    if w.right != 0:
                        (*w.right).color = 1
                p.color = 1
                root = _rbt_rotate_left(p, root)
                break
        else:
            RbtNode* w = p.left
            if w != 0 and w.color == 0:
                w.color = 1
                p.color = 0
                root = _rbt_rotate_right(p, root)
                w = p.left
            if w == 0 or ((w.left == 0 or (*w.left).color == 1) and (w.right == 0 or (*w.right).color == 1)):
                if w != 0:
                    w.color = 0
                x = p
                xp = p.parent
                if x != 0 and x.color == 0:
                    x.color = 1
                    break
            else:
                if w == 0 or w.left == 0 or (*w.left).color == 1:
                    if w != 0:
                        if w.right != 0:
                            (*w.right).color = 1
                        w.color = 0
                        root = _rbt_rotate_left(w, root)
                        w = p.left
                if w != 0:
                    w.color = p.color
                    if w.left != 0:
                        (*w.left).color = 1
                p.color = 1
                root = _rbt_rotate_right(p, root)
                break
    if root != 0:
        root.color = 1
    return root

public def _rbt_delete_do(root RbtNode*, key int, removed int*) -> RbtNode*:
    RbtNode* z = _rbt_find(root, key)
    if z == 0:
        *removed = 0
        return root
    *removed = 1
    RbtNode* y = z
    RbtNode* x = 0
    RbtNode* xp = 0
    int y_orig = y.color
    if z.left == 0:
        x = z.right
        xp = z.parent
        root = _rbt_transplant(root, z, z.right)
    elif z.right == 0:
        x = z.left
        xp = z.parent
        root = _rbt_transplant(root, z, z.left)
    else:
        y = _rbt_find_min(z.right)
        y_orig = y.color
        x = y.right
        if y.parent == z:
            xp = y
            if x != 0:
                x.parent = y
        else:
            RbtNode* yp = y.parent
            xp = yp
            root = _rbt_transplant(root, y, y.right)
            y.right = z.right
            (*y.right).parent = y
        root = _rbt_transplant(root, z, y)
        y.left = z.left
        (*y.left).parent = y
        y.color = z.color
    if y_orig == 1:
        root = _rbt_delete_fixup(root, x, xp)
    root.color = 1
    return root

public def _rbt_check(n RbtNode*, bh int*, cnt int*) -> int:
    if n == 0:
        *bh = 1
        *cnt = 0
        return 1
    if n.color == 0:
        if _rbt_is_red(n.left):
            return 0
        if _rbt_is_red(n.right):
            return 0
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    if n.left != 0 and (*n.left).parent != n:
        return 0
    if n.right != 0 and (*n.right).parent != n:
        return 0
    int lh = 0
    int rh = 0
    int lc = 0
    int rc = 0
    int ok_l = _rbt_check(n.left, &lh, &lc)
    int ok_r = _rbt_check(n.right, &rh, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    if lh != rh:
        return 0
    if n.color == 1:
        *bh = lh + 1
    else:
        *bh = lh
    *cnt = lc + rc + 1
    return 1

public def rbt_insert(t RedBlackTree, key int) -> RedBlackTree:
    int created = 0
    t.root = _rbt_insert_do(t.root, key, &created)
    if created == 1:
        t.size += (size_t)1
    return t

public def rbt_contains(t RedBlackTree, key int) -> int:
    if _rbt_find(t.root, key) == 0:
        return 0
    return 1

public def rbt_erase(t RedBlackTree, key int) -> RedBlackTree:
    int removed = 0
    t.root = _rbt_delete_do(t.root, key, &removed)
    if removed == 1:
        if t.size > (size_t)0:
            t.size -= (size_t)1
    return t

public def rbt_size(t RedBlackTree) -> size_t:
    return t.size

public def rbt_is_empty(t RedBlackTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# Smallest key (caller should check is_empty first).
public def rbt_min(t RedBlackTree) -> int:
    if t.root == 0:
        return 0
    RbtNode* n = _rbt_find_min(t.root)
    return n.key

# Largest key (caller should check is_empty first).
public def rbt_max(t RedBlackTree) -> int:
    RbtNode* x = t.root
    while x != 0 and x.right != 0:
        x = x.right
    if x == 0:
        return 0
    return x.key

public def rbt_validate(t RedBlackTree) -> int:
    if t.root == 0:
        return 1
    if (*t.root).color != 1:
        return 0
    int bh = 0
    int cnt = 0
    int ok = _rbt_check(t.root, &bh, &cnt)
    if ok == 0:
        return 0
    if (size_t)cnt != t.size:
        return 0
    return 1