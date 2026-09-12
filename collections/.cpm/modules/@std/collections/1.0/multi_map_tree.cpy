import stdlib

# MultiMapTree: an ordered key -> multiple-values map backed by an AVL-balanced
# BST. Each distinct key is the anchor of a singly-linked chain of its values,
# so associations with the same key share one BST node while the key order stays
# sorted. put/contains/erase are O(log n + chain); iteration over keys is
# ascending. A duplicate put never replaces: it appends another value.
# Self-contained; structs are passed by value so callers write
# `m = tmulti_put(m, k, v)`.
# NOTE: the codegen cannot follow chained pointer fields; use (*child).field or
# locals.
struct TmmNode:
    TmmNode* left
    TmmNode* right
    TmmNode* next
    int key
    int value
    int height

struct MultiMapTree:
    TmmNode* root
    size_t size
    size_t distinct

public def create_multimap_tree() -> MultiMapTree:
    MultiMapTree m
    m.root = 0
    m.size = (size_t)0
    m.distinct = (size_t)0
    return m

public def _tmm_height(n TmmNode*) -> int:
    if n == 0:
        return 0
    return n.height

public def _tmm_update(n TmmNode*) -> void:
    int l = _tmm_height(n.left)
    int r = _tmm_height(n.right)
    if l >= r:
        n.height = l + 1
    else:
        n.height = r + 1

public def _tmm_rotate_right(y TmmNode*) -> TmmNode*:
    TmmNode* x = y.left
    y.left = x.right
    x.right = y
    _tmm_update(y)
    _tmm_update(x)
    return x

public def _tmm_rotate_left(x TmmNode*) -> TmmNode*:
    TmmNode* y = x.right
    x.right = y.left
    y.left = x
    _tmm_update(x)
    _tmm_update(y)
    return y

public def _tmm_fix(n TmmNode*) -> TmmNode*:
    _tmm_update(n)
    int b = _tmm_height(n.left) - _tmm_height(n.right)
    if b > 1:
        TmmNode* l = n.left
        if _tmm_height(l.right) > _tmm_height(l.left):
            n.left = _tmm_rotate_left(n.left)
        return _tmm_rotate_right(n)
    if b < -1:
        TmmNode* r = n.right
        if _tmm_height(r.left) > _tmm_height(r.right):
            n.right = _tmm_rotate_right(n.right)
        return _tmm_rotate_left(n)
    return n

public def _tmm_find(root TmmNode*, key int) -> TmmNode*:
    if root == 0:
        return root
    if key == root.key:
        return root
    if key < root.key:
        return _tmm_find(root.left, key)
    return _tmm_find(root.right, key)

# created is set to 1 when a brand-new key anchor was inserted.
public def _tmm_put_rec(root TmmNode*, key int, value int, created int*) -> TmmNode*:
    if root == 0:
        TmmNode* n = new TmmNode
        n.left = 0
        n.right = 0
        n.next = 0
        n.key = key
        n.value = value
        n.height = 1
        *created = 1
        return n
    if key < root.key:
        root.left = _tmm_put_rec(root.left, key, value, created)
        return _tmm_fix(root)
    if key > root.key:
        root.right = _tmm_put_rec(root.right, key, value, created)
        return _tmm_fix(root)
    # duplicate key: prepend a value node to this key's chain
    TmmNode* d = new TmmNode
    d.left = 0
    d.right = 0
    d.next = root.next
    d.key = key
    d.value = value
    d.height = 1
    root.next = d
    *created = 0
    return root

public def _tmm_find_min(n TmmNode*) -> TmmNode*:
    TmmNode* cur = n
    TmmNode* nxt = 0
    if cur != 0:
        nxt = cur.left
    while nxt != 0:
        cur = nxt
        nxt = cur.left
    return cur

# Erase the BST anchor node (and its whole chain). removed set if key existed.
public def _tmm_erase_key_rec(root TmmNode*, key int, removed int*) -> TmmNode*:
    if root == 0:
        return root
    if key < root.key:
        root.left = _tmm_erase_key_rec(root.left, key, removed)
        return _tmm_fix(root)
    if key > root.key:
        root.right = _tmm_erase_key_rec(root.right, key, removed)
        return _tmm_fix(root)
    *removed = 1
    if root.left == 0:
        return root.right
    if root.right == 0:
        return root.left
    TmmNode* succ = _tmm_find_min(root.right)
    root.key = succ.key
    root.value = succ.value
    root.next = succ.next
    root.right = _tmm_erase_key_rec(root.right, succ.key, removed)
    return _tmm_fix(root)

