# Functional self-checks for @std/math. Every expected value is cross-checked
# against CPython (math / statistics) rather than the library itself, so this
# suite catches algorithmic drift, not just crashes.
#
#   cpy test_math.cpy   -> prints one "ok"/"FAIL" line per assertion and exits
#                          with the total number of failures
#
# Buffer arguments are cast to `double*` at the call: cpyte keeps array types
# distinct from pointer types, so a `double[]` local is not implicitly decayed
# where a `double*` parameter is declared.
import "main.cpy"

def near(name str, got double, want double) -> int:
    double diff = got - want
    if diff < 0.0:
        diff = diff * -1.0
    if diff > 0.000000001:
        print("  FAIL  " + name + "  want " + str(want) + "  got " + str(got))
        return 1
    print("  ok    " + name)
    return 0

def eq_int(name str, got int64, want int64) -> int:
    if got != want:
        print("  FAIL  " + name + "  want " + str(want) + "  got " + str(got))
        return 1
    print("  ok    " + name)
    return 0

# ------------------------------------------------------------------ scalar

def test_scalar() -> int:
    int n = 0
    n += near("clamp hi", scalar_clamp(5.0, 0.0, 3.0), 3.0)
    n += near("clamp lo", scalar_clamp(-1.0, 0.0, 3.0), 0.0)
    n += near("clamp mid", scalar_clamp(2.0, 0.0, 3.0), 2.0)
    n += near("lerp", scalar_lerp(0.0, 10.0, 0.25), 2.5)
    n += near("sqrt2", scalar_sqrt(2.0), 1.4142135623730951)
    n += near("hypot 3-4", scalar_hypot(3.0, 4.0), 5.0)
    n += near("sin 0.5", scalar_sin(0.5), 0.479425538604203)
    n += near("cos 0.5", scalar_cos(0.5), 0.8775825618903728)
    n += eq_int("max_int", numeric_max_int(3, 7), 7)
    return n

# -------------------------------------------------------------- statistics

def test_statistics() -> int:
    double[] v = new double[8]
    v[0] = 2.0
    v[1] = 4.0
    v[2] = 4.0
    v[3] = 4.0
    v[4] = 5.0
    v[5] = 5.0
    v[6] = 7.0
    v[7] = 9.0
    int n = 0
    n += near("sum", stats_sum((double*)v, 8), 40.0)
    n += near("mean", stats_mean((double*)v, 8), 5.0)
    n += near("min", stats_min((double*)v, 8), 2.0)
    n += near("max", stats_max((double*)v, 8), 9.0)
    # variance is the population form (divide by n), sample_variance by n-1
    n += near("variance", stats_variance((double*)v, 8), 4.0)
    n += near("sample variance", stats_sample_variance((double*)v, 8), 32.0 / 7.0)
    n += near("stddev", stats_stddev((double*)v, 8), 2.0)
    # rms = sqrt(sum(v*v)/n) = sqrt(232/8)
    n += near("rms", stats_rms((double*)v, 8), 5.385164807134504)
    return n

# ----------------------------------------------------------------- complex

def test_complex() -> int:
    Complex a = complex_make(1.0, 2.0)
    Complex b = complex_make(3.0, 4.0)
    Complex s = complex_add(a, b)
    Complex p = complex_mul(a, b)
    Complex c = complex_conjugate(a)
    int n = 0
    n += near("cadd re", s.real, 4.0)
    n += near("cadd im", s.imag, 6.0)
    n += near("cmul re", p.real, -5.0)
    n += near("cmul im", p.imag, 10.0)
    n += near("cconj im", c.imag, -2.0)
    return n

# ----------------------------------------------------------------- vector3

def test_vector3() -> int:
    Vector3 a = vector3(1.0, 2.0, 3.0)
    Vector3 b = vector3(4.0, 5.0, 6.0)
    Vector3 x = vector3_cross(vector3(1.0, 0.0, 0.0), vector3(0.0, 1.0, 0.0))
    Vector3 u = vector3_normalize(vector3(0.0, 3.0, 0.0))
    Vector3 d = vector3_sub(b, a)
    int n = 0
    n += near("dot", vector3_dot(a, b), 32.0)
    n += near("cross x", x.x, 0.0)
    n += near("cross z", x.z, 1.0)
    n += near("magnitude 3-4", vector3_magnitude(vector3(3.0, 4.0, 0.0)), 5.0)
    n += near("normalize y", u.y, 1.0)
    n += near("sub x", d.x, 3.0)
    return n

