import stdlib

# BPlusTree: an order-4 B+ tree. All keys live in leaf nodes, chained via
# `next`; internal nodes only hold separator keys that guide lookups (copies of
# leaf values). Leaf depth is constant; leaves hold 1..3 keys (>= t-1), inner
# nodes 1..3 keys. Insert/erase/contains run in O(log n). Sorted iteration is
# a walk of the leaf chain. Duplicate keys are rejected.
# Invariant used here: for each internal node, keys in child i's subtree are
# all <= separator[i] <= keys in child i+1's subtree. Separators are copies, so
# a lookup key equal to a separator continues into the right subtree.
# Structs are passed by value; mutators return the updated container:
# `t = bpt_insert(t, k)`.
# NOTE: the codegen cannot follow chained pointer fields and cannot subscript
# a pointer-to-pointer struct field directly; child arrays are void* here,
# re-cast to a local BpNode** (c) before indexing, so write `c[i]`.
struct BpNode:
    void* child
    BpNode* next
    int* keys
    int nkeys
    int leaf

struct BPlusTree:
    BpNode* root
    size_t size

public def create_bptree() -> BPlusTree:
    BPlusTree t
    t.root = 0
    t.size = (size_t)0
    return t

public def _bp_create(leaf int) -> BpNode*:
    size_t kcap = (size_t)3
    size_t ccap = (size_t)4
    BpNode* n = new BpNode
    n.keys = malloc(kcap * (size_t)sizeof(int))
    n.child = malloc(ccap * (size_t)sizeof(void*))
    n.next = 0
    n.nkeys = 0
    n.leaf = leaf
    BpNode** c = (BpNode**)n.child
    int i = 0
    while i < 4:
        c[i] = 0
        i = i + 1
    i = 0
    while i < 3:
        n.keys[i] = 0
        i = i + 1
    return n

# Child index whose subtree might hold `key` (equal keys go right).
public def _bp_child_idx(x BpNode*, key int) -> int:
    int i = 0
    while i < x.nkeys and x.keys[i] <= key:
        i = i + 1
    return i

public def _bp_search(x BpNode*, key int) -> int:
    if x.leaf == 1:
        int i = 0
        while i < x.nkeys:
            if x.keys[i] == key:
                return 1
            i = i + 1
        return 0
    int cidx = _bp_child_idx(x, key)
    BpNode** c = (BpNode**)x.child
    return _bp_search(c[cidx], key)

# Splits a FULL leaf x (3 keys) into x (1 key) + a new leaf z (2 keys);
# updates the leaf chain. Caller reads z.keys[0] as the promoted separator.
public def _bp_split_leaf_full(x BpNode*) -> BpNode*:
    BpNode* z = _bp_create(1)
    z.keys[0] = x.keys[1]
    z.keys[1] = x.keys[2]
    z.nkeys = 2
    x.nkeys = 1
    z.next = x.next
    x.next = z
    return z

# Splits a FULL internal child x.child[i] (3 keys / 4 children) into two
# 1-key internal nodes, promoting the middle key into x.
public def _bp_split_child(x BpNode*, i int) -> void:
    BpNode** cx = (BpNode**)x.child
    BpNode* y = cx[i]
    BpNode* z = _bp_create(0)
    BpNode** cy = (BpNode**)y.child
    BpNode** cz = (BpNode**)z.child
    int mid = y.keys[1]
    z.keys[0] = y.keys[2]
    z.nkeys = 1
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

# x is a NON-FULL internal node; descends into the child holding `key` and
# inserts, pre-splitting a full child on the way down.
public def _bp_insert_nonfull(x BpNode*, key int, inserted int*) -> void:
    if x.leaf == 1:
        int i = 0
        while i < x.nkeys and x.keys[i] < key:
            i = i + 1
        int j = x.nkeys
        while j > i:
            x.keys[j] = x.keys[j - 1]
            j = j - 1
        x.keys[i] = key
        x.nkeys = x.nkeys + 1
        *inserted = 1
        return
    int i = _bp_child_idx(x, key)
    BpNode** cx = (BpNode**)x.child
    BpNode* c = cx[i]
    if c.nkeys == 3:
        if c.leaf == 1:
            BpNode* z = _bp_split_leaf_full(c)
            int pkey = z.keys[0]
            int j = x.nkeys
            while j > i:
                x.keys[j] = x.keys[j - 1]
                cx[j + 1] = cx[j]
                j = j - 1
            x.keys[i] = pkey
            cx[i + 1] = z
            x.nkeys = x.nkeys + 1
        else:
            _bp_split_child(x, i)
        if key >= x.keys[i]:
            i = i + 1
    _bp_insert_nonfull(cx[i], key, inserted)

public def bpt_contains(t BPlusTree, key int) -> int:
    if t.root == 0:
        return 0
    return _bp_search(t.root, key)

