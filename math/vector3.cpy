import stdlib
import math

# 3D Vector struct for mathematical operations
struct Vector3:
    double x
    double y
    double z

public def vector3(x double, y double, z double) -> Vector3:
    Vector3 v
    v.x = x
    v.y = y
    v.z = z
    return v

public def vector3_zero() -> Vector3:
    return vector3(0.0, 0.0, 0.0)

public def vector3_one() -> Vector3:
    return vector3(1.0, 1.0, 1.0)

public def vector3_up() -> Vector3:
    return vector3(0.0, 1.0, 0.0)

public def vector3_down() -> Vector3:
    return vector3(0.0, -1.0, 0.0)

public def vector3_left() -> Vector3:
    return vector3(-1.0, 0.0, 0.0)

public def vector3_right() -> Vector3:
    return vector3(1.0, 0.0, 0.0)

public def vector3_forward() -> Vector3:
    return vector3(0.0, 0.0, 1.0)

public def vector3_back() -> Vector3:
    return vector3(0.0, 0.0, -1.0)

# Addition
public def vector3_add(a Vector3, b Vector3) -> Vector3:
    return vector3(a.x + b.x, a.y + b.y, a.z + b.z)

# Subtraction
public def vector3_sub(a Vector3, b Vector3) -> Vector3:
    return vector3(a.x - b.x, a.y - b.y, a.z - b.z)

# Scalar multiplication
public def vector3_mul_scalar(v Vector3, s double) -> Vector3:
    return vector3(v.x * s, v.y * s, v.z * s)

# Element-wise multiplication
public def vector3_mul(a Vector3, b Vector3) -> Vector3:
    return vector3(a.x * b.x, a.y * b.y, a.z * b.z)

# Scalar division
public def vector3_div_scalar(v Vector3, s double) -> Vector3:
    assert s != 0.0, "Division by zero"
    return vector3(v.x / s, v.y / s, v.z / s)

# Element-wise division
public def vector3_div(a Vector3, b Vector3) -> Vector3:
    assert b.x != 0.0 and b.y != 0.0 and b.z != 0.0, "Division by zero"
    return vector3(a.x / b.x, a.y / b.y, a.z / b.z)

# Negation
public def vector3_neg(v Vector3) -> Vector3:
    return vector3(-v.x, -v.y, -v.z)

# Dot product
public def vector3_dot(a Vector3, b Vector3) -> double:
    return a.x * b.x + a.y * b.y + a.z * b.z

# Cross product
public def vector3_cross(a Vector3, b Vector3) -> Vector3:
    return vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )

# Triple scalar product (a · (b × c))
public def vector3_triple_scalar(a Vector3, b Vector3, c Vector3) -> double:
    return vector3_dot(a, vector3_cross(b, c))

# Triple vector product (a × (b × c))
public def vector3_triple_vector(a Vector3, b Vector3, c Vector3) -> Vector3:
    return vector3_cross(a, vector3_cross(b, c))

# Magnitude (length)
public def vector3_magnitude(v Vector3) -> double:
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

# Squared magnitude (faster, avoids sqrt)
public def vector3_magnitude_squared(v Vector3) -> double:
    return v.x * v.x + v.y * v.y + v.z * v.z

# Normalization (returns unit vector)
public def vector3_normalize(v Vector3) -> Vector3:
    double mag = vector3_magnitude(v)
    assert mag != 0.0, "Cannot normalize zero vector"
    return vector3_div_scalar(v, mag)

# Distance between two vectors
public def vector3_distance(a Vector3, b Vector3) -> double:
    return vector3_magnitude(vector3_sub(b, a))

# Squared distance (faster, avoids sqrt)
public def vector3_distance_squared(a Vector3, b Vector3) -> double:
    return vector3_magnitude_squared(vector3_sub(b, a))

# Angle between vectors (in radians)
public def vector3_angle(a Vector3, b Vector3) -> double:
    double mag_a = vector3_magnitude(a)
    double mag_b = vector3_magnitude(b)
    assert mag_a != 0.0 and mag_b != 0.0, "Cannot compute angle with zero vector"
    double dot = vector3_dot(a, b)
    double cos_theta = dot / (mag_a * mag_b)
    # Clamp to [-1, 1] to handle floating point errors
    if cos_theta > 1.0:
        cos_theta = 1.0
    if cos_theta < -1.0:
        cos_theta = -1.0
    return acos(cos_theta)

# Linear interpolation
public def vector3_lerp(a Vector3, b Vector3, t double) -> Vector3:
    return vector3_add(a, vector3_mul_scalar(vector3_sub(b, a), t))