# ------------------------------------------------------------------ matrix

def test_matrix() -> int:
    double[] a = new double[9]
    a[0] = 6.0
    a[1] = 4.0
    a[2] = 4.0
    a[3] = 5.0
    a[4] = 8.0
    a[5] = 7.0
    a[6] = 4.0
    a[7] = 2.0
    a[8] = 5.0
    Matrix m = matrix_from_data((size_t)3, (size_t)3, (double*)a)
    Matrix i3 = matrix_identity((size_t)3)
    Matrix t = matrix_transpose(m)

    # (2x3) * (3x2) = [[58, 64], [139, 154]]
    double[] bb = new double[6]
    bb[0] = 1.0
    bb[1] = 2.0
    bb[2] = 3.0
    bb[3] = 4.0
    bb[4] = 5.0
    bb[5] = 6.0
    double[] cc = new double[6]
    cc[0] = 7.0
    cc[1] = 8.0
    cc[2] = 9.0
    cc[3] = 10.0
    cc[4] = 11.0
    cc[5] = 12.0
    Matrix left = matrix_from_data((size_t)2, (size_t)3, (double*)bb)
    Matrix right = matrix_from_data((size_t)3, (size_t)2, (double*)cc)
    Matrix p = matrix_mul(left, right)

    double[] rhs = new double[3]
    rhs[0] = 1.0
    rhs[1] = 2.0
    rhs[2] = 3.0
    Matrix bmat = matrix_from_data((size_t)3, (size_t)1, (double*)rhs)
    Matrix xs = matrix_solve(m, bmat)
    Matrix back = matrix_mul(m, xs)
    Matrix prod = matrix_mul(m, matrix_inverse(m))

    int n = 0
    n += near("det 3x3", matrix_det(m), 80.0)
    n += near("identity diag", matrix_get(i3, (size_t)1, (size_t)1), 1.0)
    n += near("identity off", matrix_get(i3, (size_t)0, (size_t)1), 0.0)
    n += near("transpose", matrix_get(t, (size_t)2, (size_t)0), 4.0)
    n += near("mul 00", matrix_get(p, (size_t)0, (size_t)0), 58.0)
    n += near("mul 01", matrix_get(p, (size_t)0, (size_t)1), 64.0)
    n += near("mul 10", matrix_get(p, (size_t)1, (size_t)0), 139.0)
    n += near("mul 11", matrix_get(p, (size_t)1, (size_t)1), 154.0)
    # m * (m^-1 b) must reproduce b
    n += near("solve check 0", matrix_get(back, (size_t)0, (size_t)0), 1.0)
    n += near("solve check 1", matrix_get(back, (size_t)1, (size_t)0), 2.0)
    n += near("solve check 2", matrix_get(back, (size_t)2, (size_t)0), 3.0)
    n += near("inverse I 00", matrix_get(prod, (size_t)0, (size_t)0), 1.0)
    n += near("inverse I 11", matrix_get(prod, (size_t)1, (size_t)1), 1.0)
    n += near("inverse off 01", matrix_get(prod, (size_t)0, (size_t)1), 0.0)
    return n

# ------------------------------------------------------------- interpolate

def test_interpolate() -> int:
    double[] xs = new double[4]
    double[] ys = new double[4]
    int i = 0
    while i < 4:
        xs[i] = (double)i
        ys[i] = (double)(i * i)
        i = i + 1
    double[] mm = new double[4]
    interp_spline_coeffs((double*)xs, (double*)ys, 4, (double*)mm)
    int n = 0
    n += near("linear at knot", interp_linear((double*)xs, (double*)ys, 4, 2.0), 4.0)
    n += near("linear mid", interp_linear((double*)xs, (double*)ys, 4, 0.5), 0.5)
    n += near("lagrange 1.5", interp_lagrange((double*)xs, (double*)ys, 4, 1.5), 2.25)
    n += near("spline knot 0", interp_spline_eval((double*)xs, (double*)ys, (double*)mm, 4, 0.0), 0.0)
    n += near("spline knot 1", interp_spline_eval((double*)xs, (double*)ys, (double*)mm, 4, 1.0), 1.0)
    n += near("spline knot 2", interp_spline_eval((double*)xs, (double*)ys, (double*)mm, 4, 2.0), 4.0)
    n += near("spline knot 3", interp_spline_eval((double*)xs, (double*)ys, (double*)mm, 4, 3.0), 9.0)
    n += near("clamp below", interp_clamp(-2.0, 0.0, 1.0), 0.0)
    n += near("hermite mid", interp_cubic_hermite(0.0, 1.0, 1.0, 1.0, 0.5), 0.5)
    return n

