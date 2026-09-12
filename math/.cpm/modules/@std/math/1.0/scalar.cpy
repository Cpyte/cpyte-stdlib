import stdlib
import math

# Clamp value between min and max
public def scalar_clamp(value double, min_val double, max_val double) -> double:
    if value < min_val:
        return min_val
    if value > max_val:
        return max_val
    return value

# Linear interpolation
public def scalar_lerp(a double, b double, t double) -> double:
    return a + (b - a) * t

# Degrees to radians
public def scalar_deg_to_rad(deg double) -> double:
    return deg * 3.141592653589793 / 180.0

# Radians to degrees
public def scalar_rad_to_deg(rad double) -> double:
    return rad * 180.0 / 3.141592653589793

# Check if value is approximately zero
public def scalar_approx_zero(value double, epsilon double) -> bool:
    return abs(value) < epsilon

# Check if two values are approximately equal
public def scalar_approx_equal(a double, b double, epsilon double) -> bool:
    return abs(a - b) < epsilon

# Sign function (-1, 0, or 1)
public def scalar_sign(value double) -> double:
    if value > 0.0:
        return 1.0
    if value < 0.0:
        return -1.0
    return 0.0

# Step function (0 if value < edge, 1 otherwise)
public def scalar_step(edge double, value double) -> double:
    if value < edge:
        return 0.0
    return 1.0

# Smooth step function
public def scalar_smooth_step(edge0 double, edge1 double, value double) -> double:
    double t = scalar_clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

# Minimum of two values
public def scalar_min(a double, b double) -> double:
    if a < b:
        return a
    return b

# Maximum of two values
public def scalar_max(a double, b double) -> double:
    if a > b:
        return a
    return b

# Absolute value
public def scalar_abs(value double) -> double:
    return fabs(value)

# Square
public def scalar_square(value double) -> double:
    return value * value

# Cube
public def scalar_cube(value double) -> double:
    return value * value * value

# Reciprocal (1/x)
public def scalar_reciprocal(value double) -> double:
    assert value != 0.0, "Division by zero"
    return 1.0 / value

# Power
public def scalar_pow(base double, exponent double) -> double:
    return pow(base, exponent)

# Square root
public def scalar_sqrt(value double) -> double:
    assert value >= 0.0, "Square root of negative number"
    return sqrt(value)

# Exponential
public def scalar_exp(value double) -> double:
    return exp(value)

# Natural logarithm
public def scalar_log(value double) -> double:
    assert value > 0.0, "Logarithm of non-positive number"
    return log(value)

# Logarithm base 10
public def scalar_log10(value double) -> double:
    assert value > 0.0, "Logarithm of non-positive number"
    return log10(value)

public def scalar_sin(value double) -> double:
    return sin(value)

public def scalar_cos(value double) -> double:
    return cos(value)

public def scalar_tan(value double) -> double:
    return tan(value)

public def scalar_asin(value double) -> double:
    assert value >= -1.0 and value <= 1.0, "asin domain error"
    return asin(value)

public def scalar_acos(value double) -> double:
    assert value >= -1.0 and value <= 1.0, "acos domain error"
    return acos(value)

public def scalar_atan(value double) -> double:
    return atan(value)

public def scalar_atan2(y double, x double) -> double:
    return atan2(y, x)

public def scalar_sinh(value double) -> double:
    double positive = exp(value)
    double negative = exp(-value)
    return (positive - negative) / 2.0

public def scalar_cosh(value double) -> double:
    double positive = exp(value)
    double negative = exp(-value)
    return (positive + negative) / 2.0

public def scalar_tanh(value double) -> double:
    double positive = exp(value)
    double negative = exp(-value)
    return (positive - negative) / (positive + negative)

public def scalar_asinh(value double) -> double:
    return log(value + sqrt(value * value + 1.0))

public def scalar_acosh(value double) -> double:
    assert value >= 1.0, "acosh domain error"
    return log(value + sqrt(value * value - 1.0))

public def scalar_atanh(value double) -> double:
    assert value > -1.0 and value < 1.0, "atanh domain error"
    return 0.5 * log((1.0 + value) / (1.0 - value))

public def scalar_hypot(x double, y double) -> double:
    double ax = fabs(x)
    double ay = fabs(y)
    if ax < ay:
        double temp = ax
        ax = ay
        ay = temp
    if ax == 0.0:
        return 0.0
    double ratio = ay / ax
    return ax * sqrt(1.0 + ratio * ratio)

public def scalar_cbrt(value double) -> double:
    if value == 0.0:
        return 0.0
    double magnitude = exp(log(fabs(value)) / 3.0)
    if value < 0.0:
        return -magnitude
    return magnitude

public def scalar_log2(value double) -> double:
    assert value > 0.0, "Logarithm of non-positive number"
    return log(value) / log(2.0)

public def scalar_exp2(value double) -> double:
    return exp(value * log(2.0))

public def scalar_log1p(value double) -> double:
    assert value > -1.0, "log1p domain error"
    if fabs(value) < 0.00000001:
        return value - value * value / 2.0 + value * value * value / 3.0
    return log(1.0 + value)

public def scalar_expm1(value double) -> double:
    if fabs(value) < 0.00000001:
        return value + value * value / 2.0 + value * value * value / 6.0
    return exp(value) - 1.0

public def scalar_copysign(value double, sign double) -> double:
    double magnitude = fabs(value)
    if sign < 0.0:
        return -magnitude
    return magnitude

# Fractional part
public def scalar_frac(value double) -> double:
    return value - floor(value)

# Modulo (always positive)
public def scalar_mod(a double, b double) -> double:
    assert b != 0.0, "Modulo by zero"
    double remainder = a - b * floor(a / b)
    return remainder

# Wrap value in range [min, max)
public def scalar_wrap(value double, min_val double, max_val double) -> double:
    double range = max_val - min_val
    if range == 0.0:
        return min_val
    return min_val + scalar_mod(value - min_val, range)

# Snap value to nearest increment
public def scalar_snap(value double, increment double) -> double:
    assert increment != 0.0, "Snap increment cannot be zero"
    double scaled = value / increment
    double nearest = 0.0
    if scaled >= 0.0:
        nearest = floor(scaled + 0.5)
    else:
        nearest = -floor(-scaled + 0.5)
    return nearest * increment

# Dampen value towards target (for smoothing)
public def scalar_dampen(current double, target double, smoothing double) -> double:
    return current + (target - current) * smoothing

# Remap value from one range to another
public def scalar_remap(value double, in_min double, in_max double, out_min double, out_max double) -> double:
    return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)

public def ctz(value uint64) -> int:
    assert value != 0, "Value Error: You can't run ctz with 0"
    int count = 0
    while (value & 1) == 0:
        value = value >> 1
        count += 1
    return count
