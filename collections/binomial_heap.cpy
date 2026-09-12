import stdlib

# BinomialHeap: a meldable min-priority queue. It is a forest of binomial
# trees; every operation is O(log n) amortized and meld is O(log n)
# (O(log n) worst-case versus the Fibonacci heap's O(1) meld). A binomial tree
# of rank r has a root with r children whose subtrees have ranks r-1 ... 0,
# and every child subtree is itself heap-ordered. Roots are kept in a
# singly-linked `next` list in strictly increasing rank order (one tree per
# rank). Structs are passed by value; mutators return the updated BinomialHeap.
# NOTE (codegen): chained pointer fields are avoided; follow via locals.
struct BinoNode:
    BinoNode* child
    BinoNode* next
    size_t degree
    int key

struct BinomialHeap:
    BinoNode* root
    size_t size

public def create_binomial_heap() -> BinomialHeap:
    BinomialHeap h
    h.root = 0
    h.size = (size_t)0
    return h

public def _bino_link(a BinoNode*, b BinoNode*) -> BinoNode*:
    # a and b are roots of equal rank; returns the root with the smaller key
    # and hangs the other under it as a new first child (rank increases by 1).
    if a.key > b.key:
        BinoNode* t = a
        a = b
        b = t
    b.next = a.child
    a.child = b
    a.degree = a.degree + (size_t)1
    return a

# Meld two root forests (each sorted ascending by rank) into one.
# Single pass: pick the smallest visible rank; if a second tree of that rank
# exists in a/b/carry, link the pair (carry, rank+1), else emit it. The
# result keeps strictly ascending, distinct ranks.
public def _bino_meld(a BinoNode*, b BinoNode*) -> BinoNode*:
    if a == 0:
        return b
    if b == 0:
        return a
    BinoNode* out_head = 0
    BinoNode* out_tail = 0
    BinoNode* carry = 0
    while a != 0 or b != 0 or carry != 0:
        size_t dmin = (size_t)2147483647
        if a != 0 and a.degree < dmin:
            dmin = a.degree
        if b != 0 and b.degree < dmin:
            dmin = b.degree
        if carry != 0 and carry.degree < dmin:
            dmin = carry.degree
        BinoNode* src = 0
        int used = 0
        if a != 0 and a.degree == dmin and used == 0:
            src = a
            a = a.next
            used = 1
        if b != 0 and b.degree == dmin and used == 0:
            src = b
            b = b.next
            used = 1
        if carry != 0 and carry.degree == dmin and used == 0:
            src = carry
            carry = 0
            used = 1
        if used == 1:
            BinoNode* src2 = 0
            if a != 0 and a.degree == dmin and src2 == 0:
                src2 = a
                a = a.next
            if b != 0 and b.degree == dmin and src2 == 0:
                src2 = b
                b = b.next
            if carry != 0 and carry.degree == dmin and src2 == 0:
                src2 = carry
                carry = 0
            if src2 != 0:
                carry = _bino_link(src, src2)
            else:
                src.next = 0
                if out_head != 0:
                    out_tail.next = src
                    out_tail = src
                else:
                    out_head = src
                    out_tail = src
    return out_head

# Meld b into a. Returns the updated heap.
public def binomial_heap_meld(a BinomialHeap, b BinomialHeap) -> BinomialHeap:
    if b.size == (size_t)0:
        return a
    a.root = _bino_meld(a.root, b.root)
    a.size = a.size + b.size
    return a

# Insert a key. Returns the updated heap.
public def binomial_heap_push(h BinomialHeap, key int) -> BinomialHeap:
    BinoNode* n = new BinoNode
    n.child = 0
    n.next = 0
    n.degree = (size_t)0
    n.key = key
    h.root = _bino_meld(h.root, n)
    h.size += (size_t)1
    return h

# Peek at the smallest key (caller should check is_empty first).
public def binomial_heap_top(h BinomialHeap) -> int:
    BinoNode* cur = h.root
    if cur == 0:
        return 0
    int best = cur.key
    cur = cur.next
    while cur != 0:
        if cur.key < best:
            best = cur.key
        cur = cur.next
    return best

# Remove the smallest key, promoting its children back into the forest.
public def binomial_heap_pop_top(h BinomialHeap) -> BinomialHeap:
    if h.size == (size_t)0:
        return h
    BinoNode* head = h.root
    BinoNode* best = head
    BinoNode* bestprev = 0
    BinoNode* prev = head
    BinoNode* cur = head.next
    while cur != 0:
        if cur.key < best.key:
            best = cur
            bestprev = prev
        prev = cur
        cur = cur.next
    if bestprev != 0:
        bestprev.next = best.next
    else:
        head = best.next
    BinoNode* kids = best.child
    BinoNode* rev = 0
    cur = kids
    while cur != 0:
        BinoNode* nxt = cur.next
        cur.next = rev
        rev = cur
        cur = nxt
    h.root = _bino_meld(head, rev)
    h.size -= (size_t)1
    return h

public def binomial_heap_size(h BinomialHeap) -> size_t:
    return h.size

public def binomial_heap_is_empty(h BinomialHeap) -> int:
    int e = 0
    if h.size == (size_t)0:
        e = 1
    return e

# Returns n's rank, or -1 if n violates heap order / the rank invariant.
# Also counts every visited node into *cnt.
public def _bino_check(n BinoNode*, cnt int*) -> int:
    if n == 0:
        return 0
    *cnt = *cnt + 1
    int deg = (int)n.degree
    int expect = deg - 1
    BinoNode* c = n.child
    while c != 0:
        if c.key < n.key:
            return -1
        int cd = _bino_check(c, cnt)
        if cd != expect:
            return -1
        expect = expect - 1
        c = c.next
    if expect != -1:
        return -1
    return deg

# 1 if the forest is a set of heap-ordered binomial trees with distinct,
# ascending root ranks and the node count matches size.
public def binomial_heap_validate(h BinomialHeap) -> int:
    int cnt = 0
    BinoNode* cur = h.root
    int prevdeg = -1
    while cur != 0:
        int d = (int)cur.degree
        if d <= prevdeg:
            return 0
        if _bino_check(cur, &cnt) != d:
            return 0
        prevdeg = d
        cur = cur.next
    if cnt != (int)h.size:
        return 0
    return 1