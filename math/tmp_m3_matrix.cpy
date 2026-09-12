import stdlib
import "matrix.cpy"

def main():
    Matrix A = matrix((size_t)3, (size_t)3)
    A = matrix_set(A, (size_t)0, (size_t)0, 2.0)
    A = matrix_set(A, (size_t)0, (size_t)1, 1.0)
    A = matrix_set(A, (size_t)0, (size_t)2, 1.0)
    A = matrix_set(A, (size_t)1, (size_t)0, 1.0)
    A = matrix_set(A, (size_t)1, (size_t)1, 2.0)
    A = matrix_set(A, (size_t)1, (size_t)2, 1.0)
    A = matrix_set(A, (size_t)2, (size_t)0, 1.0)
    A = matrix_set(A, (size_t)2, (size_t)1, 1.0)
    A = matrix_set(A, (size_t)2, (size_t)2, 2.0)
    print("det", matrix_det(A))
    print("tr", matrix_trace(A))
    Matrix Ai = matrix_inverse(A)
    Matrix prod = matrix_mul(A, Ai)
    print("diag00", prod.data[(size_t)0 * (size_t)3 + (size_t)0])
    print("diag11", prod.data[(size_t)1 * (size_t)3 + (size_t)1])
    Matrix b = matrix((size_t)3, (size_t)1)
    b.data[0] = 4.0
    b.data[1] = 4.0
    b.data[2] = 4.0
    Matrix x = matrix_solve(A, b)
    print("sol", x.data[0], x.data[1], x.data[2])
    Matrix L = matrix_cholesky(A)
    print("chol00", L.data[(size_t)0 * (size_t)3 + (size_t)0])
    Matrix C = matrix_qr_mgs(A)
    print("qr00", C.data[(size_t)0 * (size_t)3 + (size_t)0])
    print("m3 PASS")
