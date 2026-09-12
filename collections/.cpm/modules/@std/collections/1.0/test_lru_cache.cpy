import stdlib

struct LRUCache:
    size_t* keys
    void** values
    size_t* prev
    size_t* next
    size_t* key_to_slot
    size_t capacity
    size_t size
    size_t head
    size_t tail

public def create_lru_cache(capacity size_t) -> LRUCache:
    LRUCache cache
    cache.capacity = capacity
    cache.size = (size_t)0
    cache.head = (size_t)0x7FFFFFFF
    cache.tail = (size_t)0x7FFFFFFF
    cache.keys = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    cache.values = (void**)malloc(capacity * (size_t)sizeof(void*))
    cache.prev = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    cache.next = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    cache.key_to_slot = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    size_t _i = (size_t)0
    for _i in range((int)capacity):
        cache.keys[_i] = (size_t)0x7FFFFFFF
        cache.values[_i] = 0
        cache.prev[_i] = (size_t)0x7FFFFFFF
        cache.next[_i] = (size_t)0x7FFFFFFF
        cache.key_to_slot[_i] = (size_t)0x7FFFFFFF
        i = i + (size_t)1
    return cache

public def _lru_hash(key size_t, cap size_t) -> size_t:
    size_t h = key
    h = h ^ (h >> (int)33)
    h = h * (size_t)0xff51afd7ed558ccd
    h = h ^ (h >> (int)33)
    return h % cap

public def _lru_find_slot(cache LRUCache, key size_t) -> size_t:
    size_t cap = cache.capacity
    size_t _idx = _lru_hash(key, cap)
    int _i = 0
    for _i in range((int)cap):
        size_t slot = (_idx + (size_t)_i) % cap
        if cache.keys[slot] == key or cache.keys[slot] == (size_t)0x7FFFFFFF:
            return slot
    return (size_t)0x7FFFFFFF

public def _lru_unlink(cache LRUCache, slot size_t) -> LRUCache:
    size_t p = cache.prev[slot]
    size_t n = cache.next[slot]
    if p != (size_t)0x7FFFFFFF:
        cache.next[p] = n
    else:
        cache.head = n
    if n != (size_t)0x7FFFFFFF:
        cache.prev[n] = p
    else:
        cache.tail = p
    return cache

public def _lru_link_head(cache LRUCache, slot size_t) -> LRUCache:
    cache.next[slot] = cache.head
    cache.prev[slot] = (size_t)0x7FFFFFFF
    if cache.head != (size_t)0x7FFFFFFF:
        cache.prev[cache.head] = slot
    cache.head = slot
    if cache.tail == (size_t)0x7FFFFFFF:
        cache.tail = slot
    return cache

public def lru_cache_put(cache LRUCache, key size_t, value void*) -> LRUCache:
    size_t slot = _lru_find_slot(cache, key)
    if slot == (size_t)0x7FFFFFFF:
        return cache
    if cache.keys[slot] == key:
        cache.values[slot] = value
        cache = _lru_unlink(cache, slot)
        cache = _lru_link_head(cache, slot)
        return cache
    if cache.size >= cache.capacity:
        size_t evict = cache.tail
        if evict != (size_t)0x7FFFFFFF:
            size_t evict_key = cache.keys[evict]
            size_t evict_slot = _lru_find_slot(cache, evict_key)
            if evict_slot != (size_t)0x7FFFFFFF:
                cache = _lru_unlink(cache, evict_slot)
                cache.keys[evict_slot] = (size_t)0x7FFFFFFF
                cache.values[evict_slot] = 0
                cache.key_to_slot[evict_slot] = (size_t)0x7FFFFFFF
                cache.size = cache.size - (size_t)1
    cache.keys[slot] = key
    cache.values[slot] = value
    cache.key_to_slot[slot] = slot
    cache = _lru_link_head(cache, slot)
    cache.size = cache.size + (size_t)1
    return cache

public def lru_cache_get(cache LRUCache, key size_t) -> void*:
    size_t slot = _lru_find_slot(cache, key)
    if slot == (size_t)0x7FFFFFFF:
        return 0
    if cache.keys[slot] != key:
        return 0
    cache = _lru_unlink(cache, slot)
    cache = _lru_link_head(cache, slot)
    return cache.values[slot]

def main() -> int:
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
    return 0
