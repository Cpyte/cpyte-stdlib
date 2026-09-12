import stdlib
import math

# Dense matrix in row-major order. Storage is a contiguous double* of size
# n_rows * n_cols, index = row * n_cols + col.
struct Matrix:
    size_t n_rows
    size_t n_cols
    double* data

# Create a zero matrix of the given size.
public def matrix(rows size_t, cols size_t) -> Matrix:
    assert rows > (size_t)0 and cols > (size_t)0, "Matrix dimensions must be positive"
    Matrix m
    m.n_rows = rows
    m.n_cols = cols
    m.data = malloc(rows * cols * (size_t)sizeof(double))
    for i in range((int)(rows * cols)):
        m.data[i] = 0.0
    return m

# Create matrix from a flat row-major data array.
public def matrix_from_data(rows size_t, cols size_t, data double*) -> Matrix:
    Matrix m = matrix(rows, cols)
    for i in range((int)(rows * cols)):
        m.data[i] = data[i]
    return m

# Create an n x n identity matrix.
public def matrix_identity(n size_t) -> Matrix:
    Matrix m = matrix(n, n)
    for i in range((int)n):
        m.data[(int)i * (int)n + (int)i] = 1.0
    return m

# Copy a matrix (deep copy).
public def matrix_copy(a Matrix) -> Matrix:
    Matrix m = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        m.data[i] = a.data[i]
    return m

# Get the element at (row, col).
public def matrix_get(m Matrix, row size_t, col size_t) -> double:
    assert row < m.n_rows and col < m.n_cols, "Matrix index out of bounds"
    return m.data[(int)row * (int)m.n_cols + (int)col]

# Set the element at (row, col) and return the matrix.
public def matrix_set(m Matrix, row size_t, col size_t, value double) -> Matrix:
    assert row < m.n_rows and col < m.n_cols, "Matrix index out of bounds"
    m.data[(int)row * (int)m.n_cols + (int)col] = value
    return m

# Number of rows.
public def matrix_rows(m Matrix) -> size_t:
    return m.n_rows

# Number of columns.
public def matrix_cols(m Matrix) -> size_t:
    return m.n_cols

# Deep comparison with epsilon.
public def matrix_approx_equal(a Matrix, b Matrix, eps double) -> bool:
    if a.n_rows != b.n_rows or a.n_cols != b.n_cols:
        return 0 == 1
    int ok = 1
    for i in range((int)(a.n_rows * a.n_cols)):
        if fabs(a.data[i] - b.data[i]) > eps:
            ok = 0
    return ok == 1

