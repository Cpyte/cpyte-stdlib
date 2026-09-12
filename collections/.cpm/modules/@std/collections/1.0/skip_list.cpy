import stdlib

# SkipList: probabilistic data structure for ordered sets with O(log n) expected
# time for search, insert, and delete. Cache-friendly flat pools.

struct SkipList:
    size_t* keys
    void** values
    size_t* forward
    size_t* level
    size_t* head
    size_t capacity
    size_t size
    size_t max_level
    size_t current_level
    size_t p

public def _skip_random_level(sl SkipList) -> size_t:
    size_t lvl = (size_t)1
    while (size_t)(rand() % 100) < sl.p and lvl < sl.max_level:
        lvl = lvl + (size_t)1
    return lvl

public def create_skip_list(max_level size_t, p size_t) -> SkipList:
    SkipList sl
    sl.max_level = max_level
    sl.current_level = (size_t)1
    sl.capacity = (size_t)100
    sl.size = (size_t)0
    sl.p = p
    sl.keys = (size_t*)malloc(sl.capacity * (size_t)sizeof(size_t))
    sl.values = (void**)malloc(sl.capacity * (size_t)sizeof(void*))
    sl.forward = (size_t*)malloc(sl.capacity * (max_level + (size_t)1) * (size_t)sizeof(size_t))
    sl.level = (size_t*)malloc(sl.capacity * (size_t)sizeof(size_t))
    sl.head = (size_t*)malloc((max_level + (size_t)1) * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)sl.capacity):
        sl.keys[i] = (size_t)0x7FFFFFFF
        sl.values[i] = 0
        sl.level[i] = (size_t)0
        size_t j = (size_t)0
        for j in range((int)(max_level + (size_t)1)):
            sl.forward[i * (max_level + (size_t)1) + j] = (size_t)0x7FFFFFFF
    for i in range((int)(max_level + (size_t)1)):
        sl.head[i] = (size_t)0x7FFFFFFF
    return sl

public def _skip_grow(sl SkipList) -> SkipList:
    size_t new_cap = sl.capacity * (size_t)2
    size_t* new_keys = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    void** new_values = (void**)malloc(new_cap * (size_t)sizeof(void*))
    size_t* new_forward = (size_t*)malloc(new_cap * (sl.max_level + (size_t)1) * (size_t)sizeof(size_t))
    size_t* new_level = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)sl.capacity):
        new_keys[i] = sl.keys[i]
        new_values[i] = sl.values[i]
        new_level[i] = sl.level[i]
        size_t j = (size_t)0
        for j in range((int)(sl.max_level + (size_t)1)):
            new_forward[i * (sl.max_level + (size_t)1) + j] = sl.forward[i * (sl.max_level + (size_t)1) + j]
    for i in range((int)sl.capacity, (int)new_cap):
        new_keys[i] = (size_t)0x7FFFFFFF
        new_values[i] = 0
        new_level[i] = (size_t)0
        size_t j = (size_t)0
        for j in range((int)(sl.max_level + (size_t)1)):
            new_forward[i * (sl.max_level + (size_t)1) + j] = (size_t)0x7FFFFFFF
    free(sl.keys)
    free(sl.values)
    free(sl.forward)
    free(sl.level)
    sl.keys = new_keys
    sl.values = new_values
    sl.forward = new_forward
    sl.level = new_level
    sl.capacity = new_cap
    return sl

public def _skip_find_node(sl SkipList, key size_t) -> size_t:
    size_t* update = (size_t*)malloc((sl.max_level + (size_t)1) * (size_t)sizeof(size_t))
    size_t k = (size_t)0
    for k in range((int)(sl.max_level + (size_t)1)):
        update[k] = (size_t)0x7FFFFFFF
    int lvl = (int)sl.current_level
    while lvl >= 0:
        size_t curr = sl.head[lvl]
        size_t prev = (size_t)0x7FFFFFFF
        while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
            prev = curr
            curr = sl.forward[curr * (sl.max_level + (size_t)1) + lvl]
        update[lvl] = prev
        lvl = lvl - 1
    size_t curr = sl.head[0]
    while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
        curr = sl.forward[curr * (sl.max_level + (size_t)1) + 0]
    if curr != (size_t)0x7FFFFFFF and sl.keys[curr] == key:
        free(update)
        return curr
    free(update)
    return (size_t)0x7FFFFFFF

public def skip_list_contains(sl SkipList, key size_t) -> int:
    size_t node = _skip_find_node(sl, key)
    if node != (size_t)0x7FFFFFFF:
        return 1
    return 0

public def skip_list_get(sl SkipList, key size_t) -> void*:
    size_t node = _skip_find_node(sl, key)
    if node != (size_t)0x7FFFFFFF:
        return sl.values[node]
    return 0

