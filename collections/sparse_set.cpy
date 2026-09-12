import stdlib

# SparseSet: dense set over a fixed universe with O(1) add/remove/contains.
# Cache-friendly flat pools: dense and sparse are separate dense arrays.

struct SparseSet:
    size_t* dense
    size_t* sparse
    size_t capacity
    size_t size
    size_t universe

public def create_sparse_set(universe size_t) -> SparseSet:
    SparseSet ss
    ss.universe = universe
    ss.capacity = universe
    ss.size = (size_t)0
    ss.dense = (size_t*)malloc(universe * (size_t)sizeof(size_t))
    ss.sparse = (size_t*)malloc(universe * (size_t)sizeof(size_t))
    size_t _i = (size_t)0
    for _i in range((int)universe):
        ss.dense[_i] = (size_t)0x7FFFFFFF
        ss.sparse[_i] = (size_t)0x7FFFFFFF
    return ss

public def sparse_set_contains(ss SparseSet, x size_t) -> int:
    if x >= ss.universe:
        return 0
    size_t idx = ss.sparse[x]
    if idx >= ss.size:
        return 0
    if ss.dense[idx] == x:
        return 1
    return 0

public def sparse_set_add(ss SparseSet, x size_t) -> SparseSet:
    if x >= ss.universe:
        return ss
    if sparse_set_contains(ss, x) == 1:
        return ss
    ss.dense[ss.size] = x
    ss.sparse[x] = ss.size
    ss.size += (size_t)1
    return ss

public def sparse_set_remove(ss SparseSet, x size_t) -> SparseSet:
    if x >= ss.universe:
        return ss
    if sparse_set_contains(ss, x) == 0:
        return ss
    size_t idx = ss.sparse[x]
    size_t last = ss.dense[ss.size - (size_t)1]
    ss.dense[idx] = last
    ss.sparse[last] = idx
    ss.size -= (size_t)1
    return ss

public def sparse_set_clear(ss SparseSet) -> SparseSet:
    ss.size = (size_t)0
    return ss

public def sparse_set_size(ss SparseSet) -> size_t:
    return ss.size

public def sparse_set_is_empty(ss SparseSet) -> int:
    if ss.size == (size_t)0:
        return 1
    return 0

public def sparse_set_capacity(ss SparseSet) -> size_t:
    return ss.capacity

public def sparse_set_universe(ss SparseSet) -> size_t:
    return ss.universe