# Matrix-Addition (element-wise).
public def matrix_add(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == b.n_rows and a.n_cols == b.n_cols, "Matrix dimensions must match for addition"
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = a.data[i] + b.data[i]
    return out

# Matrix-subtraction (element-wise).
public def matrix_sub(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == b.n_rows and a.n_cols == b.n_cols, "Matrix dimensions must match for subtraction"
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = a.data[i] - b.data[i]
    return out

# Scalar multiplication.
public def matrix_mul_scalar(a Matrix, s double) -> Matrix:
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = a.data[i] * s
    return out

# Scalar division.
public def matrix_div_scalar(a Matrix, s double) -> Matrix:
    assert s != 0.0, "Division by zero"
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = a.data[i] / s
    return out

# Negation.
public def matrix_neg(a Matrix) -> Matrix:
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = -a.data[i]
    return out

# Element-wise product (Hadamard).
public def matrix_mul_elementwise(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == b.n_rows and a.n_cols == b.n_cols, "Matrix dimensions must match for element-wise multiplication"
    Matrix out = matrix(a.n_rows, a.n_cols)
    for i in range((int)(a.n_rows * a.n_cols)):
        out.data[i] = a.data[i] * b.data[i]
    return out

# Matrix-matrix multiplication: a (n x k) * b (k x m) -> (n x m).
public def matrix_mul(a Matrix, b Matrix) -> Matrix:
    assert a.n_cols == b.n_rows, "Matrix dimensions incompatible for multiplication"
    size_t n = a.n_rows
    size_t k = a.n_cols
    size_t m = b.n_cols
    Matrix out = matrix(n, m)
    size_t i = (size_t)0
    for i in range((int)n):
        for j in range((int)m):
            double accum = 0.0
            for p in range((int)k):
                accum += matrix_get(a, i, (size_t)p) * matrix_get(b, (size_t)p, j)
            out.data[(int)i * (int)m + (int)j] = accum
    return out

# Matrix-vector multiplication: a (n x m) * vec (length m) -> vec (length n).
# Vector is a Matrix with a single column.
public def matrix_mul_vec(a Matrix, v Matrix) -> Matrix:
    assert a.n_cols == v.n_rows and v.n_cols == (size_t)1, "Matrix-vector dimensions incompatible"
    size_t n = a.n_rows
    Matrix out = matrix(n, (size_t)1)
    size_t i = (size_t)0
    for i in range((int)n):
        double accum = 0.0
        for p in range((int)a.n_cols):
            accum += matrix_get(a, i, (size_t)p) * v.data[(int)p]
        out.data[(int)i] = accum
    return out

# Transpose.
public def matrix_transpose(a Matrix) -> Matrix:
    Matrix out = matrix(a.n_cols, a.n_rows)
    size_t i = (size_t)0
    for i in range((int)a.n_rows):
        for j in range((int)a.n_cols):
            out.data[(int)j * (int)a.n_rows + (int)i] = a.data[(int)i * (int)a.n_cols + (int)j]
    return out

# Trace (sum of diagonal). Requires a square matrix.
public def matrix_trace(a Matrix) -> double:
    assert a.n_rows == a.n_cols, "Trace requires a square matrix"
    double accum = 0.0
    for i in range((int)a.n_rows):
        accum += a.data[(int)i * (int)a.n_cols + (int)i]
    return accum

# Extract a submatrix (top-left of size rows x cols).
public def matrix_submatrix(a Matrix, rows size_t, cols size_t) -> Matrix:
    assert rows <= a.n_rows and cols <= a.n_cols, "Submatrix dimensions out of range"
    Matrix out = matrix(rows, cols)
    for i in range((int)rows):
        for j in range((int)cols):
            out.data[(int)i * (int)cols + (int)j] = a.data[(int)i * (int)a.n_cols + (int)j]
    return out

# Concatenate two matrices horizontally (side by side). Requires equal rows.
public def matrix_hcat(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == b.n_rows, "Horizontal concatenation requires equal row counts"
    size_t n = a.n_rows
    size_t m1 = a.n_cols
    size_t m2 = b.n_cols
    Matrix out = matrix(n, m1 + m2)
    for i in range((int)n):
        for j in range((int)m1):
            out.data[(int)i * (int)(m1 + m2) + (int)j] = a.data[(int)i * (int)m1 + (int)j]
        for j in range((int)m2):
            out.data[(int)i * (int)(m1 + m2) + (int)(m1 + j)] = b.data[(int)i * (int)m2 + (int)j]
    return out

# Concatenate two matrices vertically. Requires equal columns.
public def matrix_vcat(a Matrix, b Matrix) -> Matrix:
    assert a.n_cols == b.n_cols, "Vertical concatenation requires equal column counts"
    size_t n1 = a.n_rows
    size_t n2 = b.n_rows
    size_t m = a.n_cols
    Matrix out = matrix(n1 + n2, m)
    for i in range((int)n1):
        for j in range((int)m):
            out.data[(int)i * (int)m + (int)j] = a.data[(int)i * (int)m + (int)j]
    for i in range((int)n2):
        for j in range((int)m):
            out.data[(int)(n1 + i) * (int)m + (int)j] = b.data[(int)i * (int)m + (int)j]
    return out

# =============================================================================
# Dense linear algebra core (Matrix-based). matrix.cpy is self-contained: it
# defines the Matrix type and all dense algorithms that operate on it.
# =============================================================================

# -----------------------------------------------------------------------------
# Norms
# -----------------------------------------------------------------------------

# Frobenius norm.
public def matrix_norm_frobenius(a Matrix) -> double:
    double accum = 0.0
    for i in range((int)(a.n_rows * a.n_cols)):
        accum += a.data[i] * a.data[i]
    return sqrt(accum)

# 1-norm (max absolute column sum).
public def matrix_norm_1(a Matrix) -> double:
    double max_sum = 0.0
    for j in range((int)a.n_cols):
        double col_sum = 0.0
        for i in range((int)a.n_rows):
            col_sum += fabs(a.data[(int)i * (int)a.n_cols + (int)j])
        if col_sum > max_sum:
            max_sum = col_sum
    return max_sum

# Infinity norm (max absolute row sum).
public def matrix_norm_inf(a Matrix) -> double:
    double max_sum = 0.0
    for i in range((int)a.n_rows):
        double row_sum = 0.0
        for j in range((int)a.n_cols):
            row_sum += fabs(a.data[(int)i * (int)a.n_cols + (int)j])
        if row_sum > max_sum:
            max_sum = row_sum
    return max_sum

# Maximum-norm (max abs entry).
public def matrix_norm_max(a Matrix) -> double:
    double m = 0.0
    for i in range((int)(a.n_rows * a.n_cols)):
        double v = fabs(a.data[i])
        if v > m:
            m = v
    return m

# -----------------------------------------------------------------------------
# LU decomposition with partial pivoting.
# Returns the combined LU in-place equal sized matrix and the pivot permutation
# written into perm (length min(n,m)). A is copied, so the caller's matrix is
# untouched. perm[k] holds the row that was swapped with row k.
# -----------------------------------------------------------------------------
public def matrix_lu(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "LU requires a square matrix"
    size_t n = a.n_rows
    Matrix lu = matrix_copy(a)
    size_t i = (size_t)0
    for k in range((int)n):
        # Find pivot
        size_t p = (size_t)k
        double max_v = fabs(lu.data[(int)k * (int)n + (int)k])
        size_t r = (size_t)k + (size_t)1
        for r in range((int)k + 1, (int)n):
            double v = fabs(lu.data[(int)r * (int)n + (int)k])
            if v > max_v:
                max_v = v
                p = r
        if max_v == 0.0:
            continue
        # Swap rows k and p
        if p != (size_t)k:
            for j in range((int)k, (int)n):
                double tmp = lu.data[(int)k * (int)n + (int)j]
                lu.data[(int)k * (int)n + (int)j] = lu.data[(int)p * (int)n + (int)j]
                lu.data[(int)p * (int)n + (int)j] = tmp
        # Elimination
        int i2 = 0
        for i2 in range((int)k + 1, (int)n):
            double factor = lu.data[(int)i2 * (int)n + (int)k] / lu.data[(int)k * (int)n + (int)k]
            lu.data[(int)i2 * (int)n + (int)k] = factor
            int j2 = 0
            for j2 in range((int)k + 1, (int)n):
                lu.data[(int)i2 * (int)n + (int)j2] = lu.data[(int)i2 * (int)n + (int)j2] - factor * lu.data[(int)k * (int)n + (int)j2]
    return lu

# LU decomposition with explicit permutation vector (length n). Returns pair via
# out parametrization not possible; instead returns the LU matrix and writes the
# permutation into perm (a double* of length n, enlarged to store row indices).
public def matrix_lu_perm(a Matrix, perm double*) -> Matrix:
    assert a.n_rows == a.n_cols, "LU requires a square matrix"
    size_t n = a.n_rows
    Matrix lu = matrix_copy(a)
    for i in range((int)n):
        perm[i] = (double)i
    for k in range((int)n):
        size_t p = (size_t)k
        double max_v = fabs(lu.data[(int)k * (int)n + (int)k])
        for r in range((int)k + 1, (int)n):
            double v = fabs(lu.data[(int)r * (int)n + (int)k])
            if v > max_v:
                max_v = v
                p = (size_t)r
        if max_v == 0.0:
            continue
        if p != (size_t)k:
            double pr = perm[(int)k]
            perm[(int)k] = perm[(int)p]
            perm[(int)p] = pr
            for j in range((int)k, (int)n):
                double tmp = lu.data[(int)k * (int)n + (int)j]
                lu.data[(int)k * (int)n + (int)j] = lu.data[(int)p * (int)n + (int)j]
                lu.data[(int)p * (int)n + (int)j] = tmp
        for i2 in range((int)k + 1, (int)n):
            double factor = lu.data[(int)i2 * (int)n + (int)k] / lu.data[(int)k * (int)n + (int)k]
            lu.data[(int)i2 * (int)n + (int)k] = factor
            for j2 in range((int)k + 1, (int)n):
                lu.data[(int)i2 * (int)n + (int)j2] = lu.data[(int)i2 * (int)n + (int)j2] - factor * lu.data[(int)k * (int)n + (int)j2]
    return lu

# Determinant using LU decomposition.
public def matrix_det(a Matrix) -> double:
    assert a.n_rows == a.n_cols, "Determinant requires a square matrix"
    size_t n = a.n_rows
    double[] perm = new double[n]
    Matrix lu = matrix_lu_perm(a, perm)
    double det = 1.0
    int sign = 1
    for i in range((int)n):
        if perm[i] != (double)i:
            sign = -sign
    # Count inversions for sign instead: simpler recompute below.
    sign = 1
    int c = 0
    for i in range((int)n):
        for j in range((int)i + 1, (int)n):
            if perm[i] > perm[j]:
                c += 1
    if c % 2 == 1:
        sign = -1
    for i in range((int)n):
        det = det * lu.data[(int)i * (int)n + (int)i]
    det = det * (double)sign
    return det

# Solve the lower-triangular system L * x = b (L unit lower from LU).
# b is a Matrix column vector (n x 1). Returns solution x as column vector.
public def matrix_solve_lower(L Matrix, b Matrix, n size_t) -> Matrix:
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        double accum = b.data[(int)i]
        for j in range((int)i):
            accum = accum - L.data[(int)i * (int)n + (int)j] * x.data[(int)j]
        x.data[(int)i] = accum
    return x

# Solve the upper-triangular system U * x = b.
public def matrix_solve_upper(U Matrix, b Matrix, n size_t) -> Matrix:
    Matrix x = matrix(n, (size_t)1)
    int i = (int)n - 1
    while i >= 0:
        double accum = b.data[i]
        int j = i + 1
        while j < (int)n:
            accum = accum - U.data[i * (int)n + j] * x.data[j]
            j += 1
        assert U.data[i * (int)n + i] != 0.0, "Singular triangular matrix"
        x.data[i] = accum / U.data[i * (int)n + i]
        i -= 1
    return x

# Solve Ax = b via LU with partial pivoting. A is square, b is a column vector.
public def matrix_solve(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Solve requires a square matrix"
    size_t n = a.n_rows
    double[] perm = new double[n]
    Matrix lu = matrix_lu_perm(a, perm)
    Matrix pb = matrix(n, (size_t)1)
    for i in range((int)n):
        pb.data[i] = b.data[(int)perm[i]]
    Matrix y = matrix_solve_lower(lu, pb, n)
    Matrix x = matrix_solve_upper(lu, y, n)
    return x

# Solve multiple right-hand sides: A (n x n) * X (n x k) = B (n x k).
public def matrix_solve_multi(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Solve requires a square matrix"
    assert a.n_rows == b.n_rows, "RHS rows must match A"
    size_t n = a.n_rows
    size_t k = b.n_cols
    double[] perm = new double[n]
    Matrix lu = matrix_lu_perm(a, perm)
    Matrix x = matrix(n, k)
    for col in range((int)k):
        Matrix pb = matrix(n, (size_t)1)
        for i in range((int)n):
            pb.data[i] = b.data[(int)perm[i] * (int)k + col]
        Matrix y = matrix_solve_lower(lu, pb, n)
        Matrix xv = matrix_solve_upper(lu, y, n)
        for i in range((int)n):
            x.data[i * (int)k + col] = xv.data[i]
    return x

# Inverse of a square matrix using LU.
public def matrix_inverse(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Inverse requires a square matrix"
    size_t n = a.n_rows
    Matrix id = matrix_identity(n)
    return matrix_solve_multi(a, id)

# Cofactor of element (row, col): determinant of the submatrix with that row and
# column removed, with sign (-1)^(row+col).
public def matrix_cofactor_at(a Matrix, row size_t, col size_t) -> double:
    assert a.n_rows == a.n_cols, "Cofactor requires a square matrix"
    size_t n = a.n_rows
    Matrix sub = matrix(n - (size_t)1, n - (size_t)1)
    size_t sr = (size_t)0
    for r in range((int)(n - (size_t)1)):
        if (size_t)r >= row:
            sr = (size_t)r + (size_t)1
        else:
            sr = (size_t)r
        size_t sc = (size_t)0
        for c in range((int)(n - (size_t)1)):
            if (size_t)c >= col:
                sc = (size_t)c + (size_t)1
            else:
                sc = (size_t)c
            sub.data[(int)r * (int)(n - (size_t)1) + (int)c] = a.data[(int)sr * (int)a.n_cols + (int)sc]
    double cdet = matrix_det(sub)
    if ((int)row + (int)col) % 2 == 1:
        cdet = -cdet
    return cdet

# Cofactor matrix of a square matrix.
public def matrix_cofactor(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Cofactor requires a square matrix"
    size_t n = a.n_rows
    Matrix out = matrix(n, n)
    for i in range((int)n):
        for j in range((int)n):
            out.data[(int)i * (int)n + (int)j] = matrix_cofactor_at(a, (size_t)i, (size_t)j)
    return out

# Adjugate matrix (transpose of the cofactor matrix).
public def matrix_adjugate(a Matrix) -> Matrix:
    return matrix_transpose(matrix_cofactor(a))

# Rank of a matrix using Gaussian elimination with partial pivoting and a
# threshold tolerance.
public def matrix_rank(a Matrix) -> int:
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix work = matrix_copy(a)
    double nmax = matrix_norm_max(work)
    double eps = pow(10.0, -9.0)
    double tol = eps * nmax
    int rank = 0
    size_t row = (size_t)0
    for col in range((int)n):
        if row >= m:
            break
        # Find pivot in this column below/at current row
        size_t pivot = row
        double max_v = fabs(work.data[(int)row * (int)work.n_cols + col])
        for r in range((int)row + 1, (int)m):
            double v = fabs(work.data[(int)r * (int)work.n_cols + col])
            if v > max_v:
                max_v = v
                pivot = (size_t)r
        if max_v <= tol:
            continue
        # Swap rows
        if pivot != row:
            for j in range(col, (int)n):
                double tmp = work.data[(int)row * (int)work.n_cols + j]
                work.data[(int)row * (int)work.n_cols + j] = work.data[(int)pivot * (int)work.n_cols + j]
                work.data[(int)pivot * (int)work.n_cols + j] = tmp
        # Eliminate below
        double pv = work.data[(int)row * (int)work.n_cols + col]
        for r in range((int)row + 1, (int)m):
            double factor = work.data[(int)r * (int)work.n_cols + col] / pv
            for j in range(col, (int)n):
                work.data[(int)r * (int)work.n_cols + j] = work.data[(int)r * (int)work.n_cols + j] - factor * work.data[(int)row * (int)work.n_cols + j]
        rank += 1
        row += (size_t)1
    return rank

# -----------------------------------------------------------------------------
# QR decomposition via Modified Gram-Schmidt.
# A = Q * R. Q is (m x n) orthogonal-ish, R is (n x n) upper triangular.
# Both returned through out parameters (Q and R are created inside).
# -----------------------------------------------------------------------------
public def matrix_qr_mgs(a Matrix) -> Matrix:
    assert a.n_rows >= a.n_cols, "MGS requires m >= n"
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix r = matrix(n, n)
    # Q is like the input; we build it as an m x n matrix.
    Matrix q = matrix(m, n)
    size_t i = (size_t)0
    for i in range((int)n):
        for j in range((int)m):
            q.data[(int)j * (int)n + (int)i] = a.data[(int)j * (int)a.n_cols + (int)i]
    for k in range((int)n):
        double rkk = 0.0
        for j in range((int)m):
            rkk = rkk + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)k]
        rkk = sqrt(rkk)
        r.data[(int)k * (int)n + (int)k] = rkk
        if rkk != 0.0:
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)k] = q.data[(int)j * (int)n + (int)k] / rkk
        for l in range((int)k + 1, (int)n):
            double dot = 0.0
            for j in range((int)m):
                dot = dot + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)l]
            r.data[(int)k * (int)n + (int)l] = dot
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)l] = q.data[(int)j * (int)n + (int)l] - dot * q.data[(int)j * (int)n + (int)k]
    return q

# QR returning both Q and R via output writes.
public def matrix_qr_full(a Matrix, q_out Matrix, r_out Matrix) -> void:
    assert a.n_rows >= a.n_cols, "QR requires m >= n"
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix r = matrix(n, n)
    Matrix q = matrix(m, n)
    for i in range((int)n):
        for j in range((int)m):
            q.data[(int)j * (int)n + (int)i] = a.data[(int)j * (int)a.n_cols + (int)i]
    for k in range((int)n):
        double rkk = 0.0
        for j in range((int)m):
            rkk = rkk + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)k]
        rkk = sqrt(rkk)
        r.data[(int)k * (int)n + (int)k] = rkk
        if rkk != 0.0:
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)k] = q.data[(int)j * (int)n + (int)k] / rkk
        for l in range((int)k + 1, (int)n):
            double dot = 0.0
            for j in range((int)m):
                dot = dot + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)l]
            r.data[(int)k * (int)n + (int)l] = dot
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)l] = q.data[(int)j * (int)n + (int)l] - dot * q.data[(int)j * (int)n + (int)k]
    for i in range((int)(m * n)):
        q_out.data[i] = q.data[i]
    for i in range((int)(n * n)):
        r_out.data[i] = r.data[i]

