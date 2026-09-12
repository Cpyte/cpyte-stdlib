import stdlib
import math

# 2D Vector struct for mathematical operations
struct Vector2:
    double x
    double y

public def vector2(x double, y double) -> Vector2:
    Vector2 v
    v.x = x
    v.y = y
    return v

public def vector2_zero() -> Vector2:
    return vector2(0.0, 0.0)

public def vector2_one() -> Vector2:
    return vector2(1.0, 1.0)

public def vector2_up() -> Vector2:
    return vector2(0.0, 1.0)

public def vector2_down() -> Vector2:
    return vector2(0.0, -1.0)

public def vector2_left() -> Vector2:
    return vector2(-1.0, 0.0)

public def vector2_right() -> Vector2:
    return vector2(1.0, 0.0)

# Addition
public def vector2_add(a Vector2, b Vector2) -> Vector2:
    return vector2(a.x + b.x, a.y + b.y)

# Subtraction
public def vector2_sub(a Vector2, b Vector2) -> Vector2:
    return vector2(a.x - b.x, a.y - b.y)

# Scalar multiplication
public def vector2_mul_scalar(v Vector2, s double) -> Vector2:
    return vector2(v.x * s, v.y * s)

# Element-wise multiplication
public def vector2_mul(a Vector2, b Vector2) -> Vector2:
    return vector2(a.x * b.x, a.y * b.y)

# Scalar division
public def vector2_div_scalar(v Vector2, s double) -> Vector2:
    assert s != 0.0, "Division by zero"
    return vector2(v.x / s, v.y / s)

# Element-wise division
public def vector2_div(a Vector2, b Vector2) -> Vector2:
    assert b.x != 0.0 and b.y != 0.0, "Division by zero"
    return vector2(a.x / b.x, a.y / b.y)

# Negation
public def vector2_neg(v Vector2) -> Vector2:
    return vector2(-v.x, -v.y)

# Dot product
public def vector2_dot(a Vector2, b Vector2) -> double:
    return a.x * b.x + a.y * b.y

# 2D cross product (returns scalar z-component)
public def vector2_cross(a Vector2, b Vector2) -> double:
    return a.x * b.y - a.y * b.x

# Magnitude (length)
public def vector2_magnitude(v Vector2) -> double:
    return sqrt(v.x * v.x + v.y * v.y)

# Squared magnitude (faster, avoids sqrt)
public def vector2_magnitude_squared(v Vector2) -> double:
    return v.x * v.x + v.y * v.y

# Normalization (returns unit vector)
public def vector2_normalize(v Vector2) -> Vector2:
    double mag = vector2_magnitude(v)
    assert mag != 0.0, "Cannot normalize zero vector"
    return vector2_div_scalar(v, mag)

# Distance between two vectors
public def vector2_distance(a Vector2, b Vector2) -> double:
    return vector2_magnitude(vector2_sub(b, a))

# Squared distance (faster, avoids sqrt)
public def vector2_distance_squared(a Vector2, b Vector2) -> double:
    return vector2_magnitude_squared(vector2_sub(b, a))

# Angle between vectors (in radians)
public def vector2_angle(a Vector2, b Vector2) -> double:
    double mag_a = vector2_magnitude(a)
    double mag_b = vector2_magnitude(b)
    assert mag_a != 0.0 and mag_b != 0.0, "Cannot compute angle with zero vector"
    double dot = vector2_dot(a, b)
    double cos_theta = dot / (mag_a * mag_b)
    # Clamp to [-1, 1] to handle floating point errors
    if cos_theta > 1.0:
        cos_theta = 1.0
    if cos_theta < -1.0:
        cos_theta = -1.0
    return acos(cos_theta)

# Angle of vector from x-axis (in radians)
public def vector2_heading(v Vector2) -> double:
    return atan2(v.y, v.x)

# Rotate vector by angle (in radians)
public def vector2_rotate(v Vector2, angle double) -> Vector2:
    double cos_a = cos(angle)
    double sin_a = sin(angle)
    return vector2(
        v.x * cos_a - v.y * sin_a,
        v.x * sin_a + v.y * cos_a
    )

# Linear interpolation
public def vector2_lerp(a Vector2, b Vector2, t double) -> Vector2:
    return vector2_add(a, vector2_mul_scalar(vector2_sub(b, a), t))

# Reflect vector around normal
public def vector2_reflect(v Vector2, normal Vector2) -> Vector2:
    Vector2 n = vector2_normalize(normal)
    double dot = vector2_dot(v, n)
    return vector2_sub(v, vector2_mul_scalar(n, 2.0 * dot))

# Project vector onto another
public def vector2_project(v Vector2, onto Vector2) -> Vector2:
    double mag_onto_squared = vector2_magnitude_squared(onto)
    assert mag_onto_squared != 0.0, "Cannot project onto zero vector"
    double dot = vector2_dot(v, onto)
    return vector2_mul_scalar(onto, dot / mag_onto_squared)

# Perpendicular vector (rotated 90 degrees counter-clockwise)
public def vector2_perpendicular(v Vector2) -> Vector2:
    return vector2(-v.y, v.x)

# Check if vectors are approximately equal
public def vector2_approx_equal(a Vector2, b Vector2, epsilon double) -> bool:
    return abs(a.x - b.x) < epsilon and abs(a.y - b.y) < epsilon

# Maximum component
public def vector2_max_component(v Vector2) -> double:
    if v.x >= v.y:
        return v.x
    return v.y

# Minimum component
public def vector2_min_component(v Vector2) -> double:
    if v.x <= v.y:
        return v.x
    return v.y

# Absolute value of each component
public def vector2_abs(v Vector2) -> Vector2:
    return vector2(abs(v.x), abs(v.y))

# Floor each component
public def vector2_floor(v Vector2) -> Vector2:
    return vector2(floor(v.x), floor(v.y))

# Ceil each component
public def vector2_ceil(v Vector2) -> Vector2:
    return vector2(ceil(v.x), ceil(v.y))

# Round each component
public def vector2_round(v Vector2) -> Vector2:
    double rx = floor(v.x + 0.5)
    double ry = floor(v.y + 0.5)
    if v.x < 0.0:
        rx = -floor(-v.x + 0.5)
    if v.y < 0.0:
        ry = -floor(-v.y + 0.5)
    return vector2(rx, ry)

# Clamp each component between min and max
public def vector2_clamp(v Vector2, min_val double, max_val double) -> Vector2:
    double clamped_x = v.x
    double clamped_y = v.y
    if clamped_x < min_val:
        clamped_x = min_val
    if clamped_x > max_val:
        clamped_x = max_val
    if clamped_y < min_val:
        clamped_y = min_val
    if clamped_y > max_val:
        clamped_y = max_val
    return vector2(clamped_x, clamped_y)

# Scale vector to have given length
public def vector2_scale_to_length(v Vector2, new_length double) -> Vector2:
    double mag = vector2_magnitude(v)
    assert mag != 0.0, "Cannot scale zero vector"
    return vector2_mul_scalar(v, new_length / mag)

# Get direction from a to b
public def vector2_direction(from Vector2, to Vector2) -> Vector2:
    return vector2_normalize(vector2_sub(to, from))