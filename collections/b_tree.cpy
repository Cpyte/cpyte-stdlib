import stdlib

# BTree: an order-4 B-tree (minimum degree t = 2), CLRS-style. Every node
# holds up to 3 keys / 4 children; internal nodes hold nkeys+1 children; all
# leaves sit at the same depth. Supports insert / erase / contains in O(log n).
# Duplicate keys are rejected.
# Nodes are heap-allocated; the BTree struct is passed by value, so mutators
# return the updated container: `t = btree_insert(t, k)`.
# NOTE: the codegen cannot follow chained pointer fields and cannot subscript
# a pointer-to-pointer struct field directly; child arrays are stored as void*
# and re-cast to a local BNode** (c) before indexing, so write `c[i]`.
struct BNode:
    void* child
    int* keys
    int nkeys
    int leaf

struct BTree:
    BNode* root
    size_t size

public def create_btree() -> BTree:
    BTree t
    t.root = 0
    t.size = (size_t)0
    return t

public def _bnode_create(leaf int) -> BNode*:
    size_t kcap = (size_t)3
    size_t ccap = (size_t)4
    BNode* n = new BNode
    n.keys = malloc(kcap * (size_t)sizeof(int))
    n.child = malloc(ccap * (size_t)sizeof(void*))
    n.nkeys = 0
    n.leaf = leaf
    BNode** c = (BNode**)n.child
    int i = 0
    while i < 4:
        c[i] = 0
        i = i + 1
    i = 0
    while i < 3:
        n.keys[i] = 0
        i = i + 1
    return n

public def _bnode_search(x BNode*, key int) -> int:
    int i = 0
    while i < x.nkeys and key > x.keys[i]:
        i = i + 1
    if i < x.nkeys and key == x.keys[i]:
        return 1
    if x.leaf == 1:
        return 0
    BNode** c = (BNode**)x.child
    return _bnode_search(c[i], key)

# Splits the full child x.child[i] (3 keys) into two 1-key nodes, promoting the
# middle key into x.
public def _bnode_split_child(x BNode*, i int) -> void:
    BNode** cx = (BNode**)x.child
    BNode* y = cx[i]
    BNode* z = _bnode_create(y.leaf)
    BNode** cy = (BNode**)y.child
    BNode** cz = (BNode**)z.child
    int mid = y.keys[1]
    z.keys[0] = y.keys[2]
    z.nkeys = 1
    if y.leaf == 0:
        cz[0] = cy[2]
        cz[1] = cy[3]
    y.nkeys = 1
    int j = x.nkeys
    while j > i:
        x.keys[j] = x.keys[j - 1]
        cx[j + 1] = cx[j]
        j = j - 1
    x.keys[i] = mid
    cx[i + 1] = z
    x.nkeys = x.nkeys + 1

public def _bnode_insert_nonfull(x BNode*, key int, inserted int*) -> void:
    int i = x.nkeys - 1
    if x.leaf == 1:
        while i >= 0 and key < x.keys[i]:
            x.keys[i + 1] = x.keys[i]
            i = i - 1
        x.keys[i + 1] = key
        x.nkeys = x.nkeys + 1
        *inserted = 1
    else:
        while i >= 0 and key < x.keys[i]:
            i = i - 1
        i = i + 1
        BNode** c = (BNode**)x.child
        if (*c[i]).nkeys == 3:
            _bnode_split_child(x, i)
            if key > x.keys[i]:
                i = i + 1
        _bnode_insert_nonfull(c[i], key, inserted)

public def btree_contains(t BTree, key int) -> int:
    if t.root == 0:
        return 0
    return _bnode_search(t.root, key)

public def btree_insert(t BTree, key int) -> BTree:
    if btree_contains(t, key) == 1:
        return t
    if t.root == 0:
        BNode* r = _bnode_create(1)
        r.keys[0] = key
        r.nkeys = 1
        t.root = r
        t.size = (size_t)1
        return t
    BNode* r = t.root
    if r.nkeys == 3:
        BNode* s = _bnode_create(0)
        BNode** cs = (BNode**)s.child
        cs[0] = r
        _bnode_split_child(s, 0)
        t.root = s
    int inserted = 0
    _bnode_insert_nonfull(t.root, key, &inserted)
    if inserted == 1:
        t.size += (size_t)1
    return t