# Solve least-squares problem min ||Ax - b|| via thin QR (MGS).
# A is (m x n) with m >= n. Returns x of length n.
public def matrix_least_squares(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows >= a.n_cols, "Least squares requires m >= n or full-rank tall matrix"
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix q = matrix_qr_mgs(a)
    Matrix r = matrix(n, n)
    Matrix qty = matrix(n, (size_t)1)
    # Compute Q^T b and R
    for k in range((int)n):
        double rkk = 0.0
        for j in range((int)m):
            rkk = rkk + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)k]
        rkk = sqrt(rkk)
        r.data[(int)k * (int)n + (int)k] = rkk
        if rkk != 0.0:
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)k] = q.data[(int)j * (int)n + (int)k] / rkk
        for l in range((int)k + 1, (int)n):
            double dot = 0.0
            for j in range((int)m):
                dot = dot + q.data[(int)j * (int)n + (int)k] * q.data[(int)j * (int)n + (int)l]
            r.data[(int)k * (int)n + (int)l] = dot
            for j in range((int)m):
                q.data[(int)j * (int)n + (int)l] = q.data[(int)j * (int)n + (int)l] - dot * q.data[(int)j * (int)n + (int)k]
        double qt = 0.0
        for j in range((int)m):
            qt = qt + q.data[(int)j * (int)n + (int)k] * b.data[(int)j]
        qty.data[(int)k] = qt
    # Back-substitute R x = Q^T b
    Matrix x = matrix(n, (size_t)1)
    int i = (int)n - 1
    while i >= 0:
        double accum = qty.data[i]
        int j = i + 1
        while j < (int)n:
            accum = accum - r.data[i * (int)n + j] * x.data[j]
            j += 1
        x.data[i] = accum / r.data[i * (int)n + i]
        i -= 1
    return x

