import stdlib
import math

# 4x4 matrix stored by explicit components (row-major naming).
struct Matrix4:
    double m00
    double m01
    double m02
    double m03
    double m10
    double m11
    double m12
    double m13
    double m20
    double m21
    double m22
    double m23
    double m30
    double m31
    double m32
    double m33

public def matrix4(m00 double, m01 double, m02 double, m03 double, m10 double, m11 double, m12 double, m13 double, m20 double, m21 double, m22 double, m23 double, m30 double, m31 double, m32 double, m33 double) -> Matrix4:
    Matrix4 m
    m.m00 = m00
    m.m01 = m01
    m.m02 = m02
    m.m03 = m03
    m.m10 = m10
    m.m11 = m11
    m.m12 = m12
    m.m13 = m13
    m.m20 = m20
    m.m21 = m21
    m.m22 = m22
    m.m23 = m23
    m.m30 = m30
    m.m31 = m31
    m.m32 = m32
    m.m33 = m33
    return m

public def matrix4_identity() -> Matrix4:
    return matrix4(1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)

public def matrix4_zero() -> Matrix4:
    return matrix4(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

# Build a 4x4 from a 3x3 rotation matrix and a translation vector, given as
# explicit components (row-major rotation entries r00..r22, translation t).
public def matrix4_from_rotation(r00 double, r01 double, r02 double, r10 double, r11 double, r12 double, r20 double, r21 double, r22 double, tx double, ty double, tz double) -> Matrix4:
    return matrix4(
        r00, r01, r02, tx,
        r10, r11, r12, ty,
        r20, r21, r22, tz,
        0.0, 0.0, 0.0, 1.0
    )

# Addition
public def matrix4_add(a Matrix4, b Matrix4) -> Matrix4:
    return matrix4(
        a.m00 + b.m00, a.m01 + b.m01, a.m02 + b.m02, a.m03 + b.m03,
        a.m10 + b.m10, a.m11 + b.m11, a.m12 + b.m12, a.m13 + b.m13,
        a.m20 + b.m20, a.m21 + b.m21, a.m22 + b.m22, a.m23 + b.m23,
        a.m30 + b.m30, a.m31 + b.m31, a.m32 + b.m32, a.m33 + b.m33
    )

# Subtraction
public def matrix4_sub(a Matrix4, b Matrix4) -> Matrix4:
    return matrix4(
        a.m00 - b.m00, a.m01 - b.m01, a.m02 - b.m02, a.m03 - b.m03,
        a.m10 - b.m10, a.m11 - b.m11, a.m12 - b.m12, a.m13 - b.m13,
        a.m20 - b.m20, a.m21 - b.m21, a.m22 - b.m22, a.m23 - b.m23,
        a.m30 - b.m30, a.m31 - b.m31, a.m32 - b.m32, a.m33 - b.m33
    )

# Scalar multiplication
public def matrix4_mul_scalar(a Matrix4, s double) -> Matrix4:
    return matrix4(
        a.m00 * s, a.m01 * s, a.m02 * s, a.m03 * s,
        a.m10 * s, a.m11 * s, a.m12 * s, a.m13 * s,
        a.m20 * s, a.m21 * s, a.m22 * s, a.m23 * s,
        a.m30 * s, a.m31 * s, a.m32 * s, a.m33 * s
    )

# Negation
public def matrix4_neg(a Matrix4) -> Matrix4:
    return matrix4_mul_scalar(a, -1.0)

# Matrix multiplication
public def matrix4_mul(a Matrix4, b Matrix4) -> Matrix4:
    return matrix4(
        a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20 + a.m03 * b.m30,
        a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21 + a.m03 * b.m31,
        a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22 + a.m03 * b.m32,
        a.m00 * b.m03 + a.m01 * b.m13 + a.m02 * b.m23 + a.m03 * b.m33,
        a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20 + a.m13 * b.m30,
        a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21 + a.m13 * b.m31,
        a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22 + a.m13 * b.m32,
        a.m10 * b.m03 + a.m11 * b.m13 + a.m12 * b.m23 + a.m13 * b.m33,
        a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20 + a.m23 * b.m30,
        a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21 + a.m23 * b.m31,
        a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22 + a.m23 * b.m32,
        a.m20 * b.m03 + a.m21 * b.m13 + a.m22 * b.m23 + a.m23 * b.m33,
        a.m30 * b.m00 + a.m31 * b.m10 + a.m32 * b.m20 + a.m33 * b.m30,
        a.m30 * b.m01 + a.m31 * b.m11 + a.m32 * b.m21 + a.m33 * b.m31,
        a.m30 * b.m02 + a.m31 * b.m12 + a.m32 * b.m22 + a.m33 * b.m32,
        a.m30 * b.m03 + a.m31 * b.m13 + a.m32 * b.m23 + a.m33 * b.m33
    )

# Apply the 4x4 homogeneous matrix to a vector (x, y, z, w), writing to out[0..3].
public def matrix4_apply(a Matrix4, x double, y double, z double, w double, out double*) -> void:
    out[0] = a.m00 * x + a.m01 * y + a.m02 * z + a.m03 * w
    out[1] = a.m10 * x + a.m11 * y + a.m12 * z + a.m13 * w
    out[2] = a.m20 * x + a.m21 * y + a.m22 * z + a.m23 * w
    out[3] = a.m30 * x + a.m31 * y + a.m32 * z + a.m33 * w

# Transform a 3D point given as components (ignores perspective row).
public def matrix4_transform_point_xyz(a Matrix4, x double, y double, z double, out double*) -> void:
    out[0] = a.m00 * x + a.m01 * y + a.m02 * z + a.m03
    out[1] = a.m10 * x + a.m11 * y + a.m12 * z + a.m13
    out[2] = a.m20 * x + a.m21 * y + a.m22 * z + a.m23

# Transform a 3D direction given as components (no translation).
public def matrix4_transform_direction_xyz(a Matrix4, x double, y double, z double, out double*) -> void:
    out[0] = a.m00 * x + a.m01 * y + a.m02 * z
    out[1] = a.m10 * x + a.m11 * y + a.m12 * z
    out[2] = a.m20 * x + a.m21 * y + a.m22 * z

# Transpose
public def matrix4_transpose(a Matrix4) -> Matrix4:
    return matrix4(
        a.m00, a.m10, a.m20, a.m30,
        a.m01, a.m11, a.m21, a.m31,
        a.m02, a.m12, a.m22, a.m32,
        a.m03, a.m13, a.m23, a.m33
    )

# Trace
public def matrix4_trace(a Matrix4) -> double:
    return a.m00 + a.m11 + a.m22 + a.m33

# Determinant
public def matrix4_det(a Matrix4) -> double:
    double s0 = a.m00 * a.m11 - a.m01 * a.m10
    double s1 = a.m00 * a.m12 - a.m02 * a.m10
    double s2 = a.m00 * a.m13 - a.m03 * a.m10
    double s3 = a.m01 * a.m12 - a.m02 * a.m11
    double s4 = a.m01 * a.m13 - a.m03 * a.m11
    double s5 = a.m02 * a.m13 - a.m03 * a.m12
    double c5 = a.m22 * a.m33 - a.m23 * a.m32
    double c4 = a.m21 * a.m33 - a.m23 * a.m31
    double c3 = a.m21 * a.m32 - a.m22 * a.m31
    double c2 = a.m20 * a.m33 - a.m23 * a.m30
    double c1 = a.m20 * a.m32 - a.m22 * a.m30
    double c0 = a.m20 * a.m31 - a.m21 * a.m30
    return s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0

# Inverse via cofactor expansion.
public def matrix4_inverse(a Matrix4) -> Matrix4:
    double s0 = a.m00 * a.m11 - a.m01 * a.m10
    double s1 = a.m00 * a.m12 - a.m02 * a.m10
    double s2 = a.m00 * a.m13 - a.m03 * a.m10
    double s3 = a.m01 * a.m12 - a.m02 * a.m11
    double s4 = a.m01 * a.m13 - a.m03 * a.m11
    double s5 = a.m02 * a.m13 - a.m03 * a.m12
    double c5 = a.m22 * a.m33 - a.m23 * a.m32
    double c4 = a.m21 * a.m33 - a.m23 * a.m31
    double c3 = a.m21 * a.m32 - a.m22 * a.m31
    double c2 = a.m20 * a.m33 - a.m23 * a.m30
    double c1 = a.m20 * a.m32 - a.m22 * a.m30
    double c0 = a.m20 * a.m31 - a.m21 * a.m30
    double det = s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0
    assert det != 0.0, "Matrix is singular, cannot invert"
    double id = 1.0 / det
    Matrix4 inv
    inv.m00 = (a.m11 * c5 - a.m12 * c4 + a.m13 * c3) * id
    inv.m01 = (-a.m01 * c5 + a.m02 * c4 - a.m03 * c3) * id
    inv.m02 = (a.m31 * s5 - a.m32 * s4 + a.m33 * s3) * id
    inv.m03 = (-a.m21 * s5 + a.m22 * s4 - a.m23 * s3) * id
    inv.m10 = (-a.m10 * c5 + a.m12 * c2 - a.m13 * c1) * id
    inv.m11 = (a.m00 * c5 - a.m02 * c2 + a.m03 * c1) * id
    inv.m12 = (-a.m30 * s5 + a.m32 * s2 - a.m33 * s1) * id
    inv.m13 = (a.m20 * s5 - a.m22 * s2 + a.m23 * s1) * id
    inv.m20 = (a.m10 * c4 - a.m11 * c2 + a.m13 * c0) * id
    inv.m21 = (-a.m00 * c4 + a.m01 * c2 - a.m03 * c0) * id
    inv.m22 = (a.m30 * s4 - a.m31 * s2 + a.m33 * s0) * id
    inv.m23 = (-a.m20 * s4 + a.m21 * s2 - a.m23 * s0) * id
    inv.m30 = (-a.m10 * c3 + a.m11 * c1 - a.m12 * c0) * id
    inv.m31 = (a.m00 * c3 - a.m01 * c1 + a.m02 * c0) * id
    inv.m32 = (-a.m30 * s3 + a.m31 * s1 - a.m32 * s0) * id
    inv.m33 = (a.m20 * s3 - a.m21 * s1 + a.m22 * s0) * id
    return inv

# Translation matrix (translation vector given as components).
public def matrix4_translation(tx double, ty double, tz double) -> Matrix4:
    return matrix4(1.0, 0.0, 0.0, tx, 0.0, 1.0, 0.0, ty, 0.0, 0.0, 1.0, tz, 0.0, 0.0, 0.0, 1.0)

# Scaling matrix (scale factors given as components).
public def matrix4_scaling(sx double, sy double, sz double) -> Matrix4:
    return matrix4(sx, 0.0, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, 0.0, sz, 0.0, 0.0, 0.0, 0.0, 1.0)

# Rotation matrix about the X, Y, Z axes embedded in 4x4 homogeneous form.
public def matrix4_rotation_x(angle double) -> Matrix4:
    double c = cos(angle)
    double s = sin(angle)
    return matrix4(1.0, 0.0, 0.0, 0.0, 0.0, c, -s, 0.0, 0.0, s, c, 0.0, 0.0, 0.0, 0.0, 1.0)

public def matrix4_rotation_y(angle double) -> Matrix4:
    double c = cos(angle)
    double s = sin(angle)
    return matrix4(c, 0.0, s, 0.0, 0.0, 1.0, 0.0, 0.0, -s, 0.0, c, 0.0, 0.0, 0.0, 0.0, 1.0)

public def matrix4_rotation_z(angle double) -> Matrix4:
    double c = cos(angle)
    double s = sin(angle)
    return matrix4(c, -s, 0.0, 0.0, s, c, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)

public def matrix4_rotation_axis(ax double, ay double, az double, angle double) -> Matrix4:
    double alen = sqrt(ax * ax + ay * ay + az * az)
    assert alen != 0.0, "Rotation axis cannot be zero"
    double x = ax / alen
    double y = ay / alen
    double z = az / alen
    double c = cos(angle)
    double s = sin(angle)
    double t = 1.0 - c
    return matrix4(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0.0,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0.0,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0.0,
        0.0, 0.0, 0.0, 1.0
    )

# Orthographic projection matrix
public def matrix4_orthographic(left double, right double, bottom double, top double, near double, far double) -> Matrix4:
    double rl = right - left
    double tb = top - bottom
    double fn = far - near
    assert rl != 0.0 and tb != 0.0 and fn != 0.0, "Orthographic frustum is degenerate"
    return matrix4(
        2.0 / rl, 0.0, 0.0, -(right + left) / rl,
        0.0, 2.0 / tb, 0.0, -(top + bottom) / tb,
        0.0, 0.0, -2.0 / fn, -(far + near) / fn,
        0.0, 0.0, 0.0, 1.0
    )

# Perspective projection matrix
public def matrix4_perspective(fov_y double, aspect double, near double, far double) -> Matrix4:
    assert aspect != 0.0 and far != near, "Invalid perspective parameters"
    double f = 1.0 / tan(fov_y / 2.0)
    double fn = far - near
    return matrix4(
        f / aspect, 0.0, 0.0, 0.0,
        0.0, f, 0.0, 0.0,
        0.0, 0.0, (far + near) / fn, 2.0 * far * near / fn,
        0.0, 0.0, -1.0, 0.0
    )

# Look-at view matrix. eye/target/up given as components. The cross-type
# Vector3-based form lives in the aggregator module.
public def matrix4_look_at(ex double, ey double, ez double, tx double, ty double, tz double, upx double, upy double, upz double) -> Matrix4:
    double zx = ex - tx
    double zy = ey - ty
    double zz = ez - tz
    double zlen = sqrt(zx * zx + zy * zy + zz * zz)
    assert zlen != 0.0, "Eye and target must differ"
    zx = zx / zlen
    zy = zy / zlen
    zz = zz / zlen
    double xx = upy * zz - upz * zy
    double xy = upz * zx - upx * zz
    double xz = upx * zy - upy * zx
    double xlen = sqrt(xx * xx + xy * xy + xz * xz)
    if xlen == 0.0:
        xx = 1.0
        xy = 0.0
        xz = 0.0
        xlen = 1.0
    xx = xx / xlen
    xy = xy / xlen
    xz = xz / xlen
    double yx = zy * xz - zz * xy
    double yy = zz * xx - zx * xz
    double yz = zx * xy - zy * xx
    return matrix4(
        xx, xy, xz, -(xx * ex + xy * ey + xz * ez),
        yx, yy, yz, -(yx * ex + yy * ey + yz * ez),
        zx, zy, zz, -(zx * ex + zy * ey + zz * ez),
        0.0, 0.0, 0.0, 1.0
    )
