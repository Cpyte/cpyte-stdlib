import stdlib
import math

# N-dimensional Vector struct for mathematical operations
struct VectorN:
    double* data
    size_t size

public def vectorn(size size_t) -> VectorN:
    assert size >= (size_t)2, "VectorN must have at least 2 components"
    VectorN v
    v.size = size
    v.data = malloc(size * (size_t)sizeof(double))
    # Initialize to zero
    for i in range((int)size):
        v.data[i] = 0.0
    return v

public def vectorn_from_array(arr double*, size size_t) -> VectorN:
    assert size >= (size_t)2, "VectorN must have at least 2 components"
    VectorN v
    v.size = size
    v.data = malloc(size * (size_t)sizeof(double))
    for i in range((int)size):
        v.data[i] = arr[i]
    return v

public def vectorn_copy(v VectorN) -> VectorN:
    VectorN out
    out.size = v.size
    out.data = malloc(v.size * (size_t)sizeof(double))
    for i in range((int)v.size):
        out.data[i] = v.data[i]
    return out

public def vectorn_zero(size size_t) -> VectorN:
    return vectorn(size)

public def vectorn_one(size size_t) -> VectorN:
    VectorN v = vectorn(size)
    for i in range((int)size):
        v.data[i] = 1.0
    return v

# Get component at index
public def vectorn_get(v VectorN, i size_t) -> double:
    assert i < v.size, "Index out of bounds"
    return v.data[i]

# Set component at index
public def vectorn_set(v VectorN, i size_t, value double) -> VectorN:
    assert i < v.size, "Index out of bounds"
    v.data[i] = value
    return v

# Addition
public def vectorn_add(a VectorN, b VectorN) -> VectorN:
    assert a.size == b.size, "Vector dimensions must match for addition"
    VectorN out = vectorn(a.size)
    for i in range((int)a.size):
        out.data[i] = a.data[i] + b.data[i]
    return out

# Subtraction
public def vectorn_sub(a VectorN, b VectorN) -> VectorN:
    assert a.size == b.size, "Vector dimensions must match for subtraction"
    VectorN out = vectorn(a.size)
    for i in range((int)a.size):
        out.data[i] = a.data[i] - b.data[i]
    return out

# Scalar multiplication
public def vectorn_mul_scalar(v VectorN, s double) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = v.data[i] * s
    return out

# Element-wise multiplication
public def vectorn_mul(a VectorN, b VectorN) -> VectorN:
    assert a.size == b.size, "Vector dimensions must match for element-wise multiplication"
    VectorN out = vectorn(a.size)
    for i in range((int)a.size):
        out.data[i] = a.data[i] * b.data[i]
    return out

# Scalar division
public def vectorn_div_scalar(v VectorN, s double) -> VectorN:
    assert s != 0.0, "Division by zero"
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = v.data[i] / s
    return out

# Element-wise division
public def vectorn_div(a VectorN, b VectorN) -> VectorN:
    assert a.size == b.size, "Vector dimensions must match for element-wise division"
    VectorN out = vectorn(a.size)
    for i in range((int)a.size):
        assert b.data[i] != 0.0, "Division by zero in element-wise division"
        out.data[i] = a.data[i] / b.data[i]
    return out

# Negation
public def vectorn_neg(v VectorN) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = -v.data[i]
    return out

# Dot product
public def vectorn_dot(a VectorN, b VectorN) -> double:
    assert a.size == b.size, "Vector dimensions must match for dot product"
    double accum = 0.0
    for i in range((int)a.size):
        accum += a.data[i] * b.data[i]
    return accum

# Magnitude (length)
public def vectorn_magnitude(v VectorN) -> double:
    return sqrt(vectorn_dot(v, v))

# Squared magnitude (faster, avoids sqrt)
public def vectorn_magnitude_squared(v VectorN) -> double:
    return vectorn_dot(v, v)

# Normalization (returns unit vector)
public def vectorn_normalize(v VectorN) -> VectorN:
    double mag = vectorn_magnitude(v)
    assert mag != 0.0, "Cannot normalize zero vector"
    return vectorn_div_scalar(v, mag)

# Distance between two vectors
public def vectorn_distance(a VectorN, b VectorN) -> double:
    return vectorn_magnitude(vectorn_sub(b, a))

# Squared distance (faster, avoids sqrt)
public def vectorn_distance_squared(a VectorN, b VectorN) -> double:
    return vectorn_magnitude_squared(vectorn_sub(b, a))

# Angle between vectors (in radians)
public def vectorn_angle(a VectorN, b VectorN) -> double:
    double mag_a = vectorn_magnitude(a)
    double mag_b = vectorn_magnitude(b)
    assert mag_a != 0.0 and mag_b != 0.0, "Cannot compute angle with zero vector"
    double dot_prod = vectorn_dot(a, b)
    double cos_theta = dot_prod / (mag_a * mag_b)
    # Clamp to [-1, 1] to handle floating point errors
    if cos_theta > 1.0:
        cos_theta = 1.0
    if cos_theta < -1.0:
        cos_theta = -1.0
    return acos(cos_theta)

# Linear interpolation
public def vectorn_lerp(a VectorN, b VectorN, t double) -> VectorN:
    assert a.size == b.size, "Vector dimensions must match for interpolation"
    return vectorn_add(a, vectorn_mul_scalar(vectorn_sub(b, a), t))

