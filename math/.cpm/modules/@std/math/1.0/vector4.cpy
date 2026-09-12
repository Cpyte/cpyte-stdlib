import stdlib
import math

# 4D Vector struct for mathematical operations
struct Vector4:
    double x
    double y
    double z
    double w

public def vector4(x double, y double, z double, w double) -> Vector4:
    Vector4 v
    v.x = x
    v.y = y
    v.z = z
    v.w = w
    return v

public def vector4_zero() -> Vector4:
    return vector4(0.0, 0.0, 0.0, 0.0)

public def vector4_one() -> Vector4:
    return vector4(1.0, 1.0, 1.0, 1.0)

public def vector4_xyz(x double, y double, z double) -> Vector4:
    return vector4(x, y, z, 1.0)

# Addition
public def vector4_add(a Vector4, b Vector4) -> Vector4:
    return vector4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)

# Subtraction
public def vector4_sub(a Vector4, b Vector4) -> Vector4:
    return vector4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)

# Scalar multiplication
public def vector4_mul_scalar(v Vector4, s double) -> Vector4:
    return vector4(v.x * s, v.y * s, v.z * s, v.w * s)

# Scalar division
public def vector4_div_scalar(v Vector4, s double) -> Vector4:
    assert s != 0.0, "Division by zero"
    return vector4(v.x / s, v.y / s, v.z / s, v.w / s)

# Negation
public def vector4_neg(v Vector4) -> Vector4:
    return vector4(-v.x, -v.y, -v.z, -v.w)

# Dot product
public def vector4_dot(a Vector4, b Vector4) -> double:
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

# Magnitude (length)
public def vector4_magnitude(v Vector4) -> double:
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w)

# Squared magnitude (faster, avoids sqrt)
public def vector4_magnitude_squared(v Vector4) -> double:
    return v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w

# Normalization (returns unit vector). The homogeneous w is preserved unchanged.
public def vector4_normalize(v Vector4) -> Vector4:
    double mag = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    assert mag != 0.0, "Cannot normalize zero vector"
    return vector4(v.x / mag, v.y / mag, v.z / mag, v.w)

# Distance between two vectors
public def vector4_distance(a Vector4, b Vector4) -> double:
    return vector4_magnitude(vector4_sub(b, a))

# Squared distance (faster, avoids sqrt)
public def vector4_distance_squared(a Vector4, b Vector4) -> double:
    return vector4_magnitude_squared(vector4_sub(b, a))

# Angle between vectors (in radians)
public def vector4_angle(a Vector4, b Vector4) -> double:
    double mag_a = vector4_magnitude(a)
    double mag_b = vector4_magnitude(b)
    assert mag_a != 0.0 and mag_b != 0.0, "Cannot compute angle with zero vector"
    double dot_prod = vector4_dot(a, b)
    double cos_theta = dot_prod / (mag_a * mag_b)
    if cos_theta > 1.0:
        cos_theta = 1.0
    if cos_theta < -1.0:
        cos_theta = -1.0
    return acos(cos_theta)

# Linear interpolation
public def vector4_lerp(a Vector4, b Vector4, t double) -> Vector4:
    return vector4_add(a, vector4_mul_scalar(vector4_sub(b, a), t))

# Reflect vector around normal
public def vector4_reflect(v Vector4, normal Vector4) -> Vector4:
    Vector4 n = vector4_normalize(normal)
    double dot_prod = vector4_dot(v, n)
    return vector4_sub(v, vector4_mul_scalar(n, 2.0 * dot_prod))

# Project vector onto another
public def vector4_project(v Vector4, onto Vector4) -> Vector4:
    double mag_onto_squared = vector4_magnitude_squared(onto)
    assert mag_onto_squared != 0.0, "Cannot project onto zero vector"
    double dot_prod = vector4_dot(v, onto)
    return vector4_mul_scalar(onto, dot_prod / mag_onto_squared)

# Check if vectors are approximately equal
public def vector4_approx_equal(a Vector4, b Vector4, epsilon double) -> bool:
    return abs(a.x - b.x) < epsilon and abs(a.y - b.y) < epsilon and abs(a.z - b.z) < epsilon and abs(a.w - b.w) < epsilon

# Convert homogeneous vector to a normalized-xyz Vector4 (divide xyz by w).
# Cross-type conversion to Vector3 lives in the aggregator module.
public def vector4_homogeneous_divide(v Vector4) -> Vector4:
    assert v.w != 0.0, "Cannot divide by zero w component"
    double inv_w = 1.0 / v.w
    return vector4(v.x * inv_w, v.y * inv_w, v.z * inv_w, 1.0)

# Homogeneous to Cartesian weights: returns a Vector4 whose (x,y,z) are the
# perspective-corrected values. Keep as convenience returning a Vector4.
public def vector4_xyz_of(v Vector4) -> Vector4:
    return vector4(v.x, v.y, v.z, 1.0)
