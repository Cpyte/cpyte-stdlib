import stdlib

# LFUCache: fixed-capacity cache with least-frequently-used eviction policy.
# Cache-friendly flat pools: keys, values, freqs are separate dense arrays.

struct LFUCache:
    size_t* keys
    void** values
    size_t* freqs
    size_t* key_to_slot
    size_t capacity
    size_t size
    size_t min_freq

public def create_lfu_cache(capacity size_t) -> LFUCache:
    LFUCache cache
    cache.capacity = capacity
    cache.size = (size_t)0
    cache.min_freq = (size_t)0
    cache.keys = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    cache.values = (void**)malloc(capacity * (size_t)sizeof(void*))
    cache.freqs = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    cache.key_to_slot = (size_t*)malloc(capacity * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)capacity):
        cache.keys[i] = (size_t)0x7FFFFFFF
        cache.values[i] = 0
        cache.freqs[i] = (size_t)0
        cache.key_to_slot[i] = (size_t)0x7FFFFFFF
    return cache

public def _lfu_hash(key size_t, cap size_t) -> size_t:
    size_t h = key
    h = h ^ (h >> (int)33)
    h = h * (size_t)0xff51afd7ed558ccd
    h = h ^ (h >> (int)33)
    return h % cap

public def _lfu_find_slot(cache LFUCache, key size_t) -> size_t:
    size_t cap = cache.capacity
    size_t idx = _lfu_hash(key, cap)
    int i = 0
    for i in range((int)cap):
        size_t slot = (idx + (size_t)i) % cap
        if cache.keys[slot] == key or cache.keys[slot] == (size_t)0x7FFFFFFF:
            return slot
    return (size_t)0x7FFFFFFF

public def _lfu_find_min_freq(cache LFUCache) -> size_t:
    size_t min_freq = (size_t)0x7FFFFFFF
    size_t min_slot = (size_t)0x7FFFFFFF
    size_t i = (size_t)0
    for i in range((int)cache.capacity):
        if cache.keys[i] != (size_t)0x7FFFFFFF:
            if cache.freqs[i] < min_freq:
                min_freq = cache.freqs[i]
                min_slot = i
    return min_slot

public def lfu_cache_get(cache LFUCache, key size_t) -> void*:
    size_t slot = _lfu_find_slot(cache, key)
    if slot == (size_t)0x7FFFFFFF:
        return 0
    if cache.keys[slot] != key:
        return 0
    cache.freqs[slot] += (size_t)1
    if cache.freqs[slot] < cache.min_freq or cache.min_freq == (size_t)0:
        cache.min_freq = cache.freqs[slot]
    return cache.values[slot]

public def lfu_cache_put(cache LFUCache, key size_t, value void*) -> LFUCache:
    size_t slot = _lfu_find_slot(cache, key)
    if slot == (size_t)0x7FFFFFFF:
        return cache
    if cache.keys[slot] == key:
        cache.values[slot] = value
        cache.freqs[slot] += (size_t)1
        return cache
    if cache.size >= cache.capacity:
        size_t evict_slot = _lfu_find_min_freq(cache)
        if evict_slot != (size_t)0x7FFFFFFF:
            size_t evict_key = cache.keys[evict_slot]
            size_t evict_hash_slot = _lfu_find_slot(cache, evict_key)
            if evict_hash_slot != (size_t)0x7FFFFFFF:
                cache.keys[evict_hash_slot] = (size_t)0x7FFFFFFF
                cache.values[evict_hash_slot] = 0
                cache.freqs[evict_hash_slot] = (size_t)0
                cache.key_to_slot[evict_hash_slot] = (size_t)0x7FFFFFFF
                cache.size -= (size_t)1
    cache.keys[slot] = key
    cache.values[slot] = value
    cache.freqs[slot] = (size_t)1
    cache.key_to_slot[slot] = slot
    cache.size += (size_t)1
    cache.min_freq = (size_t)1
    return cache

public def lfu_cache_remove(cache LFUCache, key size_t) -> LFUCache:
    size_t slot = _lfu_find_slot(cache, key)
    if slot == (size_t)0x7FFFFFFF:
        return cache
    if cache.keys[slot] != key:
        return cache
    cache.keys[slot] = (size_t)0x7FFFFFFF
    cache.values[slot] = 0
    cache.freqs[slot] = (size_t)0
    cache.key_to_slot[slot] = (size_t)0x7FFFFFFF
    cache.size -= (size_t)1
    size_t i = (size_t)0
    cache.min_freq = (size_t)0x7FFFFFFF
    for i in range((int)cache.capacity):
        if cache.keys[i] != (size_t)0x7FFFFFFF:
            if cache.freqs[i] < cache.min_freq:
                cache.min_freq = cache.freqs[i]
    return cache

public def lfu_cache_size(cache LFUCache) -> size_t:
    return cache.size

public def lfu_cache_capacity(cache LFUCache) -> size_t:
    return cache.capacity

public def lfu_cache_is_empty(cache LFUCache) -> int:
    if cache.size == (size_t)0:
        return 1
    return 0

public def lfu_cache_clear(cache LFUCache) -> LFUCache:
    cache.size = (size_t)0
    cache.min_freq = (size_t)0
    size_t i = (size_t)0
    for i in range((int)cache.capacity):
        cache.keys[i] = (size_t)0x7FFFFFFF
        cache.values[i] = 0
        cache.freqs[i] = (size_t)0
        cache.key_to_slot[i] = (size_t)0x7FFFFFFF
    return cache
