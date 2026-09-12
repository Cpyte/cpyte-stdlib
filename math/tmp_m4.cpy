import stdlib
import "vectorn.cpy"
import "sparse.cpy"
import "statistics.cpy"
import "transforms.cpy"
import "interpolate.cpy"

def main():
    VectorN v = vectorn((size_t)3)
    v = vectorn_set(v, (size_t)0, 1.0)
    v = vectorn_set(v, (size_t)1, 2.0)
    v = vectorn_set(v, (size_t)2, 3.0)
    print("vn0", v.data[(size_t)0], v.data[(size_t)1], v.data[(size_t)2])
    print("vnlen", vectorn_norm(v))
    VectorN w = vectorn((size_t)3)
    w = vectorn_set(w, (size_t)0, 4.0)
    w = vectorn_set(w, (size_t)1, 5.0)
    w = vectorn_set(w, (size_t)2, 6.0)
    print("vndot", vectorn_dot(v, w))

    SparseMatrix sp = sparse_matrix(3, 3, 5)
    sp = sparse_set(sp, 0, 0, 0, 2.0)
    sp = sparse_set(sp, 1, 0, 1, 1.0)
    sp = sparse_set(sp, 2, 1, 0, 1.0)
    sp = sparse_set(sp, 3, 1, 1, 2.0)
    sp = sparse_set(sp, 4, 2, 2, 2.0)
    sp = sparse_build(sp)
    double[] x = new double[3]
    x[0] = 1.0
    x[1] = 0.0
    x[2] = 0.0
    double[] y = new double[3]
    sparse_spmv(sp, (double*)x, (double*)y)
    print("spmv", y[0], y[1], y[2])

    double[] xs = new double[3]
    xs[0] = 1.0
    xs[1] = 2.0
    xs[2] = 3.0
    print("interp", interp_linear((double*)xs, (double*)xs, 3, 1.5))
    print("m4 PASS")
