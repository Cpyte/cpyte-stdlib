# Interpolation helpers over raw double* tables. Self-contained (uses only
# stdlib/math). Includes linear/bilinear/trilinear lookups, Lagrange
# polynomial evaluation, cubic Hermite, and a natural cubic spline
# (coefficient build via tridiagonal (Thomas) solve + evaluation).

import stdlib
import math

# Clamp a value to [lo, hi].
public def interp_clamp(value double, lo double, hi double) -> double:
    if value < lo:
        return lo
    if value > hi:
        return hi
    return value

# Linear interpolation between a and b at parameter t.
public def interp_lerp(a double, b double, t double) -> double:
    return a + (b - a) * t

# Find the largest index i with xs[i] <= x (binary search). Returns an index
# clamped into [0, n-2].
public def interp_bracket(xs double*, n int, x double) -> int:
    if x <= xs[0]:
        return 0
    int hi = n - 1
    if x >= xs[hi]:
        return n - 2
    int lo = 0
    int mi = 0
    while lo < hi:
        mi = lo + (hi - lo) / 2
        if xs[mi] < x:
            lo = mi + 1
        else:
            hi = mi
    int idx = lo - 1
    if idx < 0:
        idx = 0
    if idx > n - 2:
        idx = n - 2
    return idx

# 1D linear interpolation on a monotonic table (x must be sorted ascending).
public def interp_linear(xs double*, ys double*, n int, x double) -> double:
    int i = interp_bracket(xs, n, x)
    double x0 = xs[i]
    double x1 = xs[i + 1]
    double t = 0.0
    if x1 > x0:
        t = (x - x0) / (x1 - x0)
    return interp_lerp(ys[i], ys[i + 1], t)

# Bilinear interpolation on a regular 2D grid.
# xs (nx), ys (ny), zs is nx*ny (row-major, indexed by [i*nx + j] where i is
# the ys row and j the xs column). Evaluates at (x, y).
public def interp_bilinear(xs double*, ys double*, zs double*, nx int, ny int, x double, y double) -> double:
    int j = interp_bracket(xs, nx, x)
    int i = interp_bracket(ys, ny, y)
    double x0 = xs[j]
    double x1 = xs[j + 1]
    double y0 = ys[i]
    double y1 = ys[i + 1]
    double tx = 0.0
    double ty = 0.0
    if x1 > x0:
        tx = (x - x0) / (x1 - x0)
    if y1 > y0:
        ty = (y - y0) / (y1 - y0)
    double z00 = zs[i * nx + j]
    double z10 = zs[i * nx + j + 1]
    double z01 = zs[(i + 1) * nx + j]
    double z11 = zs[(i + 1) * nx + j + 1]
    double interp_y0 = interp_lerp(z00, z10, tx)
    double interp_y1 = interp_lerp(z01, z11, tx)
    return interp_lerp(interp_y0, interp_y1, ty)

# Trilinear interpolation on a regular 3D grid.
# xs(nx), ys(ny), zs-dim(nz); v indexed by i*nx*ny + j*nx + k where i is z,
# j is y, k is x. Evaluates at (x, y, z).
public def interp_trilinear(xs double*, ys double*, zs double*, v double*, nx int, ny int, nz int, x double, y double, z double) -> double:
    int k = interp_bracket(xs, nx, x)
    int j = interp_bracket(ys, ny, y)
    int i = interp_bracket(zs, nz, z)
    double x0 = xs[k]
    double x1 = xs[k + 1]
    double y0 = ys[j]
    double y1 = ys[j + 1]
    double z0 = zs[i]
    double z1 = zs[i + 1]
    double tx = 0.0
    double ty = 0.0
    double tz = 0.0
    if x1 > x0:
        tx = (x - x0) / (x1 - x0)
    if y1 > y0:
        ty = (y - y0) / (y1 - y0)
    if z1 > z0:
        tz = (z - z0) / (z1 - z0)
    int nxny = nx * ny
    # bottom face (z=z0), four corners in x,y
    double c000 = v[i * nxny + j * nx + k]
    double c100 = v[i * nxny + j * nx + k + 1]
    double c010 = v[i * nxny + (j + 1) * nx + k]
    double c110 = v[i * nxny + (j + 1) * nx + k + 1]
    double c001 = v[(i + 1) * nxny + j * nx + k]
    double c101 = v[(i + 1) * nxny + j * nx + k + 1]
    double c011 = v[(i + 1) * nxny + (j + 1) * nx + k]
    double c111 = v[(i + 1) * nxny + (j + 1) * nx + k + 1]
    double a00 = interp_lerp(c000, c100, tx)
    double a10 = interp_lerp(c010, c110, tx)
    double a01 = interp_lerp(c001, c101, tx)
    double a11 = interp_lerp(c011, c111, tx)
    double b0 = interp_lerp(a00, a10, ty)
    double b1 = interp_lerp(a01, a11, ty)
    return interp_lerp(b0, b1, tz)

