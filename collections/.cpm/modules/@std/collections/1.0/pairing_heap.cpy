import stdlib

# PairingHeap: a meldable min-priority queue. Implementation of the pairing
# heap (Sleator/Tarjan) using first-child/next-sibling links. Insert and meld
# are O(1); extract-min melds the children in a two-pass pairing scheme
# (pair adjacent siblings, then fold right-to-left) for O(log n) amortized
# cost. In practice it beats Fibonacci heaps on most workloads. No
# decrease-key is offered. Structs are passed by value; mutators return the
# updated PairingHeap.
# NOTE (codegen): chained pointer fields are avoided; follow via locals.
struct PairNode:
    PairNode* child
    PairNode* next
    int key

struct PairingHeap:
    PairNode* root
    size_t size

public def create_pairing_heap() -> PairingHeap:
    PairingHeap h
    h.root = 0
    h.size = (size_t)0
    return h

# Link two roots; the smaller key becomes the parent. Returns the new root.
public def _pair_link_roots(a PairNode*, b PairNode*) -> PairNode*:
    if b.key < a.key:
        a.next = b.child
        b.child = a
        return b
    b.next = a.child
    a.child = b
    return a

# Meld two heaps into one (O(1)). Returns the resulting heap.
public def pairing_heap_meld(a PairingHeap, b PairingHeap) -> PairingHeap:
    if b.size == (size_t)0:
        return a
    if a.size == (size_t)0:
        return b
    a.root = _pair_link_roots(a.root, b.root)
    a.size = a.size + b.size
    return a

# Insert a key (O(1)). Returns the updated heap.
public def pairing_heap_push(h PairingHeap, key int) -> PairingHeap:
    PairNode* n = new PairNode
    n.child = 0
    n.next = 0
    n.key = key
    if h.root != 0:
        h.root = _pair_link_roots(h.root, n)
    else:
        h.root = n
    h.size += (size_t)1
    return h

# Peek at the smallest key (caller should check is_empty first).
public def pairing_heap_top(h PairingHeap) -> int:
    PairNode* r = h.root
    return r.key

# Two-pass meld of a sibling list into a single tree: pass 1 links adjacent
# pairs (odd leftover carries the pairing), pass 2 reverses the resulting list
# and folds every tree into one root (equivalently the classic right-to-left
# pass, which also keeps the amortized bound).
public def _pair_pop_merge(first PairNode*) -> PairNode*:
    PairNode* merged_head = 0
    PairNode* merged_last = 0
    PairNode* cur = first
    while cur != 0 and cur.next != 0:
        PairNode* a = cur
        cur = cur.next
        PairNode* b = cur
        cur = cur.next
        a.next = 0
        b.next = 0
        PairNode* lk = _pair_link_roots(a, b)
        if merged_head != 0:
            merged_last.next = lk
            merged_last = lk
        else:
            merged_head = lk
            merged_last = lk
    if cur != 0:
        cur.next = 0
        if merged_head != 0:
            merged_last.next = cur
            merged_last = cur
        else:
            merged_head = cur
            merged_last = cur
    PairNode* prev = 0
    PairNode* c = merged_head
    while c != 0:
        PairNode* nxt = c.next
        c.next = prev
        prev = c
        c = nxt
    if prev == 0:
        return 0
    PairNode* acc = prev
    c = prev.next
    while c != 0:
        PairNode* nxt = c.next
        c.next = 0
        acc = _pair_link_roots(acc, c)
        c = nxt
    return acc

# Remove the smallest key; read it first with pairing_heap_top.
public def pairing_heap_pop_top(h PairingHeap) -> PairingHeap:
    if h.size == (size_t)0:
        return h
    PairNode* r = h.root
    h.root = _pair_pop_merge(r.child)
    h.size -= (size_t)1
    return h

public def pairing_heap_size(h PairingHeap) -> size_t:
    return h.size

public def pairing_heap_is_empty(h PairingHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# 1 if every child subtree of n obeys the heap-order rule; adds n to *cnt.
public def _pair_check(n PairNode*, cnt int*) -> int:
    if n == 0:
        return 1
    PairNode* c = n.child
    while c != 0:
        if c.key < n.key:
            return 0
        if _pair_check(c, cnt) == 0:
            return 0
        c = c.next
    *cnt = *cnt + 1
    return 1

# 1 if the whole tree is heap-ordered and the traversal count matches size.
public def pairing_heap_validate(h PairingHeap) -> int:
    if h.size == (size_t)0:
        if h.root == 0:
            return 1
        return 0
    if h.root == 0:
        return 0
    int cnt = 0
    int ok = _pair_check(h.root, &cnt)
    if ok == 0:
        return 0
    if cnt != (int)h.size:
        return 0
    return 1