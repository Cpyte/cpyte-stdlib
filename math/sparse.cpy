# Sparse matrix support: CSR format with raw C arrays. Provides a triplet
# builder, SpMV, transpose, and iterative linear solvers (Jacobi,
# Gauss-Seidel, CG). Kept self-contained (no dependency on matrix.cpy); dense
# readiness is exposed via sparse_to_dense(double*).

import stdlib
import math

# CSR sparse matrix. row_ptr has n_rows+1 entries; col_idx/values have nnz
# entries. rows[] holds the row of each triplet until sparse_build is called.
struct SparseMatrix:
    int n_rows
    int n_cols
    int nnz
    int* row_ptr
    int* col_idx
    double* values
    int* rows

# Allocate an empty CSR container for nnz triplets.
public def sparse_matrix(n_rows int, n_cols int, nnz int) -> SparseMatrix:
    SparseMatrix s
    s.n_rows = n_rows
    s.n_cols = n_cols
    s.nnz = nnz
    s.row_ptr = (int*)malloc((size_t)(sizeof(int) * (n_rows + 1)))
    s.col_idx = (int*)malloc((size_t)(sizeof(int) * nnz))
    s.values = (double*)malloc((size_t)(sizeof(double) * nnz))
    s.rows = (int*)malloc((size_t)(sizeof(int) * nnz))
    for i in range(n_rows + 1):
        s.row_ptr[i] = 0
    return s

# Store the k-th triplet (row, col, val).
public def sparse_set(sp SparseMatrix, k int, row int, col int, val double) -> SparseMatrix:
    sp.rows[k] = row
    sp.col_idx[k] = col
    sp.values[k] = val
    return sp

# Release the raw arrays held by a SparseMatrix.
public def sparse_free(sp SparseMatrix) -> void:
    free(sp.row_ptr)
    free(sp.col_idx)
    free(sp.values)
    free(sp.rows)

# Free a bare CSR container (row_ptr/col_idx/values only).
public def sparse_free_bare(sp SparseMatrix) -> void:
    free(sp.row_ptr)
    free(sp.col_idx)
    free(sp.values)

# Finalize CSR: sort triplets by row and compute row_ptr prefix sums. Returns a
# new SparseMatrix with a correct row_ptr; the caller frees the source with
# sparse_free (which also frees the rows scratch array).
public def sparse_build(sp SparseMatrix) -> SparseMatrix:
    int n = sp.n_rows
    int nnz = sp.nnz
    SparseMatrix out = sparse_matrix(n, sp.n_cols, nnz)
    # counting sort by row via prefix sums
    for r in range(n):
        out.row_ptr[r] = 0
    for k in range(nnz):
        out.row_ptr[sp.rows[k]] = out.row_ptr[sp.rows[k]] + 1
    int acc = 0
    for r in range(n):
        int cnt = out.row_ptr[r]
        out.row_ptr[r] = acc
        acc = acc + cnt
    out.row_ptr[n] = sp.nnz
    int* cursor = (int*)malloc((size_t)(sizeof(int) * (n + 1)))
    int* next = (int*)malloc((size_t)(sizeof(int) * nnz))
    for r in range(n + 1):
        cursor[r] = out.row_ptr[r]
    for r in range(n):
        for k in range(nnz):
            if sp.rows[k] == r:
                next[cursor[r]] = k
                cursor[r] = cursor[r] + 1
    for k in range(nnz):
        int src = next[k]
        out.col_idx[k] = sp.col_idx[src]
        out.values[k] = sp.values[src]
    free(cursor)
    free(next)
    return out

# Sparse matrix-vector product: y = A * x (in place into y buffer).
public def sparse_spmv(sp SparseMatrix, x double*, y double*) -> void:
    int n = sp.n_rows
    for i in range(n):
        double acc = 0.0
        for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
            acc = acc + sp.values[k] * x[sp.col_idx[k]]
        y[i] = acc

# Transpose a CSR matrix, returning a new CSR matrix (the row-ordered col
# index becomes the CSC/transpose layout; rows are not re-sorted, so the
# result is only suitable with sparse_transpose_formal for column ordering).
public def sparse_transpose(sp SparseMatrix) -> SparseMatrix:
    int n = sp.n_rows
    int m = sp.n_cols
    int nnz = sp.nnz
    SparseMatrix out = sparse_matrix(m, n, nnz)
    for c in range(m):
        out.row_ptr[c] = 0
    for k in range(nnz):
        int cj = sp.col_idx[k]
        out.row_ptr[cj] = out.row_ptr[cj] + 1
    int acc = 0
    for c in range(m):
        int cnt = out.row_ptr[c]
        out.row_ptr[c] = acc
        acc = acc + cnt
    out.row_ptr[m] = nnz
    int* cursor = (int*)malloc((size_t)(sizeof(int) * (m + 1)))
    int* next = (int*)malloc((size_t)(sizeof(int) * nnz))
    for c in range(m + 1):
        cursor[c] = out.row_ptr[c]
    for c in range(m):
        for k in range(nnz):
            if sp.col_idx[k] == c:
                next[cursor[c]] = k
                cursor[c] = cursor[c] + 1
    for k in range(nnz):
        int src = next[k]
        out.col_idx[k] = sp.rows[src]
        out.values[k] = sp.values[src]
    free(cursor)
    free(next)
    return out

