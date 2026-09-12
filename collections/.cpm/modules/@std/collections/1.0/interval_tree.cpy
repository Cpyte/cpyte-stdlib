import stdlib

# IntervalTree: augmented AVL tree keyed by [lo, hi] intervals. Each node
# caches `maxh` = largest interval endpoint in its subtree, which lets stabbing
# / overlap queries prune whole branches (O(log n + m) to report, O(log n) for
# a yes/no overlap check). Duplicates (same lo and hi) are rejected; intervals
# sharing a lo (but different hi) are fine.
# Structs are passed by value; mutators return the updated container, so write
# `t = interval_insert(t, lo, hi)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field.
struct IntNode:
    IntNode* left
    IntNode* right
    int lo
    int hi
    int hgt
    int maxh

struct IntervalTree:
    IntNode* root
    size_t size

public def create_interval_tree() -> IntervalTree:
    IntervalTree t
    t.root = 0
    t.size = (size_t)0
    return t

public def _it_new(lo int, hi int) -> IntNode*:
    IntNode* n = new IntNode
    n.left = 0
    n.right = 0
    n.lo = lo
    n.hi = hi
    n.hgt = 1
    n.maxh = hi
    return n

public def _it_hgt(n IntNode*) -> int:
    if n == 0:
        return 0
    return n.hgt

public def _it_maxh(n IntNode*) -> int:
    if n == 0:
        return 0
    return n.maxh

public def _it_bal(n IntNode*) -> int:
    return _it_hgt(n.left) - _it_hgt(n.right)

public def _it_upd(n IntNode*) -> void:
    int lh = _it_hgt(n.left)
    int rh = _it_hgt(n.right)
    if lh >= rh:
        n.hgt = lh + 1
    else:
        n.hgt = rh + 1
    int mr = _it_maxh(n.right)
    int ml = _it_maxh(n.left)
    int m1 = 0
    if ml >= mr:
        m1 = ml
    else:
        m1 = mr
    if n.hi >= m1:
        n.maxh = n.hi
    else:
        n.maxh = m1

public def _it_rotr(y IntNode*) -> IntNode*:
    IntNode* x = y.left
    y.left = x.right
    x.right = y
    _it_upd(y)
    _it_upd(x)
    return x

public def _it_rotl(x IntNode*) -> IntNode*:
    IntNode* y = x.right
    x.right = y.left
    y.left = x
    _it_upd(x)
    _it_upd(y)
    return y

public def _it_balance(root IntNode*) -> IntNode*:
    if root == 0:
        return root
    _it_upd(root)
    int b = _it_bal(root)
    if b > 1:
        if _it_bal(root.left) < 0:
            root.left = _it_rotl(root.left)
        return _it_rotr(root)
    if b < -1:
        if _it_bal(root.right) > 0:
            root.right = _it_rotr(root.right)
        return _it_rotl(root)
    return root

public def _it_insert_rec(root IntNode*, lo int, hi int, created int*) -> IntNode*:
    if root == 0:
        *created = 1
        return _it_new(lo, hi)
    if lo == root.lo and hi == root.hi:
        *created = 0
        return root
    if lo < root.lo or (lo == root.lo and hi < root.hi):
        root.left = _it_insert_rec(root.left, lo, hi, created)
    else:
        root.right = _it_insert_rec(root.right, lo, hi, created)
    return _it_balance(root)

public def _it_find_min(n IntNode*) -> IntNode*:
    IntNode* cur = n
    IntNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    return cur

public def _it_find_max(n IntNode*) -> IntNode*:
    IntNode* cur = n
    IntNode* nxt = 0
    if cur != 0:
        nxt = cur.right
    while nxt != 0:
        cur = nxt
        nxt = cur.right
    return cur

public def _it_erase_rec(root IntNode*, lo int, hi int, found int*) -> IntNode*:
    if root == 0:
        return root
    if lo == root.lo and hi == root.hi:
        *found = 1
        if root.left == 0 and root.right == 0:
            return 0
        if root.left == 0:
            return root.right
        if root.right == 0:
            return root.left
        IntNode* succ = _it_find_min(root.right)
        root.lo = succ.lo
        root.hi = succ.hi
        root.right = _it_erase_rec(root.right, succ.lo, succ.hi, found)
        return _it_balance(root)
    if lo < root.lo or (lo == root.lo and hi < root.hi):
        root.left = _it_erase_rec(root.left, lo, hi, found)
    else:
        root.right = _it_erase_rec(root.right, lo, hi, found)
    return _it_balance(root)

