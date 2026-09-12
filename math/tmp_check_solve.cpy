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
    Matrix b = matrix((size_t)3, (size_t)1)
    b = matrix_set(b, (size_t)0, (size_t)0, 4.0)
    b = matrix_set(b, (size_t)1, (size_t)0, 4.0)
    b = matrix_set(b, (size_t)2, (size_t)0, 4.0)
    Matrix x = matrix_solve(A, b)
    print("x0", x.data[0])
    print("x1", x.data[1])
    print("x2", x.data[2])
    print("g0", matrix_get(x, (size_t)0, (size_t)0))
    print("g1", matrix_get(x, (size_t)1, (size_t)0))
