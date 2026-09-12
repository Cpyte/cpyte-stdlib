import stdlib
import math
import "scalar.cpy"

struct Complex:
    double real
    double imag

public def complex_make(real double, imag double) -> Complex:
    Complex result
    result.real = real
    result.imag = imag
    return result

public def complex_zero() -> Complex:
    return complex_make(0.0, 0.0)

public def complex_one() -> Complex:
    return complex_make(1.0, 0.0)

public def complex_add(a Complex, b Complex) -> Complex:
    return complex_make(a.real + b.real, a.imag + b.imag)

public def complex_sub(a Complex, b Complex) -> Complex:
    return complex_make(a.real - b.real, a.imag - b.imag)

public def complex_neg(a Complex) -> Complex:
    return complex_make(-a.real, -a.imag)

public def complex_mul(a Complex, b Complex) -> Complex:
    return complex_make(
        a.real * b.real - a.imag * b.imag,
        a.real * b.imag + a.imag * b.real
    )

public def complex_div(a Complex, b Complex) -> Complex:
    double scale = fabs(b.real)
    if fabs(b.imag) > scale:
        scale = fabs(b.imag)
    assert scale != 0.0, "Complex division by zero"
    double br = b.real / scale
    double bi = b.imag / scale
    double denominator = br * br + bi * bi
    double ar = a.real / scale
    double ai = a.imag / scale
    return complex_make(
        (ar * br + ai * bi) / denominator,
        (ai * br - ar * bi) / denominator
    )

public def complex_conjugate(a Complex) -> Complex:
    return complex_make(a.real, -a.imag)

public def complex_abs(a Complex) -> double:
    return scalar_hypot(a.real, a.imag)

public def complex_arg(a Complex) -> double:
    return atan2(a.imag, a.real)

public def complex_exp(a Complex) -> Complex:
    double scale = exp(a.real)
    return complex_make(scale * cos(a.imag), scale * sin(a.imag))

public def complex_log(a Complex) -> Complex:
    return complex_make(log(complex_abs(a)), complex_arg(a))

public def complex_pow_real(a Complex, exponent double) -> Complex:
    double magnitude = pow(complex_abs(a), exponent)
    double angle = complex_arg(a) * exponent
    return complex_make(magnitude * cos(angle), magnitude * sin(angle))

public def complex_sqrt(a Complex) -> Complex:
    double magnitude = complex_abs(a)
    double real_part = sqrt((magnitude + a.real) / 2.0)
    double imag_part = sqrt((magnitude - a.real) / 2.0)
    if a.imag < 0.0:
        imag_part = -imag_part
    return complex_make(real_part, imag_part)

public def complex_scale(a Complex, scale double) -> Complex:
    return complex_make(a.real * scale, a.imag * scale)

public def complex_approx_equal(a Complex, b Complex, epsilon double) -> bool:
    return scalar_approx_equal(a.real, b.real, epsilon) and scalar_approx_equal(a.imag, b.imag, epsilon)
