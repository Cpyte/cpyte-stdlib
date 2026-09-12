import stdlib

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

def main() -> int:
    ds = create_disjoint_set(10)
    ds = disjoint_set_union(ds, 0, 1)
    ds = disjoint_set_union(ds, 2, 3)
    ds = disjoint_set_union(ds, 0, 2)
    if disjoint_set_connected(ds, 1, 3) == 1:
        print("Disjoint Set: PASS")
    else:
        print("Disjoint Set: FAIL")
    return 0