# Lagrange polynomial interpolation through n points (xs, ys) evaluated at x.
public def interp_lagrange(xs double*, ys double*, n int, x double) -> double:
    double acc = 0.0
    for i in range(n):
        double term = ys[i]
        for j in range(n):
            if j != i:
                double denom = xs[i] - xs[j]
                if denom != 0.0:
                    term = term * (x - xs[j]) / denom
        acc = acc + term
    return acc

# Cubic Hermite interpolation. y0,y1 values; m0,m1 slopes; t in [0,1].
public def interp_cubic_hermite(y0 double, y1 double, m0 double, m1 double, t double) -> double:
    double t2 = t * t
    double t3 = t2 * t
    double h00 = 2.0 * t3 - 3.0 * t2 + 1.0
    double h10 = t3 - 2.0 * t2 + t
    double h01 = -2.0 * t3 + 3.0 * t2
    double h11 = t3 - t2
    return h00 * y0 + h10 * m0 + h01 * y1 + h11 * m1

# Build natural cubic spline second-derivative coefficients into M (length n)
# for knots xs (sorted ascending) and data ys. Natural (zero curvature)
# boundary conditions: M[0] = M[n-1] = 0.
public def interp_spline_coeffs(xs double*, ys double*, n int, M double*) -> void:
    M[0] = 0.0
    M[n - 1] = 0.0
    if n < 3:
        return
    int m = n - 2
    double* a = (double*)malloc((size_t)(sizeof(double) * m))
    double* bmat = (double*)malloc((size_t)(sizeof(double) * m))
    double* d = (double*)malloc((size_t)(sizeof(double) * m))
    double* c = (double*)malloc((size_t)(sizeof(double) * m))
    for i in range(1, n - 1):
        int idx = i - 1
        double hp = xs[i] - xs[i - 1]
        double hn = xs[i + 1] - xs[i]
        double rhs = (ys[i + 1] - ys[i]) / hn - (ys[i] - ys[i - 1]) / hp
        d[idx] = 6.0 * rhs
        bmat[idx] = 2.0 * (hp + hn)
        if idx > 0:
            a[idx] = hp
        if idx < m - 1:
            c[idx] = hn
    a[0] = 0.0
    c[m - 1] = 0.0
    # Thomas algorithm
    for i in range(1, m):
        double wfac = a[i] / bmat[i - 1]
        bmat[i] = bmat[i] - wfac * c[i - 1]
        d[i] = d[i] - wfac * d[i - 1]
    M[1 + m - 1] = d[m - 1] / bmat[m - 1]
    for i in range(m - 2, -1, -1):
        M[1 + 0 + i] = (d[i] - c[i] * M[1 + 0 + i + 1]) / bmat[i]
    free(a)
    free(bmat)
    free(d)
    free(c)

# Evaluate a natural cubic spline built by interp_spline_coeffs at x.
public def interp_spline_eval(xs double*, ys double*, M double*, n int, x double) -> double:
    int i = interp_bracket(xs, n, x)
    double h = xs[i + 1] - xs[i]
    double t = 0.0
    if h > 0.0:
        t = (x - xs[i]) / h
    double Mi = M[i]
    double Mi1 = M[i + 1]
    double one_minus_t = 1.0 - t
    double A = (1.0 - t) * ys[i] + t * ys[i + 1]
    double hh = h * h / 6.0
    double B = hh * ((t * t * t - t) * Mi + (one_minus_t * one_minus_t * one_minus_t - one_minus_t) * Mi1)
    return A + B
