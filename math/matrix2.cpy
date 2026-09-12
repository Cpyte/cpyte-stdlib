import stdlib
import math

# 2x2 matrix stored by explicit components (row-major naming).
struct Matrix2:
    double m00
    double m01
    double m10
    double m11

public def matrix2(m00 double, m01 double, m10 double, m11 double) -> Matrix2:
    Matrix2 m
    m.m00 = m00
    m.m01 = m01
    m.m10 = m10
    m.m11 = m11
    return m

public def matrix2_identity() -> Matrix2:
    return matrix2(1.0, 0.0, 0.0, 1.0)

public def matrix2_zero() -> Matrix2:
    return matrix2(0.0, 0.0, 0.0, 0.0)

# Addition
public def matrix2_add(a Matrix2, b Matrix2) -> Matrix2:
    return matrix2(a.m00 + b.m00, a.m01 + b.m01, a.m10 + b.m10, a.m11 + b.m11)

# Subtraction
public def matrix2_sub(a Matrix2, b Matrix2) -> Matrix2:
    return matrix2(a.m00 - b.m00, a.m01 - b.m01, a.m10 - b.m10, a.m11 - b.m11)

# Scalar multiplication
public def matrix2_mul_scalar(a Matrix2, s double) -> Matrix2:
    return matrix2(a.m00 * s, a.m01 * s, a.m10 * s, a.m11 * s)

# Negation
public def matrix2_neg(a Matrix2) -> Matrix2:
    return matrix2_mul_scalar(a, -1.0)

# Matrix multiplication
public def matrix2_mul(a Matrix2, b Matrix2) -> Matrix2:
    return matrix2(
        a.m00 * b.m00 + a.m01 * b.m10,
        a.m00 * b.m01 + a.m01 * b.m11,
        a.m10 * b.m00 + a.m11 * b.m10,
        a.m10 * b.m01 + a.m11 * b.m11
    )

# Transpose
public def matrix2_transpose(a Matrix2) -> Matrix2:
    return matrix2(a.m00, a.m10, a.m01, a.m11)

# Trace
public def matrix2_trace(a Matrix2) -> double:
    return a.m00 + a.m11

# Determinant
public def matrix2_det(a Matrix2) -> double:
    return a.m00 * a.m11 - a.m01 * a.m10

# Inverse
public def matrix2_inverse(a Matrix2) -> Matrix2:
    double det = matrix2_det(a)
    assert det != 0.0, "Matrix is singular, cannot invert"
    double inv_det = 1.0 / det
    return matrix2(
        a.m11 * inv_det,
        -a.m01 * inv_det,
        -a.m10 * inv_det,
        a.m00 * inv_det
    )

# Cofactor matrix
public def matrix2_cofactor(a Matrix2) -> Matrix2:
    return matrix2(
        a.m11, -a.m01,
        -a.m10, a.m00
    )

# Adjugate (transpose of cofactor)
public def matrix2_adjugate(a Matrix2) -> Matrix2:
    return matrix2(
        a.m11, -a.m10,
        -a.m01, a.m00
    )

# Create a 2-name rotation matrix (angle in radians)
public def matrix2_rotation(angle double) -> Matrix2:
    double c = cos(angle)
    double s = sin(angle)
    return matrix2(c, -s, s, c)

# Create a scaling matrix
public def matrix2_scaling(sx double, sy double) -> Matrix2:
    return matrix2(sx, 0.0, 0.0, sy)

# Create a reflection matrix across a line through the origin with normal components
public def matrix2_reflection(nx double, ny double) -> Matrix2:
    double len2 = nx * nx + ny * ny
    assert len2 != 0.0, "Reflection normal cannot be zero"
    return matrix2(
        1.0 - 2.0 * nx * nx / len2, -2.0 * nx * ny / len2,
        -2.0 * nx * ny / len2, 1.0 - 2.0 * ny * ny / len2
    )