public def bpt_insert(t BPlusTree, key int) -> BPlusTree:
    if bpt_contains(t, key) == 1:
        return t
    if t.root == 0:
        BpNode* r = _bp_create(1)
        r.keys[0] = key
        r.nkeys = 1
        t.root = r
        t.size = (size_t)1
        return t
    BpNode* r = t.root
    if r.leaf == 1:
        if r.nkeys == 3:
            BpNode* z = _bp_split_leaf_full(r)
            BpNode* s = _bp_create(0)
            BpNode** cs = (BpNode**)s.child
            cs[0] = r
            cs[1] = z
            s.keys[0] = z.keys[0]
            s.nkeys = 1
            t.root = s
            int inserted = 0
            _bp_insert_nonfull(t.root, key, &inserted)
        else:
            int i = 0
            while i < r.nkeys and r.keys[i] < key:
                i = i + 1
            int j = r.nkeys
            while j > i:
                r.keys[j] = r.keys[j - 1]
                j = j - 1
            r.keys[i] = key
            r.nkeys = r.nkeys + 1
    else:
        if r.nkeys == 3:
            BpNode* s = _bp_create(0)
            BpNode** cs = (BpNode**)s.child
            cs[0] = r
            _bp_split_child(s, 0)
            t.root = s
        int inserted = 0
        _bp_insert_nonfull(t.root, key, &inserted)
    t.size += (size_t)1
    return t

# Merges child i+1 into child i, demoting x.keys[i] between them and updating
# the leaf chain when both are leaves.
public def _bp_merge(x BpNode*, i int) -> void:
    BpNode** cx = (BpNode**)x.child
    BpNode* y = cx[i]
    BpNode* z = cx[i + 1]
    BpNode** cy = (BpNode**)y.child
    BpNode** cz = (BpNode**)z.child
    if y.leaf == 1:
        int j = 0
        while j < z.nkeys:
            y.keys[y.nkeys + j] = z.keys[j]
            j = j + 1
        y.nkeys = y.nkeys + z.nkeys
        y.next = z.next
    else:
        y.keys[y.nkeys] = x.keys[i]
        cy[y.nkeys + 1] = cz[0]
        int j = 0
        while j < z.nkeys:
            y.keys[y.nkeys + 1 + j] = z.keys[j]
            cy[y.nkeys + 2 + j] = cz[j + 1]
            j = j + 1
        y.nkeys = y.nkeys + 1 + z.nkeys
    int j = i
    while j < x.nkeys - 1:
        x.keys[j] = x.keys[j + 1]
        cx[j + 1] = cx[j + 2]
        j = j + 1
    x.nkeys = x.nkeys - 1

# Borrows the largest entry from child i-1 into child i (both leaves or both
# internal); the parent separator is refreshed from the moved entry.
public def _bp_borrow_left(x BpNode*, i int) -> void:
    BpNode** cx = (BpNode**)x.child
    BpNode* y = cx[i - 1]
    BpNode* z = cx[i]
    BpNode** cy = (BpNode**)y.child
    BpNode** cz = (BpNode**)z.child
    if y.leaf == 1:
        z.keys[1] = z.keys[0]
        z.keys[0] = y.keys[y.nkeys - 1]
        x.keys[i - 1] = y.keys[y.nkeys - 1]
        z.nkeys = z.nkeys + 1
        y.nkeys = y.nkeys - 1
    else:
        z.keys[1] = z.keys[0]
        z.keys[0] = x.keys[i - 1]
        cz[2] = cz[1]
        cz[1] = cz[0]
        cz[0] = cy[y.nkeys]
        x.keys[i - 1] = y.keys[y.nkeys - 1]
        z.nkeys = z.nkeys + 1
        y.nkeys = y.nkeys - 1

# Borrows the smallest entry from child i+1 into child i; the parent separator
# is refreshed from child i+1's smallest remaining key.
public def _bp_borrow_right(x BpNode*, i int) -> void:
    BpNode** cx = (BpNode**)x.child
    BpNode* z = cx[i]
    BpNode* y = cx[i + 1]
    BpNode** cz = (BpNode**)z.child
    BpNode** cy = (BpNode**)y.child
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

public def _bp_sub_min_key(x BpNode*) -> int:
    if x.leaf == 1:
        return x.keys[0]
    BpNode** c = (BpNode**)x.child
    return _bp_sub_min_key(c[0])

public def _bp_delete_rec(x BpNode*, key int, found int*) -> void:
    if x.leaf == 1:
        int i = 0
        while i < x.nkeys and x.keys[i] < key:
            i = i + 1
        if i < x.nkeys and x.keys[i] == key:
            *found = 1
            while i < x.nkeys - 1:
                x.keys[i] = x.keys[i + 1]
                i = i + 1
            x.nkeys = x.nkeys - 1
        return
    int cidx = _bp_child_idx(x, key)
    BpNode** cx = (BpNode**)x.child
    BpNode* y = cx[cidx]
    if y.nkeys == 1:
        if cidx > 0:
            BpNode* ls = cx[cidx - 1]
            if ls.nkeys >= 2:
                _bp_borrow_left(x, cidx)
            else:
                _bp_merge(x, cidx - 1)
                y = cx[cidx - 1]
        elif cidx < x.nkeys:
            BpNode* rs = cx[cidx + 1]
            if rs.nkeys >= 2:
                _bp_borrow_right(x, cidx)
            else:
                _bp_merge(x, cidx)
                y = cx[cidx]
    _bp_delete_rec(y, key, found)
    BpNode** c2 = (BpNode**)x.child
    int i = 0
    while i < x.nkeys:
        x.keys[i] = _bp_sub_min_key(c2[i + 1])
        i = i + 1