public def skip_list_insert(sl SkipList, key size_t, value void*) -> SkipList:
    size_t* update = (size_t*)malloc((sl.max_level + (size_t)1) * (size_t)sizeof(size_t))
    size_t k = (size_t)0
    for k in range((int)(sl.max_level + (size_t)1)):
        update[k] = (size_t)0x7FFFFFFF
    int lvl = (int)sl.current_level
    while lvl >= 0:
        size_t curr = sl.head[lvl]
        size_t prev = (size_t)0x7FFFFFFF
        while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
            prev = curr
            curr = sl.forward[curr * (sl.max_level + (size_t)1) + lvl]
        update[lvl] = prev
        lvl = lvl - 1
    size_t curr = sl.head[0]
    while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
        curr = sl.forward[curr * (sl.max_level + (size_t)1) + 0]
    if curr != (size_t)0x7FFFFFFF and sl.keys[curr] == key:
        sl.values[curr] = value
        free(update)
        return sl
    size_t node_lvl = _skip_random_level(sl)
    if node_lvl > sl.current_level:
        int k = (int)sl.current_level + 1
        while k <= (int)node_lvl:
            update[k] = (size_t)0x7FFFFFFF
            k += 1
        sl.current_level = node_lvl
    if sl.size >= sl.capacity:
        sl = _skip_grow(sl)
    size_t idx = sl.size
    sl.keys[idx] = key
    sl.values[idx] = value
    sl.level[idx] = node_lvl
    k = (size_t)0
    while k <= node_lvl:
        if update[k] == (size_t)0x7FFFFFFF:
            sl.forward[idx * (sl.max_level + (size_t)1) + k] = sl.head[k]
            sl.head[k] = idx
        else:
            sl.forward[idx * (sl.max_level + (size_t)1) + k] = sl.forward[update[k] * (sl.max_level + (size_t)1) + k]
            sl.forward[update[k] * (sl.max_level + (size_t)1) + k] = idx
        k += (size_t)1
    sl.size += (size_t)1
    free(update)
    return sl

public def skip_list_remove(sl SkipList, key size_t) -> SkipList:
    size_t* update = (size_t*)malloc((sl.max_level + (size_t)1) * (size_t)sizeof(size_t))
    size_t k = (size_t)0
    for k in range((int)(sl.max_level + (size_t)1)):
        update[k] = (size_t)0x7FFFFFFF
    int lvl = (int)sl.current_level
    while lvl >= 0:
        size_t curr = sl.head[lvl]
        size_t prev = (size_t)0x7FFFFFFF
        while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
            prev = curr
            curr = sl.forward[curr * (sl.max_level + (size_t)1) + lvl]
        update[lvl] = prev
        lvl = lvl - 1
    size_t curr = sl.head[0]
    while curr != (size_t)0x7FFFFFFF and sl.keys[curr] < key:
        curr = sl.forward[curr * (sl.max_level + (size_t)1) + 0]
    if curr == (size_t)0x7FFFFFFF or sl.keys[curr] != key:
        free(update)
        return sl
    k = (size_t)0
    while k <= sl.current_level:
        if update[k] == (size_t)0x7FFFFFFF:
            sl.head[k] = sl.forward[curr * (sl.max_level + (size_t)1) + k]
        else:
            sl.forward[update[k] * (sl.max_level + (size_t)1) + k] = sl.forward[curr * (sl.max_level + (size_t)1) + k]
        k += (size_t)1
    sl.keys[curr] = (size_t)0x7FFFFFFF
    sl.values[curr] = 0
    sl.size -= (size_t)1
    while sl.current_level > (size_t)0 and sl.head[sl.current_level] == (size_t)0x7FFFFFFF:
        sl.current_level -= (size_t)1
    free(update)
    return sl

public def skip_list_size(sl SkipList) -> size_t:
    return sl.size

public def skip_list_is_empty(sl SkipList) -> int:
    if sl.size == (size_t)0:
        return 1
    return 0

public def skip_list_clear(sl SkipList) -> SkipList:
    sl.size = (size_t)0
    sl.current_level = (size_t)1
    size_t i = (size_t)0
    for i in range((int)(sl.max_level + (size_t)1)):
        sl.head[i] = (size_t)0x7FFFFFFF
    for i in range((int)sl.capacity):
        sl.keys[i] = (size_t)0x7FFFFFFF
        sl.values[i] = 0
        sl.level[i] = (size_t)0
        size_t j = (size_t)0
        for j in range((int)(sl.max_level + (size_t)1)):
            sl.forward[i * (sl.max_level + (size_t)1) + j] = (size_t)0x7FFFFFFF
    return sl
