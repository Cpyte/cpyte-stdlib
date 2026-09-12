import stdlib
import math

# 3x3 matrix stored by explicit components (row-major naming).
struct Matrix3:
    double m00
    double m01
    double m02
    double m10
    double m11
    double m12
    double m20
    double m21
    double m22

public def matrix3(m00 double, m01 double, m02 double, m10 double, m11 double, m12 double, m20 double, m21 double, m22 double) -> Matrix3:
    Matrix3 m
    m.m00 = m00
    m.m01 = m01
    m.m02 = m02
    m.m10 = m10
    m.m11 = m11
    m.m12 = m12
    m.m20 = m20
    m.m21 = m21
    m.m22 = m22
    return m

public def matrix3_identity() -> Matrix3:
    return matrix3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)

public def matrix3_zero() -> Matrix3:
    return matrix3(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

# Addition
public def matrix3_add(a Matrix3, b Matrix3) -> Matrix3:
    return matrix3(
        a.m00 + b.m00, a.m01 + b.m01, a.m02 + b.m02,
        a.m10 + b.m10, a.m11 + b.m11, a.m12 + b.m12,
        a.m20 + b.m20, a.m21 + b.m21, a.m22 + b.m22
    )

# Subtraction
public def matrix3_sub(a Matrix3, b Matrix3) -> Matrix3:
    return matrix3(
        a.m00 - b.m00, a.m01 - b.m01, a.m02 - b.m02,
        a.m10 - b.m10, a.m11 - b.m11, a.m12 - b.m12,
        a.m20 - b.m20, a.m21 - b.m21, a.m22 - b.m22
    )

# Scalar multiplication
public def matrix3_mul_scalar(a Matrix3, s double) -> Matrix3:
    return matrix3(
        a.m00 * s, a.m01 * s, a.m02 * s,
        a.m10 * s, a.m11 * s, a.m12 * s,
        a.m20 * s, a.m21 * s, a.m22 * s
    )

# Negation
public def matrix3_neg(a Matrix3) -> Matrix3:
    return matrix3_mul_scalar(a, -1.0)

# Matrix multiplication
public def matrix3_mul(a Matrix3, b Matrix3) -> Matrix3:
    return matrix3(
        a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20,
        a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21,
        a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
        a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20,
        a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21,
        a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
        a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20,
        a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21,
        a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22
    )

# Matrix-vector multiplication (takes explicit components, returns xyz triple).
# The cross-type tuple form is provided in the aggregator module.
public def matrix3_apply(a Matrix3, x double, y double, z double, out double*) -> void:
    out[0] = a.m00 * x + a.m01 * y + a.m02 * z
    out[1] = a.m10 * x + a.m11 * y + a.m12 * z
    out[2] = a.m20 * x + a.m21 * y + a.m22 * z

# Transpose
public def matrix3_transpose(a Matrix3) -> Matrix3:
    return matrix3(
        a.m00, a.m10, a.m20,
        a.m01, a.m11, a.m21,
        a.m02, a.m12, a.m22
    )

# Trace
public def matrix3_trace(a Matrix3) -> double:
    return a.m00 + a.m11 + a.m22

# Determinant
public def matrix3_det(a Matrix3) -> double:
    return (
        a.m00 * (a.m11 * a.m22 - a.m12 * a.m21)
        - a.m01 * (a.m10 * a.m22 - a.m12 * a.m20)
        + a.m02 * (a.m10 * a.m21 - a.m11 * a.m20)
    )

# Cofactor matrix
public def matrix3_cofactor(a Matrix3) -> Matrix3:
    return matrix3(
        a.m11 * a.m22 - a.m12 * a.m21,
        -(a.m10 * a.m22 - a.m12 * a.m20),
        a.m10 * a.m21 - a.m11 * a.m20,
        -(a.m01 * a.m22 - a.m02 * a.m21),
        a.m00 * a.m22 - a.m02 * a.m20,
        -(a.m00 * a.m21 - a.m01 * a.m20),
        a.m01 * a.m12 - a.m02 * a.m11,
        -(a.m00 * a.m12 - a.m02 * a.m10),
        a.m00 * a.m11 - a.m01 * a.m10
    )

# Adjugate (transpose of cofactor)
public def matrix3_adjugate(a Matrix3) -> Matrix3:
    return matrix3_transpose(matrix3_cofactor(a))

# Inverse via adjugate / determinant
public def matrix3_inverse(a Matrix3) -> Matrix3:
    double det = matrix3_det(a)
    assert det != 0.0, "Matrix is singular, cannot invert"
    double inv_det = 1.0 / det
    return matrix3_mul_scalar(matrix3_adjugate(a), inv_det)

# Rotation matrix about the X axis (angle in radians)
public def matrix3_rotation_x(angle double) -> Matrix3:
    double c = cos(angle)
    double s = sin(angle)
    return matrix3(1.0, 0.0, 0.0, 0.0, c, -s, 0.0, s, c)

# Rotation matrix about the Y axis (angle in radians)
public def matrix3_rotation_y(angle double) -> Matrix3:
    double c = cos(angle)
    double s = sin(angle)
    return matrix3(c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c)

# Rotation matrix about the Z axis (angle in radians)
public def matrix3_rotation_z(angle double) -> Matrix3:
    double c = cos(angle)
    double s = sin(angle)
    return matrix3(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)

# Rotation matrix from an arbitrary axis and angle (Rodrigues).
# Axis is given by explicit components; it is normalized internally.
public def matrix3_rotation_axis(ax double, ay double, az double, angle double) -> Matrix3:
    double alen = sqrt(ax * ax + ay * ay + az * az)
    assert alen != 0.0, "Rotation axis cannot be zero"
    double x = ax / alen
    double y = ay / alen
    double z = az / alen
    double c = cos(angle)
    double s = sin(angle)
    double t = 1.0 - c
    return matrix3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c
    )

# Scaling matrix
public def matrix3_scaling(sx double, sy double, sz double) -> Matrix3:
    return matrix3(sx, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, sz)

# Reflection matrix across a plane through the origin with given normal
# components (normal is normalized internally).
public def matrix3_reflection(nx double, ny double, nz double) -> Matrix3:
    double nlen = sqrt(nx * nx + ny * ny + nz * nz)
    assert nlen != 0.0, "Reflection normal cannot be zero"
    double x = nx / nlen
    double y = ny / nlen
    double z = nz / nlen
    return matrix3(
        1.0 - 2.0 * x * x, -2.0 * x * y, -2.0 * x * z,
        -2.0 * x * y, 1.0 - 2.0 * y * y, -2.0 * y * z,
        -2.0 * x * z, -2.0 * y * z, 1.0 - 2.0 * z * z
    )
