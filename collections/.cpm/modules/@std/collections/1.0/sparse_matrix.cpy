import stdlib

# SparseMatrix: space-efficient matrix storage using coordinate format (COO).
# Cache-friendly flat pools: rows, cols, values are separate dense arrays.

struct SparseMatrix:
    size_t* rows
    size_t* cols
    void** values
    size_t capacity
    size_t size
    size_t n_rows
    size_t n_cols

public def create_sparse_matrix(n_rows size_t, n_cols size_t) -> SparseMatrix:
    SparseMatrix sm
    sm.n_rows = n_rows
    sm.n_cols = n_cols
    sm.capacity = (size_t)16
    sm.size = (size_t)0
    sm.rows = (size_t*)malloc(sm.capacity * (size_t)sizeof(size_t))
    sm.cols = (size_t*)malloc(sm.capacity * (size_t)sizeof(size_t))
    sm.values = (void**)malloc(sm.capacity * (size_t)sizeof(void*))
    size_t i = (size_t)0
    for i in range((int)sm.capacity):
        sm.rows[i] = (size_t)0x7FFFFFFF
        sm.cols[i] = (size_t)0x7FFFFFFF
        sm.values[i] = 0
    return sm

public def _sm_grow(sm SparseMatrix) -> SparseMatrix:
    size_t new_cap = sm.capacity * (size_t)2
    size_t* new_rows = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    size_t* new_cols = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    void** new_values = (void**)malloc(new_cap * (size_t)sizeof(void*))
    size_t i = (size_t)0
    for i in range((int)sm.capacity):
        new_rows[i] = sm.rows[i]
        new_cols[i] = sm.cols[i]
        new_values[i] = sm.values[i]
    for i in range((int)sm.capacity, (int)new_cap):
        new_rows[i] = (size_t)0x7FFFFFFF
        new_cols[i] = (size_t)0x7FFFFFFF
        new_values[i] = 0
    free(sm.rows)
    free(sm.cols)
    free(sm.values)
    sm.rows = new_rows
    sm.cols = new_cols
    sm.values = new_values
    sm.capacity = new_cap
    return sm

public def _sm_find_entry(sm SparseMatrix, row size_t, col size_t) -> size_t:
    size_t i = (size_t)0
    for i in range((int)sm.size):
        if sm.rows[i] == row and sm.cols[i] == col:
            return (size_t)i
    return (size_t)0x7FFFFFFF

public def sparse_matrix_get(sm SparseMatrix, row size_t, col size_t) -> void*:
    if row >= sm.n_rows or col >= sm.n_cols:
        return 0
    size_t idx = _sm_find_entry(sm, row, col)
    if idx != (size_t)0x7FFFFFFF:
        return sm.values[idx]
    return 0

public def sparse_matrix_set(sm SparseMatrix, row size_t, col size_t, value void*) -> SparseMatrix:
    if row >= sm.n_rows or col >= sm.n_cols:
        return sm
    size_t idx = _sm_find_entry(sm, row, col)
    if idx != (size_t)0x7FFFFFFF:
        sm.values[idx] = value
        return sm
    if value == 0:
        return sm
    if sm.size >= sm.capacity:
        sm = _sm_grow(sm)
    sm.rows[sm.size] = row
    sm.cols[sm.size] = col
    sm.values[sm.size] = value
    sm.size += (size_t)1
    return sm

public def sparse_matrix_remove(sm SparseMatrix, row size_t, col size_t) -> SparseMatrix:
    if row >= sm.n_rows or col >= sm.n_cols:
        return sm
    size_t idx = _sm_find_entry(sm, row, col)
    if idx == (size_t)0x7FFFFFFF:
        return sm
    size_t last = sm.size - (size_t)1
    sm.rows[idx] = sm.rows[last]
    sm.cols[idx] = sm.cols[last]
    sm.values[idx] = sm.values[last]
    sm.rows[last] = (size_t)0x7FFFFFFF
    sm.cols[last] = (size_t)0x7FFFFFFF
    sm.values[last] = 0
    sm.size -= (size_t)1
    return sm

public def sparse_matrix_rows(sm SparseMatrix) -> size_t:
    return sm.n_rows

public def sparse_matrix_cols(sm SparseMatrix) -> size_t:
    return sm.n_cols

public def sparse_matrix_size(sm SparseMatrix) -> size_t:
    return sm.size

public def sparse_matrix_is_empty(sm SparseMatrix) -> int:
    if sm.size == (size_t)0:
        return 1
    return 0

public def sparse_matrix_clear(sm SparseMatrix) -> SparseMatrix:
    sm.size = (size_t)0
    size_t i = (size_t)0
    for i in range((int)sm.capacity):
        sm.rows[i] = (size_t)0x7FFFFFFF
        sm.cols[i] = (size_t)0x7FFFFFFF
        sm.values[i] = 0
    return sm

public def sparse_matrix_capacity(sm SparseMatrix) -> size_t:
    return sm.capacity
