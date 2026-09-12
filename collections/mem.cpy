import stdlib

# Shared memory backends for the collections package.
#
# Everything here touches only pointers and scalar sizes — no cpyte structs
# cross module boundaries, so these helpers can be `import "mem.cpy"`d from
# any container without tripping the cross-module struct-field restriction.
#
# Compiled from the embedded `ccode:` block (libc memcpy/memmove/memset) and
# pure-cpy flat loops over contiguous buffers. Client containers use these to
# bulk-copy / bulk-shift their element arrays instead of per-element loops, and
# to draw node storage from one contiguous arena.

ccode:
    #include <stddef.h>
    #include <string.h>
    #include <stdlib.h>

    void* cpy_memcpy(void* dst, void* src, long long n) {
        return memcpy(dst, src, (size_t)n);
    }
    void* cpy_memmove(void* dst, void* src, long long n) {
        return memmove(dst, src, (size_t)n);
    }
    void* cpy_memset(void* dst, int c, long long n) {
        return memset(dst, c, (size_t)n);
    }

    /* Opaque arena allocator: one contiguous region, bump-allocate chunks of
     * `align`-rounded size, grow by realloc-doubling when exhausted. The
     * handle is a cpyte-invisible C struct so clients hold it as a bare void*. */
    typedef struct {
        unsigned char* base;
        size_t cap;
        size_t top;
    } cpy_arena_t;

    void* cpy_arena_create(long long bytes) {
        cpy_arena_t* a = (cpy_arena_t*)calloc(1, sizeof(cpy_arena_t));
        if (!a) return NULL;
        if (bytes < 8192) bytes = 8192;
        a->base = (unsigned char*)malloc((size_t)bytes);
        if (!a->base) { free(a); return NULL; }
        a->cap = (size_t)bytes;
        a->top = 0;
        return (void*)a;
    }

    void* cpy_arena_alloc(void* arena, long long bytes, long long align) {
        cpy_arena_t* a = (cpy_arena_t*)arena;
        size_t al = (size_t)align; if (al < 8) al = 8;
        size_t n = (size_t)bytes;
        size_t off = (a->top + al - 1u) & ~(al - 1u);
        if (off + n > a->cap) {
            size_t ncap = a->cap * 2;
            while (ncap < off + n) ncap *= 2;
            unsigned char* nb = (unsigned char*)realloc(a->base, ncap);
            if (!nb) return NULL;
            a->base = nb;
            a->cap = ncap;
        }
        unsigned char* p = a->base + off;
        a->top = off + n;
        return (void*)p;
    }

    void cpy_arena_reset(void* arena) {
        cpy_arena_t* a = (cpy_arena_t*)arena;
        a->top = 0;
    }

    void cpy_arena_destroy(void* arena) {
        cpy_arena_t* a = (cpy_arena_t*)arena;
        if (!a) return;
        free(a->base);
        a->base = NULL;
        free(a);
    }

# Allocate a fresh arena with at least `bytes` of bump space.
public def arena_create(bytes size_t) -> void*:
    return cpy_arena_create((int)bytes)

# Draw `bytes` from the arena, aligned to at least `align` bytes.
public def arena_alloc(arena void*, bytes size_t, align size_t) -> void*:
    return cpy_arena_alloc(arena, (int)bytes, (int)align)

# Rewind the arena to the beginning (all previously drawn chunks are freed as
# a group; nothing has per-chunk ownership).
public def arena_reset(arena void*) -> void*:
    cpy_arena_reset(arena)
    return arena

public def arena_destroy(arena void*) -> void*:
    cpy_arena_destroy(arena)
    return 0

# Bulk ops over raw bytes (libc memcpy/memmove/memset).
public def buf_copy(dst void*, src void*, n size_t) -> void*:
    return cpy_memcpy(dst, src, (int)n)

public def buf_move(dst void*, src void*, n size_t) -> void*:
    return cpy_memmove(dst, src, (int)n)

public def buf_zero(dst void*, n size_t) -> void*:
    return cpy_memset(dst, 0, (int)n)