# 1 if any stored interval intersects [lo, hi].
public def _it_overlap_rec(n IntNode*, lo int, hi int) -> int:
    if n == 0:
        return 0
    if _it_maxh(n) < lo:
        return 0
    int hit = 0
    if n.lo <= hi and n.hi >= lo:
        hit = 1
    if hit == 1:
        return 1
    if n.left != 0:
        if _it_maxh(n.left) >= lo:
            if _it_overlap_rec(n.left, lo, hi) == 1:
                return 1
    return _it_overlap_rec(n.right, lo, hi)

# 1 if any stored interval contains point x.
public def _it_stab_rec(n IntNode*, x int) -> int:
    if n == 0:
        return 0
    if _it_maxh(n) < x:
        return 0
    if n.lo <= x and n.hi >= x:
        return 1
    if n.left != 0:
        if _it_maxh(n.left) >= x:
            if _it_stab_rec(n.left, x) == 1:
                return 1
    return _it_stab_rec(n.right, x)

public def _it_check(n IntNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0:
        if (*n.left).lo > n.lo:
            return 0
        if (*n.left).lo == n.lo and (*n.left).hi >= n.hi:
            return 0
    if n.right != 0:
        if (*n.right).lo < n.lo:
            return 0
        if (*n.right).lo == n.lo and (*n.right).hi <= n.hi:
            return 0
    int lh = _it_hgt(n.left)
    int rh = _it_hgt(n.right)
    int d = lh - rh
    if d > 1 or d < -1:
        return 0
    int ex = _it_maxh(n.left)
    int ey = _it_maxh(n.right)
    int em = 0
    if ex >= ey:
        em = ex
    else:
        em = ey
    int exp = 0
    if n.hi >= em:
        exp = n.hi
    else:
        exp = em
    if exp != n.maxh:
        return 0
    int lc = 0
    int rc = 0
    int ok_l = _it_check(n.left, &lc)
    int ok_r = _it_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    *cnt = lc + rc + 1
    return 1

public def interval_insert(t IntervalTree, lo int, hi int) -> IntervalTree:
    int created = 0
    t.root = _it_insert_rec(t.root, lo, hi, &created)
    if created == 1:
        t.size += (size_t)1
    return t

public def interval_erase(t IntervalTree, lo int, hi int) -> IntervalTree:
    int found = 0
    t.root = _it_erase_rec(t.root, lo, hi, &found)
    if found == 1:
        if t.size > (size_t)0:
            t.size -= (size_t)1
    return t

# 1 if some stored interval intersects [lo, hi].
public def interval_overlap(t IntervalTree, lo int, hi int) -> int:
    return _it_overlap_rec(t.root, lo, hi)

# 1 if some stored interval covers point x.
public def interval_contains_point(t IntervalTree, x int) -> int:
    return _it_stab_rec(t.root, x)

public def interval_size(t IntervalTree) -> size_t:
    return t.size

public def interval_is_empty(t IntervalTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# Smallest low endpoint (caller should check is_empty first).
public def interval_min_lo(t IntervalTree) -> int:
    IntNode* n = _it_find_min(t.root)
    if n == 0:
        return 0
    return n.lo

# Largest low endpoint (caller should check is_empty first).
public def interval_max_lo(t IntervalTree) -> int:
    IntNode* n = _it_find_max(t.root)
    if n == 0:
        return 0
    return n.lo

# Largest endpoint present in the whole tree (caller should check is_empty).
public def interval_max_hi(t IntervalTree) -> int:
    IntNode* r = t.root
    if r == 0:
        return 0
    return r.maxh

public def interval_validate(t IntervalTree) -> int:
    int cnt = 0
    int ok = _it_check(t.root, &cnt)
    if ok == 0:
        return 0
    if (size_t)cnt != t.size:
        return 0
    return 1