# Reflect vector around normal
public def vectorn_reflect(v VectorN, normal VectorN) -> VectorN:
    assert v.size == normal.size, "Vector dimensions must match for reflection"
    VectorN n = vectorn_normalize(normal)
    double dot_prod = vectorn_dot(v, n)
    return vectorn_sub(v, vectorn_mul_scalar(n, 2.0 * dot_prod))

# Project vector onto another
public def vectorn_project(v VectorN, onto VectorN) -> VectorN:
    assert v.size == onto.size, "Vector dimensions must match for projection"
    double mag_onto_squared = vectorn_magnitude_squared(onto)
    assert mag_onto_squared != 0.0, "Cannot project onto zero vector"
    double dot_prod = vectorn_dot(v, onto)
    return vectorn_mul_scalar(onto, dot_prod / mag_onto_squared)

# Check if vectors are approximately equal
public def vectorn_approx_equal(a VectorN, b VectorN, epsilon double) -> bool:
    assert a.size == b.size, "Vector dimensions must match for comparison"
    int ok = 1
    for i in range((int)a.size):
        if fabs(a.data[i] - b.data[i]) >= epsilon:
            ok = 0
    return ok == 1

# Maximum component
public def vectorn_max_component(v VectorN) -> double:
    double max_val = v.data[0]
    for i in range(1, (int)v.size):
        if v.data[i] > max_val:
            max_val = v.data[i]
    return max_val

# Minimum component
public def vectorn_min_component(v VectorN) -> double:
    double min_val = v.data[0]
    for i in range(1, (int)v.size):
        if v.data[i] < min_val:
            min_val = v.data[i]
    return min_val

# Sum of all components
public def vectorn_sum(v VectorN) -> double:
    double accum = 0.0
    for i in range((int)v.size):
        accum += v.data[i]
    return accum

# Product of all components
public def vectorn_product(v VectorN) -> double:
    double product = 1.0
    for i in range((int)v.size):
        product *= v.data[i]
    return product

# Mean of components
public def vectorn_mean(v VectorN) -> double:
    return vectorn_sum(v) / (double)v.size

# Absolute value of each component
public def vectorn_abs(v VectorN) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = fabs(v.data[i])
    return out

# Floor each component
public def vectorn_floor(v VectorN) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = floor(v.data[i])
    return out

# Ceil each component
public def vectorn_ceil(v VectorN) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        out.data[i] = ceil(v.data[i])
    return out

# Round each component
public def vectorn_round(v VectorN) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        if v.data[i] >= 0.0:
            out.data[i] = floor(v.data[i] + 0.5)
        else:
            out.data[i] = -floor(-v.data[i] + 0.5)
    return out

# Clamp each component between min and max
public def vectorn_clamp(v VectorN, min_val double, max_val double) -> VectorN:
    VectorN out = vectorn(v.size)
    for i in range((int)v.size):
        double clamped = v.data[i]
        if clamped < min_val:
            clamped = min_val
        if clamped > max_val:
            clamped = max_val
        out.data[i] = clamped
    return out

# Scale vector to have given length
public def vectorn_scale_to_length(v VectorN, new_length double) -> VectorN:
    double mag = vectorn_magnitude(v)
    assert mag != 0.0, "Cannot scale zero vector"
    return vectorn_mul_scalar(v, new_length / mag)

# Get direction from a to b
public def vectorn_direction(from VectorN, to VectorN) -> VectorN:
    assert from.size == to.size, "Vector dimensions must match for direction"
    return vectorn_normalize(vectorn_sub(to, from))

# Euclidean norm (same as magnitude)
public def vectorn_norm(v VectorN) -> double:
    return vectorn_magnitude(v)

# Manhattan norm (L1 norm)
public def vectorn_norm_manhattan(v VectorN) -> double:
    double accum = 0.0
    for i in range((int)v.size):
        accum += fabs(v.data[i])
    return accum

# Maximum norm (infinity norm)
public def vectorn_norm_max(v VectorN) -> double:
    return vectorn_max_component(vectorn_abs(v))

# Resize vector (truncates or pads with zeros)
public def vectorn_resize(v VectorN, new_size size_t) -> VectorN:
    assert new_size >= (size_t)2, "VectorN must have at least 2 components"
    VectorN out = vectorn(new_size)
    size_t copy_size = v.size
    if new_size < copy_size:
        copy_size = new_size
    for i in range((int)copy_size):
        out.data[i] = v.data[i]
    return out

# Concatenate two vectors
public def vectorn_concat(a VectorN, b VectorN) -> VectorN:
    VectorN out = vectorn(a.size + b.size)
    for i in range((int)a.size):
        out.data[i] = a.data[i]
    for i in range((int)b.size):
        out.data[a.size + i] = b.data[i]
    return out

# Get subvector
public def vectorn_subvector(v VectorN, start size_t, length size_t) -> VectorN:
    assert start + length <= v.size, "Subvector range out of bounds"
    assert length >= (size_t)2, "Subvector must have at least 2 components"
    VectorN out = vectorn(length)
    for i in range((int)length):
        out.data[i] = v.data[start + i]
    return out
