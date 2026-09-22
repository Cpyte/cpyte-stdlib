import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "WEW", "source"))
from cpyte.extension_hooks import RuntimeHook


class DequeRuntimeHook(RuntimeHook):
    def get_runtime_code(self):
        return """
#include <stdint.h>
#include <stdlib.h>

/* deque_to_list — convert a Cpyte Deque into a DynValue[] iterable.
 *
 * Deque layout (matches the Cpyte struct):
 *   void*  data;       // circular buffer of DynValue pointers
 *   size_t capacity;
 *   size_t length;
 *   size_t front;
 *
 * Each element in data[] is a (DynValue*). This function copies the
 * pointed-to DynValue structs into a contiguous, registered array so
 * `for x in list` works. */

typedef struct { int kind; uint64_t data; } deque_dynvalue_t;
extern void* cpyte_array_alloc(size_t elem_size, size_t count);

typedef struct {
    void*  data;
    size_t capacity;
    size_t length;
    size_t front;
} cpy_deque_t;

void* deque_to_list(void *deque_ptr) {
    if (deque_ptr == NULL) return NULL;

    cpy_deque_t *dq = (cpy_deque_t *)deque_ptr;
    size_t n = dq->length;

    void **src = (void **)dq->data;
    deque_dynvalue_t *arr = (deque_dynvalue_t *)cpyte_array_alloc(sizeof(deque_dynvalue_t), n);
    if (!arr) return NULL;

    for (size_t i = 0; i < n; i++) {
        size_t idx = (dq->front + i) % dq->capacity;
        arr[i] = *(deque_dynvalue_t *)src[idx];
    }

    return (void *)arr;
}
"""

    def initialize(self, context):
        pass


def get_hooks():
    return [DequeRuntimeHook("deque")]
