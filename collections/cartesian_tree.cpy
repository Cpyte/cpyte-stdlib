import stdlib

# CartesianTree: the min-heap tree with the property that an in-order walk
# yields the original array order. Built in O(n) from an int array using a
# monotonic stack. Root holds the global minimum; useful as the basis for RMQ
# via LCA. Built via build_cartesian(arr, n); the resulting Cartesian struct
# owns the nodes.
# Struct is passed by value; build returns a fresh container.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field.
struct CartNode:
    CartNode* left
    CartNode* right
    CartNode* parent
    int value

struct Cartesian:
    CartNode* root
    size_t size

public def create_cartesian() -> Cartesian:
    Cartesian t
    t.root = 0
    t.size = (size_t)0
    return t

# Builds the min cartesian tree for arr[0..n-1].
public def build_cartesian(arr int*, n size_t) -> Cartesian:
    Cartesian t = create_cartesian()
    if n == (size_t)0:
        return t
    void* raw = malloc(n * (size_t)sizeof(void*))
    CartNode** st = (CartNode**)raw
    int top = 0
    int i = 0
    while i < (int)n:
        CartNode* cur = new CartNode
        cur.left = 0
        cur.right = 0
        cur.parent = 0
        cur.value = arr[i]
        CartNode* last = 0
        while top > 0:
            CartNode* tp = st[top - 1]
            if tp.value < cur.value:
                break
            last = tp
            top -= 1
        if top > 0:
            CartNode* p = st[top - 1]
            p.right = cur
            cur.parent = p
        if last != 0:
            cur.left = last
            last.parent = cur
        st[top] = cur
        top += 1
        i += 1
    t.root = st[0]
    t.size = n
    return t

# Global minimum value (root of a min cartesian tree; check is_empty first).
public def cart_min(t Cartesian) -> int:
    CartNode* r = t.root
    if r == 0:
        return 0
    return r.value

public def cart_size(t Cartesian) -> size_t:
    return t.size

public def cart_is_empty(t Cartesian) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

public def _cart_hgt(n CartNode*) -> int:
    if n == 0:
        return 0
    int lh = _cart_hgt(n.left)
    int rh = _cart_hgt(n.right)
    if lh >= rh:
        return lh + 1
    return rh + 1

public def cart_height(t Cartesian) -> int:
    return _cart_hgt(t.root)

public def _cart_contains_rec(n CartNode*, v int) -> int:
    if n == 0:
        return 0
    if n.value == v:
        return 1
    return _cart_contains_rec(n.left, v) + _cart_contains_rec(n.right, v)

# Membership scan (cartesian trees are not ordered by value).
public def cart_contains(t Cartesian, v int) -> int:
    int c = _cart_contains_rec(t.root, v)
    if c > 0:
        return 1
    return 0

public def _cart_check(n CartNode*, cnt int*) -> int:
    if n == 0:
        *cnt = 0
        return 1
    if n.left != 0:
        if (*n.left).parent != n:
            return 0
        if (*n.left).value < n.value:
            return 0
    if n.right != 0:
        if (*n.right).parent != n:
            return 0
        if (*n.right).value < n.value:
            return 0
    int lc = 0
    int rc = 0
    int ok_l = _cart_check(n.left, &lc)
    int ok_r = _cart_check(n.right, &rc)
    if ok_l == 0 or ok_r == 0:
        return 0
    *cnt = lc + rc + 1
    return 1

public def cart_validate(t Cartesian) -> int:
    if t.size == (size_t)0:
        if t.root == 0:
            return 1
        return 0
    if t.root == 0:
        return 0
    CartNode* r = t.root
    if r.parent != 0:
        return 0
    int cnt = 0
    int ok = _cart_check(t.root, &cnt)
    if ok == 0:
        return 0
    if (size_t)cnt != t.size:
        return 0
    return 1