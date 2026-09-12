import stdlib

# DisjointSet (Union-Find): maintains disjoint sets with path compression
# and union by rank for near-constant amortized operations.
# Cache-friendly flat pool: parent and rank are separate dense arrays.

struct DisjointSet:
    size_t* parent
    size_t* rank
    size_t capacity
    size_t size

public def create_disjoint_set(n size_t) -> DisjointSet:
    DisjointSet ds
    ds.capacity = n
    ds.size = n
    ds.parent = (size_t*)malloc(n * (size_t)sizeof(size_t))
    ds.rank = (size_t*)malloc(n * (size_t)sizeof(size_t))
    size_t _i = (size_t)0
    for _i in range((int)n):
        ds.parent[_i] = _i
        ds.rank[_i] = (size_t)0
    return ds

public def _ds_grow(ds DisjointSet) -> DisjointSet:
    size_t new_cap = ds.capacity * (size_t)2
    size_t* new_parent = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    size_t* new_rank = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)ds.capacity):
        new_parent[i] = ds.parent[i]
        new_rank[i] = ds.rank[i]
    for i in range((int)ds.capacity, (int)new_cap):
        new_parent[i] = i
        new_rank[i] = (size_t)0
    free(ds.parent)
    free(ds.rank)
    ds.parent = new_parent
    ds.rank = new_rank
    ds.capacity = new_cap
    return ds

public def disjoint_set_find(ds DisjointSet, x size_t) -> size_t:
    if x >= ds.size:
        return (size_t)0x7FFFFFFF
    if ds.parent[x] != x:
        ds.parent[x] = disjoint_set_find(ds, ds.parent[x])
    return ds.parent[x]

public def disjoint_set_union(ds DisjointSet, x size_t, y size_t) -> DisjointSet:
    if x >= ds.size or y >= ds.size:
        return ds
    size_t x_root = disjoint_set_find(ds, x)
    size_t y_root = disjoint_set_find(ds, y)
    if x_root == y_root:
        return ds
    if ds.rank[x_root] < ds.rank[y_root]:
        ds.parent[x_root] = y_root
    else:
        if ds.rank[x_root] == ds.rank[y_root]:
            ds.rank[x_root] += (size_t)1
        ds.parent[y_root] = x_root
    return ds

public def disjoint_set_connected(ds DisjointSet, x size_t, y size_t) -> int:
    if x >= ds.size or y >= ds.size:
        return 0
    size_t x_root = disjoint_set_find(ds, x)
    size_t y_root = disjoint_set_find(ds, y)
    if x_root == y_root:
        return 1
    return 0

public def disjoint_set_count(ds DisjointSet) -> size_t:
    size_t count = (size_t)0
    size_t i = (size_t)0
    for i in range((int)ds.size):
        if ds.parent[i] == i:
            count = count + (size_t)1
    return count

public def disjoint_set_size(ds DisjointSet) -> size_t:
    return ds.size

public def disjoint_set_add(ds DisjointSet) -> DisjointSet:
    if ds.size >= ds.capacity:
        ds = _ds_grow(ds)
    ds.parent[ds.size] = ds.size
    ds.rank[ds.size] = (size_t)0
    ds.size = ds.size + (size_t)1
    return ds

public def disjoint_set_clear(ds DisjointSet) -> DisjointSet:
    size_t i = (size_t)0
    for i in range((int)ds.size):
        ds.parent[i] = i
        ds.rank[i] = (size_t)0
    return ds