public def _bnode_find_key(x BNode*, key int) -> int:
    int i = 0
    while i < x.nkeys and x.keys[i] < key:
        i = i + 1
    return i

public def _bnode_pred_key(x BNode*, idx int) -> int:
    BNode** c = (BNode**)x.child
    BNode* y = c[idx]
    while y.leaf == 0:
        BNode** cy = (BNode**)y.child
        y = cy[y.nkeys]
    return y.keys[y.nkeys - 1]

public def _bnode_succ_key(x BNode*, idx int) -> int:
    BNode** c = (BNode**)x.child
    BNode* y = c[idx + 1]
    while y.leaf == 0:
        BNode** cy = (BNode**)y.child
        y = cy[0]
    return y.keys[0]

# Merges child i+1 into child i, demoting x.keys[i] between them.
public def _bnode_merge(x BNode*, i int) -> void:
    BNode** cx = (BNode**)x.child
    BNode* y = cx[i]
    BNode* z = cx[i + 1]
    BNode** cy = (BNode**)y.child
    BNode** cz = (BNode**)z.child
    y.keys[y.nkeys] = x.keys[i]
    if y.leaf == 0:
        cy[y.nkeys + 1] = cz[0]
    int j = 0
    while j < z.nkeys:
        y.keys[y.nkeys + 1 + j] = z.keys[j]
        if y.leaf == 0:
            cy[y.nkeys + 2 + j] = cz[j + 1]
        j = j + 1
    y.nkeys = y.nkeys + 1 + z.nkeys
    j = i
    while j < x.nkeys - 1:
        x.keys[j] = x.keys[j + 1]
        cx[j + 1] = cx[j + 2]
        j = j + 1
    x.nkeys = x.nkeys - 1

# Borrows the largest key from child i-1 into child i.
public def _bnode_borrow_left(x BNode*, i int) -> void:
    BNode** cx = (BNode**)x.child
    BNode* y = cx[i - 1]
    BNode* z = cx[i]
    BNode** cy = (BNode**)y.child
    BNode** cz = (BNode**)z.child
    z.keys[1] = z.keys[0]
    cz[2] = cz[1]
    cz[1] = cz[0]
    z.keys[0] = x.keys[i - 1]
    if y.leaf == 0:
        cz[0] = cy[y.nkeys]
    x.keys[i - 1] = y.keys[y.nkeys - 1]
    z.nkeys = z.nkeys + 1
    y.nkeys = y.nkeys - 1

# Borrows the smallest key from child i+1 into child i.
public def _bnode_borrow_right(x BNode*, i int) -> void:
    BNode** cx = (BNode**)x.child
    BNode* z = cx[i]
    BNode* y = cx[i + 1]
    BNode** cz = (BNode**)z.child
    BNode** cy = (BNode**)y.child
    int oldy = y.nkeys
    z.keys[z.nkeys] = x.keys[i]
    if y.leaf == 0:
        cz[z.nkeys + 1] = cy[0]
    x.keys[i] = y.keys[0]
    int j = 0
    while j < oldy - 1:
        y.keys[j] = y.keys[j + 1]
        j = j + 1
    if y.leaf == 0:
        j = 0
        while j < oldy:
            cy[j] = cy[j + 1]
            j = j + 1
    y.nkeys = oldy - 1
    z.nkeys = z.nkeys + 1

public def _bnode_delete_key(x BNode*, key int, found int*) -> void:
    int idx = _bnode_find_key(x, key)
    if idx < x.nkeys and x.keys[idx] == key:
        *found = 1
        if x.leaf == 1:
            int j = idx
            while j < x.nkeys - 1:
                x.keys[j] = x.keys[j + 1]
                j = j + 1
            x.nkeys = x.nkeys - 1
        else:
            BNode** cx = (BNode**)x.child
            BNode* y = cx[idx]
            BNode* z = cx[idx + 1]
            if y.nkeys >= 2:
                int pk = _bnode_pred_key(x, idx)
                x.keys[idx] = pk
                _bnode_delete_key(y, pk, found)
            elif z.nkeys >= 2:
                int sk = _bnode_succ_key(x, idx)
                x.keys[idx] = sk
                _bnode_delete_key(z, sk, found)
            else:
                _bnode_merge(x, idx)
                BNode** cx2 = (BNode**)x.child
                _bnode_delete_key(cx2[idx], key, found)
    else:
        if x.leaf == 1:
            return
        int cidx = idx
        BNode** cx = (BNode**)x.child
        BNode* y = cx[cidx]
        if y.nkeys == 1:
            if cidx > 0:
                BNode* ls = cx[cidx - 1]
                if ls.nkeys >= 2:
                    _bnode_borrow_left(x, cidx)
                else:
                    _bnode_merge(x, cidx - 1)
                    y = cx[cidx - 1]
            elif cidx < x.nkeys:
                BNode* rs = cx[cidx + 1]
                if rs.nkeys >= 2:
                    _bnode_borrow_right(x, cidx)
                else:
                    _bnode_merge(x, cidx)
                    y = cx[cidx]
        _bnode_delete_key(y, key, found)