# Solve A x = b where A is (lower) triangular CSR via forward substitution.
# Expects A to already be finalized. x must be a zero-initialized buffer of
# length n if strict lower; this is a full row-oriented forward solve.
public def sparse_forward_triangular(sp SparseMatrix, b double*, x double*) -> void:
    int n = sp.n_rows
    double zero = 0.0
    for i in range(n):
        double rhs = b[i]
        double diag = 0.0
        for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
            int j = sp.col_idx[k]
            if j != i:
                rhs = rhs - sp.values[k] * x[j]
            else:
                diag = sp.values[k]
        if diag == zero:
            x[i] = 0.0
        else:
            x[i] = rhs / diag

# Jacobi iteration: solve A x = b (writes into x). Assumes nonzero diagonal.
public def sparse_jacobi(sp SparseMatrix, b double*, x double*, max_iter int, tol double) -> void:
    int n = sp.n_rows
    double* xnew = (double*)malloc((size_t)(sizeof(double) * n))
    for i in range(n):
        x[i] = 0.0
    double zero = 0.0
    int it = 0
    while it < max_iter:
        double err = 0.0
        for i in range(n):
            double sum = 0.0
            for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
                int j = sp.col_idx[k]
                if j != i:
                    sum = sum + sp.values[k] * x[j]
            double diag = 0.0
            for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
                if sp.col_idx[k] == i:
                    diag = sp.values[k]
            double xold = x[i]
            if diag == zero:
                xnew[i] = xold
            else:
                xnew[i] = (b[i] - sum) / diag
            double diff = xnew[i] - xold
            if fabs(diff) > err:
                err = fabs(diff)
        for i in range(n):
            x[i] = xnew[i]
        if err < tol:
            break
        it += 1
    free(xnew)

# Gauss-Seidel iteration: solve A x = b (writes into x).
public def sparse_gauss_seidel(sp SparseMatrix, b double*, x double*, max_iter int, tol double) -> void:
    int n = sp.n_rows
    for i in range(n):
        x[i] = 0.0
    double zero = 0.0
    int it = 0
    while it < max_iter:
        double err = 0.0
        for i in range(n):
            double sum = 0.0
            double diag = 0.0
            for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
                int j = sp.col_idx[k]
                if j != i:
                    sum = sum + sp.values[k] * x[j]
                else:
                    diag = sp.values[k]
            double xold = x[i]
            if diag == zero:
                x[i] = xold
            else:
                x[i] = (b[i] - sum) / diag
            double diff = x[i] - xold
            if fabs(diff) > err:
                err = fabs(diff)
        if err < tol:
            break
        it += 1

# Conjugate gradient: solve A x = b for symmetric positive definite A.
public def sparse_cg(sp SparseMatrix, b double*, x double*, max_iter int, tol double) -> void:
    int n = sp.n_rows
    double* r = (double*)malloc((size_t)(sizeof(double) * n))
    double* p = (double*)malloc((size_t)(sizeof(double) * n))
    double* ap = (double*)malloc((size_t)(sizeof(double) * n))
    for i in range(n):
        x[i] = 0.0
    sparse_spmv(sp, x, r)
    for i in range(n):
        r[i] = b[i] - r[i]
        p[i] = r[i]
    double rsold = 0.0
    for i in range(n):
        rsold = rsold + r[i] * r[i]
    int it = 0
    while it < max_iter:
        sparse_spmv(sp, p, ap)
        double pap = 0.0
        for i in range(n):
            pap = pap + p[i] * ap[i]
        if pap == 0.0:
            break
        double alpha = rsold / pap
        for i in range(n):
            x[i] = x[i] + alpha * p[i]
            r[i] = r[i] - alpha * ap[i]
        double rsnew = 0.0
        for i in range(n):
            rsnew = rsnew + r[i] * r[i]
        if sqrt(rsnew) < tol:
            break
        double beta = rsnew / rsold
        for i in range(n):
            p[i] = r[i] + beta * p[i]
        rsold = rsnew
        it += 1
    free(r)
    free(p)
    free(ap)

# Write the dense representation of sp into the buffer dense (n_rows*n_cols).
public def sparse_to_dense(sp SparseMatrix, dense double*) -> void:
    int n = sp.n_rows
    int m = sp.n_cols
    for i in range(n * m):
        dense[i] = 0.0
    for i in range(n):
        for k in range(sp.row_ptr[i], sp.row_ptr[i + 1]):
            int j = sp.col_idx[k]
            dense[i * m + j] = sp.values[k]