# Erase a single (key,value) association from the tree.
public def _tmm_erase_pair_rec(root TmmNode*, key int, value int, removed int*) -> TmmNode*:
    if root == 0:
        return root
    if key < root.key:
        root.left = _tmm_erase_pair_rec(root.left, key, value, removed)
        return _tmm_fix(root)
    if key > root.key:
        root.right = _tmm_erase_pair_rec(root.right, key, value, removed)
        return _tmm_fix(root)
    if root.value == value:
        if root.next == 0:
            # last value for this key: remove the anchor node entirely
            *removed = 1
            if root.left == 0:
                return root.right
            if root.right == 0:
                return root.left
            TmmNode* succ = _tmm_find_min(root.right)
            root.key = succ.key
            root.value = succ.value
            root.next = succ.next
            root.right = _tmm_erase_key_rec(root.right, succ.key, removed)
            return _tmm_fix(root)
        # promote a chain value into the anchor
        TmmNode* nx = root.next
        root.value = nx.value
        root.next = nx.next
        *removed = 1
        return root
    # search this key's chain
    TmmNode* prev = root
    TmmNode* cur = root.next
    while cur != 0:
        if cur.value == value:
            prev.next = cur.next
            *removed = 1
            return root
        prev = cur
        cur = cur.next
    return root

public def _tmm_count_chain(n TmmNode*) -> size_t:
    size_t c = (size_t)0
    TmmNode* cur = n
    while cur != 0:
        c += (size_t)1
        cur = cur.next
    return c

public def _tmm_check(n TmmNode*, cnt int*, dist int*) -> int:
    if n == 0:
        *cnt = 0
        *dist = 0
        return 1
    if n.left != 0 and (*n.left).key >= n.key:
        return 0
    if n.right != 0 and (*n.right).key <= n.key:
        return 0
    int lc = 0
    int rc = 0
    int ld = 0
    int rd = 0
    int ok_l = _tmm_check(n.left, &lc, &ld)
    int ok_r = _tmm_check(n.right, &rc, &rd)
    if ok_l == 0 or ok_r == 0:
        return 0
    int lh = _tmm_height(n.left)
    int rh = _tmm_height(n.right)
    if lh - rh > 1 or rh - lh > 1:
        return 0
    int want = 1
    if lh >= rh:
        want = lh + 1
    else:
        want = rh + 1
    if want != n.height:
        return 0
    *cnt = lc + rc + 1 + (int)_tmm_count_chain(n.next)
    *dist = ld + rd + 1
    return 1

public def tmulti_put(m MultiMapTree, key int, value int) -> MultiMapTree:
    int created = 0
    m.root = _tmm_put_rec(m.root, key, value, &created)
    m.size += (size_t)1
    if created == 1:
        m.distinct += (size_t)1
    return m

public def tmulti_contains(m MultiMapTree, key int) -> int:
    TmmNode* n = _tmm_find(m.root, key)
    if n == 0:
        return 0
    return 1

public def tmulti_contains_pair(m MultiMapTree, key int, value int) -> int:
    TmmNode* n = _tmm_find(m.root, key)
    while n != 0:
        if n.value == value:
            return 1
        n = n.next
    return 0

public def tmulti_count(m MultiMapTree, key int) -> size_t:
    TmmNode* n = _tmm_find(m.root, key)
    return _tmm_count_chain(n)

public def tmulti_get(m MultiMapTree, key int) -> int:
    TmmNode* n = _tmm_find(m.root, key)
    if n == 0:
        return 0
    return n.value

# value at index `idx` within a key's value chain (0-based)
public def tmulti_get_at(m MultiMapTree, key int, idx size_t) -> int:
    TmmNode* n = _tmm_find(m.root, key)
    size_t i = (size_t)0
    while n != 0:
        if i == idx:
            return n.value
        i += (size_t)1
        n = n.next
    return 0

public def tmulti_erase(m MultiMapTree, key int, value int) -> MultiMapTree:
    int removed = 0
    m.root = _tmm_erase_pair_rec(m.root, key, value, &removed)
    if removed == 1:
        if m.size > (size_t)0:
            m.size -= (size_t)1
        if tmulti_count(m, key) == (size_t)0 and m.distinct > (size_t)0:
            m.distinct -= (size_t)1
    return m

public def tmulti_erase_key(m MultiMapTree, key int) -> MultiMapTree:
    int removed = 0
    if _tmm_find(m.root, key) == 0:
        return m
    size_t gone = _tmm_count_chain(_tmm_find(m.root, key))
    m.root = _tmm_erase_key_rec(m.root, key, &removed)
    if gone <= m.size:
        m.size -= gone
    if removed == 1 and m.distinct > (size_t)0:
        m.distinct -= (size_t)1
    return m

public def tmulti_size(m MultiMapTree) -> size_t:
    return m.size

public def tmulti_distinct(m MultiMapTree) -> size_t:
    return m.distinct

public def tmulti_is_empty(m MultiMapTree) -> int:
    int e = 0
    if m.size == (size_t)0:
        e = 1
    return e

public def tmulti_validate(m MultiMapTree) -> int:
    int cnt = 0
    int dist = 0
    int ok = _tmm_check(m.root, &cnt, &dist)
    if ok == 0:
        return 0
    if (size_t)cnt != m.size:
        return 0
    if (size_t)dist != m.distinct:
        return 0
    return 1