public def bpt_erase(t BPlusTree, key int) -> BPlusTree:
    int found = 0
    if t.root != 0:
        _bp_delete_rec(t.root, key, &found)
        BpNode* r = t.root
        if r.nkeys == 0:
            if r.leaf == 1:
                t.root = 0
            else:
                BpNode** cr = (BpNode**)r.child
                t.root = cr[0]
        if found == 1:
            if t.size > (size_t)0:
                t.size -= (size_t)1
    return t

public def _bp_leftmost(x BpNode*) -> BpNode*:
    BpNode* cur = x
    BpNode* nxt = 0
    while cur.leaf == 0:
        BpNode** c = (BpNode**)cur.child
        nxt = c[0]
        cur = nxt
    return cur

public def _bp_rightmost(x BpNode*) -> BpNode*:
    BpNode* cur = x
    while cur.leaf == 0:
        BpNode** c = (BpNode**)cur.child
        cur = c[cur.nkeys]
    return cur

public def bpt_min(t BPlusTree) -> int:
    BpNode* n = _bp_leftmost(t.root)
    if n == 0:
        return 0
    return n.keys[0]

public def bpt_max(t BPlusTree) -> int:
    BpNode* n = _bp_rightmost(t.root)
    if n == 0:
        return 0
    return n.keys[n.nkeys - 1]

public def bpt_size(t BPlusTree) -> size_t:
    return t.size

public def bpt_is_empty(t BPlusTree) -> int:
    int e = 0
    if t.size == (size_t)0:
        e = 1
    return e

# Copies all keys in ascending order into buf; returns how many were written.
public def bpt_collect(t BPlusTree, buf int*) -> size_t:
    size_t w = (size_t)0
    BpNode* n = t.root
    while n != 0 and n.leaf == 0:
        BpNode** c = (BpNode**)n.child
        n = c[0]
    while n != 0:
        int i = 0
        while i < n.nkeys:
            buf[w] = n.keys[i]
            w += (size_t)1
            i = i + 1
        n = n.next
    return w

# Smallest key in subtree n (used by validate).
public def _bp_sub_min(n BpNode*) -> BpNode*:
    BpNode* cur = n
    while cur.leaf == 0:
        BpNode** c = (BpNode**)cur.child
        cur = c[0]
    return cur

# Largest key in subtree n (used by validate).
public def _bp_sub_max(n BpNode*) -> BpNode*:
    BpNode* cur = n
    while cur.leaf == 0:
        BpNode** c = (BpNode**)cur.child
        cur = c[cur.nkeys]
    return cur

public def _bp_check(x BpNode*, leafdepth int*, d int) -> int:
    if x.leaf == 1:
        if x.nkeys < 1 or x.nkeys > 3:
            return 0
        int i = 0
        while i < x.nkeys - 1:
            if x.keys[i] >= x.keys[i + 1]:
                return 0
            i = i + 1
        if *leafdepth == -1:
            *leafdepth = d
        if d != *leafdepth:
            return 0
        return 1
    if x.nkeys < 1 or x.nkeys > 3:
        return 0
    BpNode** c = (BpNode**)x.child
    int i = 0
    while i < x.nkeys:
        if c[i] == 0:
            return 0
        if _bp_check(c[i], leafdepth, d + 1) == 0:
            return 0
        i = i + 1
    if c[x.nkeys] == 0:
        return 0
    if _bp_check(c[x.nkeys], leafdepth, d + 1) == 0:
        return 0
    i = 0
    while i < x.nkeys:
        BpNode* a = _bp_sub_max(c[i])
        BpNode* b = _bp_sub_min(c[i + 1])
        if a.keys[a.nkeys - 1] > x.keys[i]:
            return 0
        if b.keys[0] < x.keys[i]:
            return 0
        i = i + 1
    return 1

public def bpt_validate(t BPlusTree) -> int:
    if t.root == 0:
        if t.size == (size_t)0:
            return 1
        return 0
    int leafdepth = -1
    int ok = _bp_check(t.root, &leafdepth, 0)
    if ok == 0:
        return 0
    BpNode* first = _bp_leftmost(t.root)
    BpNode* n = first
    size_t cnt = (size_t)0
    while n != 0:
        if n.next != 0:
            BpNode* nn = n.next
            if nn.keys[0] <= n.keys[n.nkeys - 1]:
                return 0
        cnt = cnt + (size_t)n.nkeys
        n = n.next
    if cnt != t.size:
        return 0
    return 1