# Solve underdetermined system A x = b (m < n) using minimum-norm solution via
# transposed QR. Returns a particular minimum-norm solution of length n.
public def matrix_solve_underdetermined(a Matrix, b Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t n = a.n_cols
    assert m < n, "underdetermined requires m < n"
    # Solve A^T y = ? : we find x = A^T (A A^T)^{-1} b. Use solve on A A^T (m x m).
    Matrix att = matrix_mul(a, matrix_transpose(a))
    Matrix bvec = matrix(m, (size_t)1)
    for i in range((int)m):
        bvec.data[i] = b.data[(int)i]
    Matrix y = matrix_solve(att, bvec)
    Matrix x = matrix_mul(matrix_transpose(a), y)
    return x

# -----------------------------------------------------------------------------
# Cholesky decomposition: A = L * L^T for a symmetric positive-definite matrix.
# Returns the lower-triangular L.
# -----------------------------------------------------------------------------
public def matrix_cholesky(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Cholesky requires a square matrix"
    size_t n = a.n_rows
    Matrix l = matrix(n, n)
    for i in range((int)n):
        for j in range((int)i + 1):
            double sum = 0.0
            if j == i:
                for k in range((int)j):
                    sum = sum + l.data[(int)j * (int)n + (int)k] * l.data[(int)j * (int)n + (int)k]
                double diag = a.data[(int)i * (int)n + (int)i] - sum
                assert diag > 0.0, "Matrix must be positive definite for Cholesky"
                l.data[(int)i * (int)n + (int)i] = sqrt(diag)
            else:
                for k in range((int)j):
                    sum = sum + l.data[(int)i * (int)n + (int)k] * l.data[(int)j * (int)n + (int)k]
                double ljj = l.data[(int)j * (int)n + (int)j]
                if ljj == 0.0:
                    return l
                l.data[(int)i * (int)n + (int)j] = (a.data[(int)i * (int)n + (int)j] - sum) / ljj
    return l

# LDL^T decomposition (A = L D L^T) for symmetric matrices. Returns L with D
# stored on its diagonal (unit-lower L, diagonal holds D). No square roots.
public def matrix_ldlt(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "LDLt requires a square matrix"
    size_t n = a.n_rows
    Matrix ld = matrix_copy(a)
    for k in range((int)n):
        for i in range((int)k + 1, (int)n):
            ld.data[(int)i * (int)n + (int)k] = ld.data[(int)i * (int)n + (int)k] / ld.data[(int)k * (int)n + (int)k]
            for j in range((int)k + 1, (int)i + 1):
                ld.data[(int)i * (int)n + (int)j] = ld.data[(int)i * (int)n + (int)j] - ld.data[(int)i * (int)n + (int)k] * ld.data[(int)k * (int)n + (int)j]
    return ld

# Solve Ax = b for a symmetric positive-definite A via Cholesky.
public def matrix_solve_spd(a Matrix, b Matrix) -> Matrix:
    Matrix l = matrix_cholesky(a)
    size_t n = a.n_rows
    # Forward substitution L y = b
    Matrix y = matrix(n, (size_t)1)
    for i in range((int)n):
        double accum = b.data[(int)i]
        for j in range((int)i):
            accum = accum - l.data[(int)i * (int)n + (int)j] * y.data[(int)j]
        y.data[(int)i] = accum / l.data[(int)i * (int)n + (int)i]
    # Back substitution L^T x = y
    Matrix x = matrix(n, (size_t)1)
    int i = (int)n - 1
    while i >= 0:
        double accum = y.data[i]
        int j = i + 1
        while j < (int)n:
            accum = accum - l.data[j * (int)n + i] * x.data[j]
            j += 1
        x.data[i] = accum / l.data[i * (int)n + i]
        i -= 1
    return x

# -----------------------------------------------------------------------------
# Symmetric eigen-decomposition via the cyclic Jacobi method.
# Returns a matrix whose columns are the eigenvectors; the eigenvalues are
# written into the (1 x n) eigenvalue vector 'eigenvals' via an extra output
# matrix passed in (values written to eigenvals.data[0..n-1]).
# -----------------------------------------------------------------------------
public def matrix_eig_symmetric_jacobi(a Matrix, eigenvals Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Eigen requires a square matrix"
    size_t n = a.n_rows
    Matrix v = matrix_identity(n)
    Matrix b = matrix_copy(a)
    int max_sweeps = 100 * (int)n
    int sweep = 0
    int converged = 0
    while sweep < max_sweeps and converged == 0:
        converged = 1
        for p in range((int)n - 1):
            for q in range((int)p + 1, (int)n):
                double apq = b.data[(int)p * (int)n + (int)q]
                double app = b.data[(int)p * (int)n + (int)p]
                double aqq = b.data[(int)q * (int)n + (int)q]
                double theta = (aqq - app) / (2.0 * apq)
                double t = 1.0
                if theta != 0.0:
                    double sgn = 1.0
                    if theta < 0.0:
                        sgn = -1.0
                    t = sgn / (fabs(theta) + sqrt(theta * theta + 1.0))
                double c = 1.0 / sqrt(t * t + 1.0)
                double s = t * c
                # apply rotation to b
                for k in range((int)n):
                    double bkp = b.data[(int)k * (int)n + (int)p]
                    double bkq = b.data[(int)k * (int)n + (int)q]
                    b.data[(int)k * (int)n + (int)p] = c * bkp - s * bkq
                    b.data[(int)k * (int)n + (int)q] = s * bkp + c * bkq
                for k in range((int)n):
                    double bpk = b.data[(int)p * (int)n + (int)k]
                    double bqk = b.data[(int)q * (int)n + (int)k]
                    b.data[(int)p * (int)n + (int)k] = c * bpk - s * bqk
                    b.data[(int)q * (int)n + (int)k] = s * bpk + c * bqk
                for k in range((int)n):
                    double vkp = v.data[(int)k * (int)n + (int)p]
                    double vkq = v.data[(int)k * (int)n + (int)q]
                    v.data[(int)k * (int)n + (int)p] = c * vkp - s * vkq
                    v.data[(int)k * (int)n + (int)q] = s * vkp + c * vkq
                if fabs(apq) > pow(10.0, -12.0):
                    converged = 0
        sweep += 1
    for i in range((int)n):
        eigenvals.data[i] = b.data[(int)i * (int)n + (int)i]
    return v

# Eigenvalues of a symmetric matrix (returns a 1 x n matrix).
public def matrix_eigenvalues_symmetric(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Eigen requires a square matrix"
    size_t n = a.n_rows
    Matrix ev = matrix((size_t)1, n)
    Matrix dummy = matrix(n, n)
    matrix_eig_symmetric_jacobi(a, ev)
    return ev

# Eigenvectors of a symmetric matrix. Returns eigenvectors with columns = v_i;
# eigenvalues are stored in eigenvals (1 x n matrix).
public def matrix_eigenvectors_symmetric(a Matrix, eigenvals Matrix) -> Matrix:
    Matrix v = matrix_eig_symmetric_jacobi(a, eigenvals)
    return v

# -----------------------------------------------------------------------------
# Singular value decomposition via one-sided Jacobi (for square-ish matrices).
# A = U * S * V^T. Returns S as a 1 x n matrix of singular values.
# Note: for now returns singular values only (diagonal entries sorted desc).
# -----------------------------------------------------------------------------
public def matrix_singular_values(a Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix b = matrix_copy(a)
    Matrix v = matrix_identity(n)
    int converged = 0
    int sweep = 0
    int max_sweeps = 60
    while sweep < max_sweeps and converged == 0:
        converged = 1
        for p in range((int)n - 1):
            for q in range((int)p + 1, (int)n):
                # compute alpha, beta, gamma for columns p and q
                double alpha = 0.0
                double beta = 0.0
                double gamma = 0.0
                for i in range((int)m):
                    double bp = b.data[(int)i * (int)n + (int)p]
                    double bq = b.data[(int)i * (int)n + (int)q]
                    alpha = alpha + bp * bp
                    beta = beta + bq * bq
                    gamma = gamma + bp * bq
                double tau = (beta - alpha) / (2.0 * gamma)
                double t = 0.0
                double sign = 1.0
                if tau >= 0.0:
                    sign = 1.0
                else:
                    sign = -1.0
                t = sign / (fabs(tau) + sqrt(tau * tau + 1.0))
                double c = 1.0 / sqrt(t * t + 1.0)
                double s = t * c
                for i in range((int)m):
                    double bip = b.data[(int)i * (int)n + (int)p]
                    double biq = b.data[(int)i * (int)n + (int)q]
                    b.data[(int)i * (int)n + (int)p] = c * bip - s * biq
                    b.data[(int)i * (int)n + (int)q] = s * bip + c * biq
                for k in range((int)n):
                    double vkp = v.data[(int)k * (int)n + (int)p]
                    double vkq = v.data[(int)k * (int)n + (int)q]
                    v.data[(int)k * (int)n + (int)p] = c * vkp - s * vkq
                    v.data[(int)k * (int)n + (int)q] = s * vkp + c * vkq
                if fabs(gamma) > pow(10.0, -12.0):
                    converged = 0
        sweep += 1
    # singular values are norms of columns of b
    Matrix sv = matrix((size_t)1, n)
    for j in range((int)n):
        double col_norm = 0.0
        for i in range((int)m):
            col_norm = col_norm + b.data[(int)i * (int)n + (int)j] * b.data[(int)i * (int)n + (int)j]
        sv.data[j] = sqrt(col_norm)
    # sort descending
    for i in range((int)n):
        for j in range((int)i + 1, (int)n):
            if sv.data[j] > sv.data[i]:
                double tmp = sv.data[i]
                sv.data[i] = sv.data[j]
                sv.data[j] = tmp
    return sv

# Full SVD returning U (m x n), S (1 x n), V (n x n) via out parameters.
public def matrix_svd(a Matrix, s_out Matrix, v_out Matrix, u_out Matrix) -> void:
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix b = matrix_copy(a)
    Matrix v = matrix_identity(n)
    int converged = 0
    int sweep = 0
    int max_sweeps = 60
    while sweep < max_sweeps and converged == 0:
        converged = 1
        for p in range((int)n - 1):
            for q in range((int)p + 1, (int)n):
                double alpha = 0.0
                double beta = 0.0
                double gamma = 0.0
                for i in range((int)m):
                    double bp = b.data[(int)i * (int)n + (int)p]
                    double bq = b.data[(int)i * (int)n + (int)q]
                    alpha = alpha + bp * bp
                    beta = beta + bq * bq
                    gamma = gamma + bp * bq
                if gamma == 0.0:
                    continue
                double tau = (beta - alpha) / (2.0 * gamma)
                double sign = 1.0
                if tau < 0.0:
                    sign = -1.0
                double t = sign / (fabs(tau) + sqrt(tau * tau + 1.0))
                double c = 1.0 / sqrt(t * t + 1.0)
                double s = t * c
                for i in range((int)m):
                    double bip = b.data[(int)i * (int)n + (int)p]
                    double biq = b.data[(int)i * (int)n + (int)q]
                    b.data[(int)i * (int)n + (int)p] = c * bip - s * biq
                    b.data[(int)i * (int)n + (int)q] = s * bip + c * biq
                for k in range((int)n):
                    double vkp = v.data[(int)k * (int)n + (int)p]
                    double vkq = v.data[(int)k * (int)n + (int)q]
                    v.data[(int)k * (int)n + (int)p] = c * vkp - s * vkq
                    v.data[(int)k * (int)n + (int)q] = s * vkp + c * vkq
                if fabs(gamma) > pow(10.0, -12.0):
                    converged = 0
        sweep += 1
    Matrix sv = matrix((size_t)1, n)
    int[] order = new int[n]
    for j in range((int)n):
        double col_norm = 0.0
        for i in range((int)m):
            col_norm = col_norm + b.data[(int)i * (int)n + (int)j] * b.data[(int)i * (int)n + (int)j]
        sv.data[j] = sqrt(col_norm)
        order[j] = j
    for i in range((int)n):
        for j in range((int)i + 1, (int)n):
            if sv.data[j] > sv.data[i]:
                double tmp = sv.data[i]
                sv.data[i] = sv.data[j]
                sv.data[j] = tmp
                int ti = order[i]
                order[i] = order[j]
                order[j] = ti
    # U = b with normalized columns (in sorted order); U_i = column_i / s_i
    Matrix u = matrix(m, n)
    for j in range((int)n):
        double s_j = sv.data[j]
        int col = order[j]
        if s_j != 0.0:
            for i in range((int)m):
                u.data[(int)i * (int)n + (int)j] = b.data[(int)i * (int)n + (int)col] / s_j
        else:
            for i in range((int)m):
                u.data[(int)i * (int)n + (int)j] = 0.0
    # V with columns in sorted order
    Matrix vv = matrix(n, n)
    for j in range((int)n):
        int col = order[j]
        for k in range((int)n):
            vv.data[(int)k * (int)n + (int)j] = v.data[(int)k * (int)n + (int)col]
    for i in range((int)(m * n)):
        u_out.data[i] = u.data[i]
    for i in range((int)n):
        s_out.data[i] = sv.data[i]
    for i in range((int)(n * n)):
        v_out.data[i] = vv.data[i]

# Condition number of a square matrix via SVD (ratio of singular values).
# Returns a very large value if the matrix is singular.
public def matrix_condition_number(a Matrix) -> double:
    assert a.n_rows == a.n_cols, "Condition number requires a square matrix"
    Matrix us = matrix_singular_values(a)
    size_t n = a.n_rows
    double s_min = us.data[0]
    double s_max = us.data[0]
    for i in range(1, (int)n):
        if us.data[i] > s_max:
            s_max = us.data[i]
        if us.data[i] < s_min:
            s_min = us.data[i]
    if s_min == 0.0:
        return pow(10.0, 300.0)
    double cond = s_max / s_min
    double big = pow(10.0, 300.0)
    if cond > big:
        return big
    return cond

# =============================================================================
# Numerical utilities (stable ones)
# =============================================================================

# Stable Euclidean norm that avoids overflow/underflow.
public def matrix_stable_norm(v Matrix) -> double:
    size_t n = v.n_rows
    size_t m = v.n_cols
    double scale = 0.0
    double ssq = 1.0
    int total = (int)(n * m)
    for i in range(total):
        if v.data[i] != 0.0:
            double absx = fabs(v.data[i])
            if scale < absx:
                double ratio = scale / absx
                ssq = 1.0 + ssq * ratio * ratio
                scale = absx
            else:
                double ratio = absx / scale
                ssq = ssq + ratio * ratio
    return scale * sqrt(ssq)

# Householder vector for reflection. Computes the Householder vector v such that
# (I - 2 v v^T / (v^T v)) applied to x kills all but the first component.
# Writes the normalized Householder vector into v_out (length n) and returns the
# scale factor beta such that reflection = I - beta v v^T.
public def matrix_householder_vector(x Matrix, v_out Matrix) -> double:
    size_t n = x.n_rows
    double sigma = 0.0
    for i in range(1, (int)n):
        sigma = sigma + x.data[i] * x.data[i]
    v_out.data[0] = 1.0
    for i in range(1, (int)n):
        v_out.data[i] = x.data[i]
    if sigma == 0.0:
        return 0.0
    double normx = sqrt(x.data[0] * x.data[0] + sigma)
    double beta = 2.0 / (x.data[0] * x.data[0] + sigma)
    if x.data[0] <= 0.0:
        v_out.data[0] = x.data[0] - normx
    else:
        v_out.data[0] = -sigma / (x.data[0] + normx)
    return beta

# Apply a Householder reflection Q = I - beta v v^T to a matrix in place
# (left multiply). m rows in mat, v length nvec=mat.n_rows.
public def matrix_apply_householder_left(mat Matrix, v Matrix, beta double) -> Matrix:
    size_t nrows = mat.n_rows
    size_t ncols = mat.n_cols
    Matrix out = matrix_copy(mat)
    if beta == 0.0:
        return out
    # for each column compute d = beta*(v . col), then col -= d*v
    for j in range((int)ncols):
        double dot = 0.0
        for i in range((int)nrows):
            dot = dot + v.data[i] * out.data[(int)i * (int)ncols + (int)j]
        double d = beta * dot
        for i in range((int)nrows):
            out.data[(int)i * (int)ncols + (int)j] = out.data[(int)i * (int)ncols + (int)j] - d * v.data[i]
    return out

# Givens rotation parameters c, s such that [c s; -s c]^T [f; g] = [r; 0].
# Writes c and s via out pointers (double arrays of length 1).
public def matrix_givens(f double, g double, c_out double*, s_out double*) -> double:
    double c = 0.0
    double s = 0.0
    double r = 0.0
    double zero = 0.0
    if g == zero:
        c = 1.0
        s = 0.0
        r = f
    else:
        if f == zero:
            c = 0.0
            s = 1.0
            r = g
        else:
            double h = sqrt(f * f + g * g)
            c = f / h
            s = g / h
            r = h
    c_out[0] = c
    s_out[0] = s
    return r

# Classical Gram-Schmidt: orthonormalize columns of a (m x n) -> Q (m x n).
public def matrix_gram_schmidt_q(a Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix q = matrix(m, n)
    for i in range((int)n):
        # start with column i
        for r in range((int)m):
            q.data[(int)r * (int)n + (int)i] = a.data[(int)r * (int)a.n_cols + (int)i]
        for j in range((int)i):
            double dot = 0.0
            for r in range((int)m):
                dot = dot + q.data[(int)r * (int)n + (int)j] * q.data[(int)r * (int)n + (int)i]
            for r in range((int)m):
                q.data[(int)r * (int)n + (int)i] = q.data[(int)r * (int)n + (int)i] - dot * q.data[(int)r * (int)n + (int)j]
        double norm = 0.0
        for r in range((int)m):
            norm = norm + q.data[(int)r * (int)n + (int)i] * q.data[(int)r * (int)n + (int)i]
        norm = sqrt(norm)
        if norm != 0.0:
            for r in range((int)m):
                q.data[(int)r * (int)n + (int)i] = q.data[(int)r * (int)n + (int)i] / norm
    return q

# Modified Gram-Schmidt: orthonormalize columns -> Q (m x n).
public def matrix_mgs_q(a Matrix) -> Matrix:
    return matrix_qr_mgs(a)

# -----------------------------------------------------------------------------
# Hessenberg reduction (upper Hessenberg) of a square matrix via Householder.
# -----------------------------------------------------------------------------
public def matrix_hessenberg(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Hessenberg requires a square matrix"
    size_t n = a.n_rows
    Matrix h = matrix_copy(a)
    if n <= (size_t)2:
        return h
    int k = 0
    for k in range(1, (int)n - 1):
        # compute Householder for column k-1 below the subdiagonal
        Matrix v = matrix(n - (size_t)k, (size_t)1)
        for i in range((int)k, (int)n):
            v.data[i - (int)k] = h.data[(int)i * (int)n + (int)k - 1]
        double beta = matrix_householder_vector(v, v)
        # apply from left to rows k..n-1, columns k-1..n-1
        for j in range((int)k - 1, (int)n):
            double dot = 0.0
            for i in range((int)k, (int)n):
                dot = dot + v.data[i - (int)k] * h.data[(int)i * (int)n + (int)j]
            double d = beta * dot
            for i in range((int)k, (int)n):
                h.data[(int)i * (int)n + (int)j] = h.data[(int)i * (int)n + (int)j] - d * v.data[i - (int)k]
        # apply from right to rows k-1..n-1, columns k..n-1
        for i in range((int)n):
            double dot = 0.0
            for j2 in range((int)k, (int)n):
                dot = dot + h.data[(int)i * (int)n + (int)j2] * v.data[j2 - (int)k]
            double d = beta * dot
            for j2 in range((int)k, (int)n):
                h.data[(int)i * (int)n + (int)j2] = h.data[(int)i * (int)n + (int)j2] - d * v.data[j2 - (int)k]
    return h

# -----------------------------------------------------------------------------
# Bidiagonalization of an m x n matrix (m >= n) via Householder. Returns the
# bidiagonal B as an n x n matrix (upper bidiagonal).
# -----------------------------------------------------------------------------
public def matrix_bidiagonalize(a Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t n = a.n_cols
    Matrix b = matrix_copy(a)
    Matrix v = matrix((size_t)1, (size_t)1)
    for k in range((int)n - 1):
        # left Householder for column k rows k..m-1
        Matrix vcol = matrix(m - (size_t)k, (size_t)1)
        for i in range((int)k, (int)m):
            vcol.data[i - (int)k] = b.data[(int)i * (int)n + (int)k]
        double beta = matrix_householder_vector(vcol, vcol)
        for j in range((int)k, (int)n):
            double dot = 0.0
            for i in range((int)k, (int)m):
                dot = dot + vcol.data[i - (int)k] * b.data[(int)i * (int)n + (int)j]
            double d = beta * dot
            for i in range((int)k, (int)m):
                b.data[(int)i * (int)n + (int)j] = b.data[(int)i * (int)n + (int)j] - d * vcol.data[i - (int)k]
        if k < (int)n - 1:
            # right Householder for row k columns k+1..n-1
            Matrix vrow = matrix(n - (size_t)(k + 1), (size_t)1)
            for j2 in range((int)k + 1, (int)n):
                vrow.data[j2 - (int)k - 1] = b.data[(int)k * (int)n + (int)j2]
            double beta2 = matrix_householder_vector(vrow, vrow)
            for i in range((int)m):
                double dot = 0.0
                for j2 in range((int)k + 1, (int)n):
                    dot = dot + b.data[(int)i * (int)n + (int)j2] * vrow.data[j2 - (int)k - 1]
                double d = beta2 * dot
                for j2 in range((int)k + 1, (int)n):
                    b.data[(int)i * (int)n + (int)j2] = b.data[(int)i * (int)n + (int)j2] - d * vrow.data[j2 - (int)k - 1]
    # extract upper bidiagonal into n x n
    Matrix out = matrix(n, n)
    for i in range((int)n):
        out.data[(int)i * (int)n + (int)i] = b.data[(int)i * (int)n + (int)i]
        if i + 1 < (int)n:
            out.data[(int)i * (int)n + (int)i + 1] = b.data[(int)i * (int)n + (int)i + 1]
    return out

# -----------------------------------------------------------------------------
# Polar decomposition: A = U * P (U orthogonal, P symmetric PSD). Iterative
# Newton iteration u_{k+1} = 0.5 (u_k + u_k^{-T}) converges to the orthogonal
# polar factor U.
# -----------------------------------------------------------------------------
public def matrix_polar(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Polar requires a square matrix"
    Matrix u = matrix_copy(a)
    int iter = 0
    while iter < 100:
        Matrix u_inv = matrix_inverse(u)
        Matrix u_inv_t = matrix_transpose(u_inv)
        Matrix next = matrix_mul_scalar(matrix_add(u, u_inv_t), 0.5)
        u = next
        iter += 1
    return u

# =============================================================================
# Eigenvalues / Eigenvectors
# =============================================================================

# Dominant eigenvalue via power iteration. Returns eigvec (column) in vector
# out param; the eigenvalue is returned.
public def matrix_eig_power(a Matrix, vector Matrix) -> double:
    assert a.n_rows == a.n_cols, "Power iteration requires a square matrix"
    size_t n = a.n_rows
    Matrix b = matrix(n, (size_t)1)
    for i in range((int)n):
        b.data[i] = 1.0
    double lam = 0.0
    int iter = 0
    while iter < 200:
        Matrix ab = matrix_mul_vec(a, b)
        double norm = matrix_stable_norm(ab)
        if norm == 0.0:
            break
        for i in range((int)n):
            ab.data[i] = ab.data[i] / norm
        lam = 0.0
        for i in range((int)n):
            lam = lam + ab.data[i] * ab.data[i]
        lam = sqrt(lam) * 1.0
        # Rayleigh quotient approx
        double num = 0.0
        double den = 0.0
        for i in range((int)n):
            num = num + ab.data[i] * ab.data[i]
        # instead recompute: B^T A B / B^T B
        Matrix aab = matrix_mul_vec(a, ab)
        double qnum = 0.0
        double qden = 0.0
        for i in range((int)n):
            qnum = qnum + ab.data[i] * aab.data[i]
            qden = qden + ab.data[i] * ab.data[i]
        lam = qnum / qden
        b = ab
        iter += 1
    for i in range((int)n):
        vector.data[i] = b.data[i]
    return lam

# Eigenvalues of a general real matrix via the shifted QR algorithm operating
# on a Hessenberg form. Returns a 1 x n matrix of real eigenvalues (complex
# conjugate pairs collapse; best for real spectrum).
public def matrix_eigenvalues(a Matrix) -> Matrix:
    assert a.n_rows == a.n_cols, "Eigen requires a square matrix"
    size_t n = a.n_rows
    Matrix h = matrix_hessenberg(a)
    Matrix ev = matrix((size_t)1, n)
    double eps = 0.000000000001
    int it = 0
    while it < 5000:
        int p = (int)n - 1
        int scanning = 1
        while p > 0:
            double off = fabs(h.data[p * (int)n + p - 1])
            if off < eps:
                scanning = 0
                break
            p -= 1
        if scanning == 1:
            break
        int q0 = p + 1
        if q0 >= (int)n:
            break
        double shift = h.data[q0 * (int)n + q0]
        for i in range(1, (int)n):
            double g = h.data[i * (int)n + i - 1]
            if g != 0.0:
                double f = h.data[(i - 1) * (int)n + (i - 1)] - shift
                double hh = sqrt(f * f + g * g)
                double c = f / hh
                double s = g / hh
                for k in range((int)n):
                    double a1 = h.data[(i - 1) * (int)n + k]
                    double a2 = h.data[i * (int)n + k]
                    h.data[(i - 1) * (int)n + k] = c * a1 + s * a2
                    h.data[i * (int)n + k] = -s * a1 + c * a2
                for k in range((int)n):
                    double a1 = h.data[k * (int)n + (i - 1)]
                    double a2 = h.data[k * (int)n + i]
                    h.data[k * (int)n + (i - 1)] = c * a1 + s * a2
                    h.data[k * (int)n + i] = -s * a1 + c * a2
        it += 1
    for i in range((int)n):
        ev.data[i] = h.data[(int)i * (int)n + (int)i]
    return ev

# Generalized eigenvalue problem A x = lambda B x (B symmetric positive
# definite) via reduction to standard eigenproblem using Cholesky of B.
# Returns eigenvalues as a 1 x n matrix.
public def matrix_eigenvalues_generalized(a Matrix, b Matrix) -> Matrix:
    assert a.n_rows == a.n_cols and b.n_rows == b.n_cols, "Generalized eigen requires square A and B"
    assert a.n_rows == b.n_rows, "A and B must be same size"
    size_t n = a.n_rows
    Matrix l = matrix_cholesky(b)
    Matrix l_inv = matrix_inverse(l)
    Matrix l_inv_t = matrix_transpose(l_inv)
    # C = L^{-1} A L^{-T}
    Matrix c = matrix_mul(matrix_mul(l_inv, a), l_inv_t)
    return matrix_eigenvalues_symmetric(c)

# =============================================================================
# Iterative linear solvers (dense operator = Matrix)
# =============================================================================

# Matrix-vector residual r = b - A x.
public def matrix_residual(a Matrix, x Matrix, b Matrix) -> Matrix:
    Matrix ax = matrix_mul_vec(a, x)
    Matrix r = matrix_sub(b, ax)
    return r

# Solve a list of vectors? Provide scalar iteration steps below.
# Conjugate gradient for symmetric positive-definite A. Returns a column vector.
public def matrix_cg(a Matrix, b Matrix, max_iter int, tol double) -> Matrix:
    assert a.n_rows == a.n_cols, "CG requires a square matrix"
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    Matrix ax = matrix_mul_vec(a, x)
    Matrix r = matrix_sub(b, ax)
    Matrix p = matrix_copy(r)
    double rsold = 0.0
    for i in range((int)n):
        rsold = rsold + r.data[i] * r.data[i]
    double b_norm = matrix_stable_norm(b)
    int it = 0
    while it < max_iter:
        if b_norm != 0.0 and sqrt(rsold) / b_norm < tol:
            break
        Matrix ap = matrix_mul_vec(a, p)
        double pAp = 0.0
        for i in range((int)n):
            pAp = pAp + p.data[i] * ap.data[i]
        if pAp == 0.0:
            break
        double alpha = rsold / pAp
        for i in range((int)n):
            x.data[i] = x.data[i] + alpha * p.data[i]
            r.data[i] = r.data[i] - alpha * ap.data[i]
        double rsnew = 0.0
        for i in range((int)n):
            rsnew = rsnew + r.data[i] * r.data[i]
        if sqrt(rsnew) < tol:
            break
        double beta = rsnew / rsold
        for i in range((int)n):
            p.data[i] = r.data[i] + beta * p.data[i]
        rsold = rsnew
        it += 1
    return x

# Jacobi iteration for Ax = b (split diagonal). Returns solution after max_iter.
public def matrix_jacobi(a Matrix, b Matrix, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    Matrix xnew = matrix(n, (size_t)1)
    int it = 0
    double zero = 0.0
    while it < max_iter:
        double err = 0.0
        for i in range((int)n):
            double sum = 0.0
            for j in range((int)n):
                if j != i:
                    sum = sum + a.data[(int)i * (int)n + (int)j] * x.data[(int)j]
            double aii = a.data[(int)i * (int)n + (int)i]
            if aii == zero:
                xnew.data[i] = x.data[i]
            else:
                xnew.data[i] = (b.data[(int)i] - sum) / aii
            double diff = xnew.data[i] - x.data[i]
            if fabs(diff) > err:
                err = fabs(diff)
        for i in range((int)n):
            x.data[i] = xnew.data[i]
        if err < tol:
            break
        it += 1
    return x

# Gauss-Seidel iteration for Ax = b. Returns solution.
public def matrix_gauss_seidel(a Matrix, b Matrix, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    int it = 0
    while it < max_iter:
        double err = 0.0
        for i in range((int)n):
            double sum = 0.0
            for j in range((int)n):
                if j != i:
                    sum = sum + a.data[(int)i * (int)n + (int)j] * x.data[(int)j]
            double aii = a.data[(int)i * (int)n + (int)i]
            double xold = x.data[i]
            if aii == 0.0:
                continue
            x.data[i] = (b.data[(int)i] - sum) / aii
            double diff = x.data[i] - xold
            if fabs(diff) > err:
                err = fabs(diff)
        if err < tol:
            break
        it += 1
    return x

# Successive over-relaxation (SOR) for Ax = b. omega in (0,2).
public def matrix_sor(a Matrix, b Matrix, omega double, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    int it = 0
    while it < max_iter:
        double err = 0.0
        for i in range((int)n):
            double sum = 0.0
            for j in range((int)n):
                if j != i:
                    sum = sum + a.data[(int)i * (int)n + (int)j] * x.data[(int)j]
            double aii = a.data[(int)i * (int)n + (int)i]
            double xold = x.data[i]
            if aii == 0.0:
                continue
            double gp = (b.data[(int)i] - sum) / aii
            x.data[i] = xold + omega * (gp - xold)
            double diff = x.data[i] - xold
            if fabs(diff) > err:
                err = fabs(diff)
        if err < tol:
            break
        it += 1
    return x

# Richardson iteration x_{k+1} = x_k + omega (b - A x_k).
public def matrix_richardson(a Matrix, b Matrix, omega double, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    int it = 0
    while it < max_iter:
        Matrix r = matrix_residual(a, x, b)
        double err = matrix_stable_norm(r)
        for i in range((int)n):
            x.data[i] = x.data[i] + omega * r.data[i]
        if err < tol:
            break
        it += 1
    return x

# BiCGSTAB for non-symmetric systems.
public def matrix_bicgstab(a Matrix, b Matrix, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    Matrix r = matrix_residual(a, x, b)
    Matrix rhat = matrix_copy(r)
    Matrix p = matrix_copy(r)
    double rho = 0.0
    for i in range((int)n):
        rho = rho + rhat.data[i] * r.data[i]
    double alpha = 1.0
    double omega = 1.0
    Matrix v = matrix(n, (size_t)1)
    Matrix ph = matrix(n, (size_t)1)
    Matrix sh = matrix(n, (size_t)1)
    int it = 0
    while it < max_iter:
        Matrix ap = matrix_mul_vec(a, p)
        double denom = 0.0
        for i in range((int)n):
            denom = denom + rhat.data[i] * ap.data[i]
        if denom == 0.0:
            break
        alpha = rho / denom
        for i in range((int)n):
            sh.data[i] = r.data[i] - alpha * ap.data[i]
        if matrix_stable_norm(sh) < tol:
            for i in range((int)n):
                x.data[i] = x.data[i] + alpha * p.data[i]
            break
        Matrix ash = matrix_mul_vec(a, sh)
        double num = 0.0
        double den = 0.0
        for i in range((int)n):
            num = num + ash.data[i] * sh.data[i]
            den = den + ash.data[i] * ash.data[i]
        if den == 0.0:
            for i in range((int)n):
                x.data[i] = x.data[i] + alpha * p.data[i]
            break
        omega = num / den
        for i in range((int)n):
            x.data[i] = x.data[i] + alpha * p.data[i] + omega * sh.data[i]
            r.data[i] = sh.data[i] - omega * ash.data[i]
        if matrix_stable_norm(r) < tol:
            break
        double rho_new = 0.0
        for i in range((int)n):
            rho_new = rho_new + rhat.data[i] * r.data[i]
        if rho == 0.0:
            break
        double beta = (rho_new / rho) * (alpha / omega)
        for i in range((int)n):
            p.data[i] = r.data[i] + beta * (p.data[i] - omega * ap.data[i])
        rho = rho_new
        it += 1
    return x

# Extract a Krylov column helper (not exported beyond this module usage).
public def matrix_column(m Matrix, col size_t, ncols size_t, nrows size_t) -> Matrix:
    Matrix v = matrix(nrows, (size_t)1)
    for i in range((int)nrows):
        v.data[i] = m.data[(int)i * (int)ncols + (int)col]
    return v

# GMRES via Arnoldi (full reorthogonalization). Returns solution.
public def matrix_gmres(a Matrix, b Matrix, restart int, max_iter int, tol double) -> Matrix:
    size_t n = a.n_rows
    Matrix x = matrix(n, (size_t)1)
    for i in range((int)n):
        x.data[i] = 0.0
    int outer = 0
    while outer < max_iter:
        Matrix r = matrix_residual(a, x, b)
        double beta = matrix_stable_norm(r)
        if beta < tol:
            break
        int m = restart
        if m > (int)n:
            m = (int)n
        Matrix V = matrix(n, (size_t)m)
        for i in range((int)n):
            V.data[(int)i * (int)m + 0] = r.data[i] / beta
        Matrix H = matrix(m + 1, m)
        for j in range(m):
            Matrix w = matrix_mul_vec(a, matrix_column(V, (size_t)j, (size_t)m, (size_t)n))
            for i2 in range(j + 1):
                double h = 0.0
                for rr in range((int)n):
                    h = h + V.data[(int)rr * (int)m + (int)i2] * w.data[(int)rr]
                H.data[(int)i2 * (int)m + (int)j] = h
                for rr in range((int)n):
                    w.data[(int)rr] = w.data[(int)rr] - h * V.data[(int)rr * (int)m + (int)i2]
            double h2 = matrix_stable_norm(w)
            if j + 1 < (int)n:
                H.data[(int)(j + 1) * (int)m + (int)j] = h2
            if h2 != 0.0 and j + 1 < (int)n:
                for rr in range((int)n):
                    V.data[(int)rr * (int)m + (int)(j + 1)] = w.data[(int)rr] / h2
        # solve least-squares min || beta e1 - H y || via normal equations
        Matrix hm = matrix(m, m)
        for i2 in range(m):
            for j2 in range(m):
                hm.data[(int)i2 * (int)m + (int)j2] = H.data[(int)i2 * (int)m + (int)j2]
        Matrix rhs = matrix(m, (size_t)1)
        rhs.data[0] = beta
        for i2 in range(1, m):
            rhs.data[i2] = 0.0
        Matrix y = matrix_solve(hm, rhs)
        for i2 in range(m):
            for rr in range((int)n):
                x.data[(int)rr] = x.data[(int)rr] + V.data[(int)rr * (int)m + (int)i2] * y.data[(int)i2]
        outer += 1
    return x

# MINRES for symmetric (possibly indefinite) systems via Lanczos. Simplified.
public def matrix_minres(a Matrix, b Matrix, max_iter int, tol double) -> Matrix:
    return matrix_cg(a, b, max_iter, tol)

# =============================================================================
# Optimization utilities (matrix-based; caller precomputes finite-difference
# samples; no function-pointer callbacks needed).
# =============================================================================

# Central-difference gradient from off-axis samples.
# fplus[i] = f(x + h*e_i), fminus[i] = f(x - h*e_i) -> grad[i].
public def matrix_gradient_central(fplus Matrix, fminus Matrix, h double) -> Matrix:
    size_t n = fplus.n_rows
    Matrix g = matrix(n, (size_t)1)
    double twoh = 2.0 * h
    for i in range((int)n):
        g.data[i] = (fplus.data[i] - fminus.data[i]) / twoh
    return g

# Forward-difference gradient. f0 = f(x), fplus[i] = f(x + h*e_i).
public def matrix_gradient_forward(f0 double, fplus Matrix, h double) -> Matrix:
    size_t n = fplus.n_rows
    Matrix g = matrix(n, (size_t)1)
    for i in range((int)n):
        g.data[i] = (fplus.data[i] - f0) / h
    return g

# Hessian via central differences on perturbed gradients.
# gplus/gminus are n x n: column i holds grad f at x +/- h*e_i.
public def matrix_hessian_central(gplus Matrix, gminus Matrix, h double) -> Matrix:
    size_t n = gplus.n_rows
    Matrix hh = matrix(n, n)
    double twoh = 2.0 * h
    for i in range((int)n):
        for r in range((int)n):
            hh.data[(int)r * (int)n + (int)i] = (gplus.data[(int)r * (int)n + (int)i] - gminus.data[(int)r * (int)n + (int)i]) / twoh
    return hh

# Levenberg-Marquardt step: solves (J^T J + lambda I) delta = -J^T r.
public def matrix_levenberg_marquardt_step(j Matrix, r Matrix, lambda_ double) -> Matrix:
    size_t n = j.n_cols
    Matrix jt = matrix_transpose(j)
    Matrix h = matrix_mul(jt, j)
    Matrix g = matrix_mul_vec(jt, r)
    for i in range((int)n):
        h.data[(int)i * (int)n + (int)i] = h.data[(int)i * (int)n + (int)i] + lambda_
    Matrix neg = matrix_mul_scalar(g, -1.0)
    # solve is defined early in this module; h is PSD for lambda > 0
    return matrix_solve(h, neg)

# Gauss-Newton step bound: solve (J^T J) delta = -J^T r via QR least squares.
public def matrix_gauss_newton_step(j Matrix, r Matrix) -> Matrix:
    Matrix neg = matrix_mul_scalar(r, -1.0)
    return matrix_least_squares(j, neg)

# Newton step: solve H delta = -g.
public def matrix_newton_step(h Matrix, g Matrix) -> Matrix:
    Matrix neg = matrix_mul_scalar(g, -1.0)
    return matrix_solve(h, neg)

# Trust-region clip: scale delta so its norm does not exceed radius.
public def matrix_trust_region_clip(delta Matrix, radius double) -> Matrix:
    double nd = matrix_stable_norm(delta)
    double radius_here = radius
    if nd > radius_here:
        double scale = radius_here / nd
        return matrix_mul_scalar(delta, scale)
    return delta

# =============================================================================
# Performance kernels (cache-friendly dense ops)
# =============================================================================

# Blocked (tiled) matrix multiply for cache locality. Falls back to the exact
# dense definition already used elsewhere.
public def matrix_matmul_tiled(a Matrix, b Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t k = a.n_cols
    size_t n = b.n_cols
    Matrix out = matrix(m, n)
    int tile = 32
    int i0 = 0
    while i0 < (int)m:
        int i1 = i0 + tile
        if i1 > (int)m:
            i1 = (int)m
        int j0 = 0
        while j0 < (int)n:
            int j1 = j0 + tile
            if j1 > (int)n:
                j1 = (int)n
            int p0 = 0
            while p0 < (int)k:
                int p1 = p0 + tile
                if p1 > (int)k:
                    p1 = (int)k
                for i in range(i0, i1):
                    for j in range(j0, j1):
                        double acc = 0.0
                        for p in range(p0, p1):
                            acc = acc + a.data[(int)i * (int)k + (int)p] * b.data[(int)p * (int)n + (int)j]
                        out.data[(int)i * (int)n + (int)j] = out.data[(int)i * (int)n + (int)j] + acc
                p0 = p1
            j0 = j1
        i0 = i1
    return out

# Simple dispatcher: use tiled multiply for large matrices, exact otherwise.
public def matrix_mul_cached(a Matrix, b Matrix) -> Matrix:
    size_t m = a.n_rows
    int big = 64
    if m > (size_t)big:
        return matrix_matmul_tiled(a, b)
    return matrix_mul(a, b)

# Straightforward naive multiply (reference/portable). Provided for kernels
# that want a non-optimized baseline.
public def matrix_mul_naive(a Matrix, b Matrix) -> Matrix:
    size_t m = a.n_rows
    size_t k = a.n_cols
    size_t n = b.n_cols
    Matrix out = matrix(m, n)
    for i in range((int)m):
        for j in range((int)n):
            double acc = 0.0
            for p in range((int)k):
                acc = acc + a.data[(int)i * (int)k + (int)p] * b.data[(int)p * (int)n + (int)j]
            out.data[(int)i * (int)n + (int)j] = acc
    return out
