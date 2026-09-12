import stdlib

# Test all new data structures with basic operations

def main() -> int:
    # Test Disjoint Set
    ds = create_disjoint_set(10)
    ds = disjoint_set_union(ds, 0, 1)
    ds = disjoint_set_union(ds, 2, 3)
    ds = disjoint_set_union(ds, 0, 2)
    if disjoint_set_connected(ds, 1, 3) == 1:
        print("Disjoint Set: PASS")
    else:
        print("Disjoint Set: FAIL")
    
    # Test Sparse Set
    ss = create_sparse_set(100)
    ss = sparse_set_add(ss, 5)
    ss = sparse_set_add(ss, 10)
    ss = sparse_set_add(ss, 15)
    if sparse_set_contains(ss, 10) == 1 and sparse_set_size(ss) == 3:
        print("Sparse Set: PASS")
    else:
        print("Sparse Set: FAIL")
    
    # Test LRU Cache
    lru = create_lru_cache(3)
    lru = lru_cache_put(lru, 1, 0)
    lru = lru_cache_put(lru, 2, 0)
    lru = lru_cache_put(lru, 3, 0)
    lru = lru_cache_put(lru, 4, 0)
    void* v1 = lru_cache_get(lru, 1)
    void* v4 = lru_cache_get(lru, 4)
    if v1 == 0 and v4 == 0:
        print("LRU Cache: PASS")
    else:
        print("LRU Cache: FAIL")
    
    # Test LFU Cache
    lfu = create_lfu_cache(3)
    lfu = lfu_cache_put(lfu, 1, 0)
    lfu = lfu_cache_put(lfu, 2, 0)
    lfu = lfu_cache_put(lfu, 3, 0)
    lfu = lfu_cache_get(lfu, 1)
    lfu = lfu_cache_get(lfu, 1)
    lfu = lfu_cache_put(lfu, 4, 0)
    void* fv2 = lfu_cache_get(lfu, 2)
    void* fv1 = lfu_cache_get(lfu, 1)
    if fv2 == 0 and fv1 == 0:
        print("LFU Cache: PASS")
    else:
        print("LFU Cache: FAIL")
    
    # Test Skip List
    sl = create_skip_list(4, 25)
    sl = skip_list_insert(sl, 10, 0)
    sl = skip_list_insert(sl, 20, 0)
    sl = skip_list_insert(sl, 30, 0)
    if skip_list_contains(sl, 20) == 1 and skip_list_size(sl) == 3:
        print("Skip List: PASS")
    else:
        print("Skip List: FAIL")
    
    # Test Sparse Matrix
    sm = create_sparse_matrix(5, 5)
    sm = sparse_matrix_set(sm, 0, 0, 0)
    sm = sparse_matrix_set(sm, 1, 1, 0)
    sm = sparse_matrix_set(sm, 2, 2, 0)
    void* mv = sparse_matrix_get(sm, 1, 1)
    if mv == 0 and sparse_matrix_size(sm) == 3:
        print("Sparse Matrix: PASS")
    else:
        print("Sparse Matrix: FAIL")
    
    # Test Adjacency List
    al = create_adjacency_list(5, 1)
    al = adjacency_list_add_edge(al, 0, 1, 0)
    al = adjacency_list_add_edge(al, 1, 2, 0)
    al = adjacency_list_add_edge(al, 2, 3, 0)
    if adjacency_list_has_edge(al, 1, 2) == 1 and adjacency_list_edges(al) == 3:
        print("Adjacency List: PASS")
    else:
        print("Adjacency List: FAIL")
    
    return 0