public def btree_erase(t BTree, key int) -> BTree:
    int found = 0
    if t.root != 0:
        _bnode_delete_key(t.root, key, &found)
        BNode* r = t.root
        if r.nkeys == 0:
            if r.leaf == 1:
                t.root = 0
            else:
                BNode** cr = (BNode**)r.child
                t.root = cr[0]
        if found == 1:
            if t.size > (size_t)0:
                t.size -= (size_t)1
    return t

public def _bnode_min(n BNode*) -> BNode*:
    BNode* cur = n
    BNode* nxt = 0
    if cur != 0:
        BNode** cc = (BNode**)cur.child
        nxt = cc[0]
    while nxt != 0:
        cur = nxt
        BNode** cc = (BNode**)cur.child
        nxt = cc[0]
    return cur

public def _bnode_max(n BNode*) -> BNode*:
    BNode* cur = n
    BNode** cc = (BNode**)cur.child
    while cur.leaf == 0:
        cc = (BNode**)cur.child
        cur = cc[cur.nkeys]
    return cur

public def btree_min(t BTree) -> int:
    BNode* n = _bnode_min(t.root)
    if n == 0:
        return 0
    return n.keys[0]

public def btree_max(t BTree) -> int:
    BNode* n = _bnode_max(t.root)
    if n == 0:
        return 0
    return n.keys[n.nkeys - 1]

public def btree_size(t BTree) -> size_t:
    return t.size

public def btree_is_empty(t BTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

public def _bnode_inorder(x BNode*, last int*, first int*, kcnt int*) -> int:
    if x.leaf == 1:
        int i = 0
        while i < x.nkeys:
            *kcnt = *kcnt + 1
            if *first == 1:
                if x.keys[i] <= *last:
                    return 0
            *last = x.keys[i]
            *first = 1
            i = i + 1
        return 1
    int i = 0
    BNode** c = (BNode**)x.child
    while i < x.nkeys:
        if _bnode_inorder(c[i], last, first, kcnt) == 0:
            return 0
        *kcnt = *kcnt + 1
        if *first == 1:
            if x.keys[i] <= *last:
                return 0
        *last = x.keys[i]
        *first = 1
        i = i + 1
    return _bnode_inorder(c[x.nkeys], last, first, kcnt)

public def _bnode_check(x BNode*, leafdepth int*, d int, cnt int*) -> int:
    *cnt = *cnt + 1
    if x.leaf == 1:
        if *leafdepth == -1:
            *leafdepth = d
        if d != *leafdepth:
            return 0
        return 1
    if x.nkeys < 1 or x.nkeys > 3:
        return 0
    int i = 0
    while i < x.nkeys - 1:
        if x.keys[i] > x.keys[i + 1]:
            return 0
        i = i + 1
    BNode** c = (BNode**)x.child
    i = 0
    while i < x.nkeys + 1:
        if c[i] == 0:
            return 0
        if _bnode_check(c[i], leafdepth, d + 1, cnt) == 0:
            return 0
        i = i + 1
    return 1

public def btree_validate(t BTree) -> int:
    if t.root == 0:
        if t.size == (size_t)0:
            return 1
        return 0
    int leafdepth = -1
    int cnt = 0
    int ok = _bnode_check(t.root, &leafdepth, 0, &cnt)
    if ok == 0:
        return 0
    int last = 0
    int first = 0
    int kcnt = 0
    int ok2 = _bnode_inorder(t.root, &last, &first, &kcnt)
    if ok2 == 0:
        return 0
    if (size_t)kcnt != t.size:
        return 0
    return 1