# Spherical linear interpolation (SLERP)
public def vector3_slerp(a Vector3, b Vector3, t double) -> Vector3:
    double mag_a = vector3_magnitude(a)
    double mag_b = vector3_magnitude(b)
    assert mag_a > 0.0 and mag_b > 0.0, "Cannot SLERP with zero vector"
    
    Vector3 unit_a = vector3_div_scalar(a, mag_a)
    Vector3 unit_b = vector3_div_scalar(b, mag_b)
    
    double dot = vector3_dot(unit_a, unit_b)
    
    # Clamp dot to [-1, 1] to handle floating point errors
    if dot > 1.0:
        dot = 1.0
    if dot < -1.0:
        dot = -1.0
    
    double theta = acos(dot) * t
    
    Vector3 relative = vector3_sub(unit_b, vector3_mul_scalar(unit_a, dot))
    relative = vector3_normalize(relative)
    
    return vector3_add(
        vector3_mul_scalar(unit_a, cos(theta)),
        vector3_mul_scalar(relative, sin(theta))
    )

# Reflect vector around normal
public def vector3_reflect(v Vector3, normal Vector3) -> Vector3:
    Vector3 n = vector3_normalize(normal)
    double dot = vector3_dot(v, n)
    return vector3_sub(v, vector3_mul_scalar(n, 2.0 * dot))

# Project vector onto another
public def vector3_project(v Vector3, onto Vector3) -> Vector3:
    double mag_onto_squared = vector3_magnitude_squared(onto)
    assert mag_onto_squared != 0.0, "Cannot project onto zero vector"
    double dot = vector3_dot(v, onto)
    return vector3_mul_scalar(onto, dot / mag_onto_squared)

# Project vector onto plane defined by normal
public def vector3_project_plane(v Vector3, normal Vector3) -> Vector3:
    Vector3 n = vector3_normalize(normal)
    double dot = vector3_dot(v, n)
    return vector3_sub(v, vector3_mul_scalar(n, dot))

# Check if vectors are approximately equal
public def vector3_approx_equal(a Vector3, b Vector3, epsilon double) -> bool:
    return abs(a.x - b.x) < epsilon and abs(a.y - b.y) < epsilon and abs(a.z - b.z) < epsilon

# Maximum component
public def vector3_max_component(v Vector3) -> double:
    double max_val = v.x
    if v.y > max_val:
        max_val = v.y
    if v.z > max_val:
        max_val = v.z
    return max_val

# Minimum component
public def vector3_min_component(v Vector3) -> double:
    double min_val = v.x
    if v.y < min_val:
        min_val = v.y
    if v.z < min_val:
        min_val = v.z
    return min_val

# Absolute value of each component
public def vector3_abs(v Vector3) -> Vector3:
    return vector3(abs(v.x), abs(v.y), abs(v.z))

# Floor each component
public def vector3_floor(v Vector3) -> Vector3:
    return vector3(floor(v.x), floor(v.y), floor(v.z))

# Ceil each component
public def vector3_ceil(v Vector3) -> Vector3:
    return vector3(ceil(v.x), ceil(v.y), ceil(v.z))

# Round each component
public def vector3_round(v Vector3) -> Vector3:
    double rx = floor(v.x + 0.5)
    double ry = floor(v.y + 0.5)
    double rz = floor(v.z + 0.5)
    if v.x < 0.0:
        rx = -floor(-v.x + 0.5)
    if v.y < 0.0:
        ry = -floor(-v.y + 0.5)
    if v.z < 0.0:
        rz = -floor(-v.z + 0.5)
    return vector3(rx, ry, rz)

# Clamp each component between min and max
public def vector3_clamp(v Vector3, min_val double, max_val double) -> Vector3:
    double clamped_x = v.x
    double clamped_y = v.y
    double clamped_z = v.z
    if clamped_x < min_val:
        clamped_x = min_val
    if clamped_x > max_val:
        clamped_x = max_val
    if clamped_y < min_val:
        clamped_y = min_val
    if clamped_y > max_val:
        clamped_y = max_val
    if clamped_z < min_val:
        clamped_z = min_val
    if clamped_z > max_val:
        clamped_z = max_val
    return vector3(clamped_x, clamped_y, clamped_z)

# Scale vector to have given length
public def vector3_scale_to_length(v Vector3, new_length double) -> Vector3:
    double mag = vector3_magnitude(v)
    assert mag != 0.0, "Cannot scale zero vector"
    return vector3_mul_scalar(v, new_length / mag)

# Get direction from a to b
public def vector3_direction(from Vector3, to Vector3) -> Vector3:
    return vector3_normalize(vector3_sub(to, from))

# Rotate vector around axis by angle (in radians) using Rodrigues' rotation formula
public def vector3_rotate_around(v Vector3, axis Vector3, angle double) -> Vector3:
    Vector3 k = vector3_normalize(axis)
    double cos_theta = cos(angle)
    double sin_theta = sin(angle)
    
    return vector3_add(
        vector3_add(
            vector3_mul_scalar(v, cos_theta),
            vector3_mul_scalar(vector3_cross(k, v), sin_theta)
        ),
        vector3_mul_scalar(k, vector3_dot(k, v) * (1.0 - cos_theta))
    )