# -------------------------------------------------------------- transforms

def test_transforms() -> int:
    double[] out = new double[2]
    polar_to_cartesian(1.0, 0.5, (double*)out)
    double[] back = new double[2]
    cartesian_to_polar(out[0], out[1], (double*)back)
    double[] sph = new double[3]
    spherical_to_cartesian(2.0, 0.5, 0.75, (double*)sph)
    int n = 0
    n += near("polar x", out[0], 0.8775825618903728)
    n += near("polar y", out[1], 0.479425538604203)
    n += near("polar round-trip r", back[0], 1.0)
    n += near("polar round-trip theta", back[1], 0.5)
    # a spherical point at radius 2 has squared norm 4
    n += near("spherical |v|^2", stats_dot((double*)sph, (double*)sph, 3), 4.0)
    return n

# ----------------------------------------------------------------- discrete

def test_discrete() -> int:
    ExtendedGCDResult g = extended_gcd(240, 46)
    int[] primes = prime_sieve(30)
    int n = 0
    n += eq_int("euc_gcd", euc_gcd(48, 18), 6)
    n += eq_int("bin_gcd", bin_gcd(48, 18), 6)
    n += eq_int("lcm", lcm(4, 6), 12)
    n += eq_int("mod_pow", mod_pow(7, 13, 11), 2)
    n += eq_int("inverse_mod", inverse_mod(3, 11), 4)
    n += eq_int("is_prime 97", is_prime(97), 1)
    n += eq_int("is_prime 91", is_prime(91), 0)
    n += eq_int("is_prime 2", is_prime(2), 1)
    n += eq_int("is_prime 1", is_prime(1), 0)
    n += eq_int("extgcd gcd", g.gcd, 2)
    n += eq_int("extgcd identity", 240 * g.x + 46 * g.y, 2)
    n += eq_int("sieve count", len(primes), 10)
    n += eq_int("sieve last", primes[9], 29)
    return n

# ------------------------------------------------------------------ sparse

def test_sparse() -> int:
    # Diagonal entries stored out of order, to exercise sparse_build's sort.
    SparseMatrix raw = sparse_matrix(3, 3, 3)
    raw = sparse_set(raw, 0, 2, 2, 3.0)
    raw = sparse_set(raw, 1, 0, 0, 1.0)
    raw = sparse_set(raw, 2, 1, 1, 2.0)
    SparseMatrix sp = sparse_build(raw)
    double[] x = new double[3]
    double[] y = new double[3]
    x[0] = 10.0
    x[1] = 20.0
    x[2] = 30.0
    sparse_spmv(sp, (double*)x, (double*)y)
    int n = 0
    n += near("spmv 0", y[0], 10.0)
    n += near("spmv 1", y[1], 40.0)
    n += near("spmv 2", y[2], 90.0)
    n += eq_int("row_ptr end", sp.row_ptr[3], 3)
    sparse_free(raw)
    sparse_free_bare(sp)
    return n

# -------------------------------------------------------------- fixed size

def test_fixed() -> int:
    # Rotation about z by 90 degrees maps (1,0,0) -> (0,1,0).
    Matrix3 r = matrix3_rotation_z(1.5707963267948966)
    double[] out = new double[3]
    matrix3_apply(r, 1.0, 0.0, 0.0, (double*)out)
    Matrix3 orth = matrix3_mul(r, matrix3_transpose(r))
    int n = 0
    n += near("rotz x", out[0], 0.0)
    n += near("rotz y", out[1], 1.0)
    n += near("rotz z", out[2], 0.0)
    n += near("rotz det", matrix3_det(r), 1.0)
    n += near("rotz R*R^T trace", matrix3_trace(orth), 3.0)
    return n

def main() -> int:
    int n = 0
    print("scalar:")
    n += test_scalar()
    print("statistics:")
    n += test_statistics()
    print("complex:")
    n += test_complex()
    print("vector3:")
    n += test_vector3()
    print("matrix:")
    n += test_matrix()
    print("interpolate:")
    n += test_interpolate()
    print("transforms:")
    n += test_transforms()
    print("discrete:")
    n += test_discrete()
    print("sparse:")
    n += test_sparse()
    print("matrix3:")
    n += test_fixed()
    if n == 0:
        print("all math checks pass")
    else:
        print(n, "math checks FAILED")
    return n
