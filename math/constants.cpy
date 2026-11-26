# Arbitrary-precision mathematical constants for @std/math.
#
# `precision` is the number of digits requested after the decimal point.
# Results are returned as decimal strings because cpyte's `double` is an
# IEEE-754 binary64 value and cannot represent more than ~15 significant
# decimal digits.
#
# Public functions:
#   pi, e, tau, phi, sqrt2, sqrt3, ln2, ln10, euler_gamma, catalan
#   math_constant(name, precision) -- generic form, e.g. "pi", "sqrt2"

ccode:
    #include <mpfr.h>
    #include <stdlib.h>

    static char* cpy_math_empty_string(void) {
        char* s = (char*)malloc(1);
        if (s != NULL) s[0] = '\0';
        return s;
    }

    char* cpy_math_const_str(int which, int digits) {
        if (digits < 1) digits = 1;
        if (digits > 10000) digits = 10000;

        mpfr_prec_t bits = (mpfr_prec_t)((double)digits * 3.321928094887362 + 64.0);
        mpfr_t x;
        mpfr_init2(x, bits);

        switch (which) {
            case 0:  /* pi */
                mpfr_const_pi(x, MPFR_RNDN);
                break;
            case 1:  /* e */
                mpfr_set_ui(x, 1UL, MPFR_RNDN);
                mpfr_exp(x, x, MPFR_RNDN);
                break;
            case 2:  /* tau = 2*pi */
                mpfr_const_pi(x, MPFR_RNDN);
                mpfr_mul_ui(x, x, 2UL, MPFR_RNDN);
                break;
            case 3:  /* golden ratio = (1 + sqrt(5)) / 2 */
                mpfr_sqrt_ui(x, 5UL, MPFR_RNDN);
                mpfr_add_ui(x, x, 1UL, MPFR_RNDN);
                mpfr_div_ui(x, x, 2UL, MPFR_RNDN);
                break;
            case 4:  /* sqrt(2) */
                mpfr_sqrt_ui(x, 2UL, MPFR_RNDN);
                break;
            case 5:  /* sqrt(3) */
                mpfr_sqrt_ui(x, 3UL, MPFR_RNDN);
                break;
            case 6:  /* ln(2) */
                mpfr_const_log2(x, MPFR_RNDN);
                break;
            case 7:  /* ln(10) */
                mpfr_log_ui(x, 10UL, MPFR_RNDN);
                break;
            case 8:  /* Euler-Mascheroni constant */
                mpfr_const_euler(x, MPFR_RNDN);
                break;
            case 9:  /* Catalan's constant */
                mpfr_const_catalan(x, MPFR_RNDN);
                break;
            default:
                mpfr_set_zero(x, 0);
                break;
        }

        char* out = NULL;
        int n = mpfr_asprintf(&out, "%.*Rf", digits, x);
        mpfr_clear(x);
        if (n < 0 || out == NULL) return cpy_math_empty_string();
        return out;
    }

public def math_constant(name str, precision int) -> str:
    assert precision >= 1 and precision <= 10000, "precision must be 1..10000"

    if name == "pi":
        return cpy_math_const_str(0, precision)
    if name == "e":
        return cpy_math_const_str(1, precision)
    if name == "tau":
        return cpy_math_const_str(2, precision)
    if name == "phi":
        return cpy_math_const_str(3, precision)
    if name == "sqrt2":
        return cpy_math_const_str(4, precision)
    if name == "sqrt3":
        return cpy_math_const_str(5, precision)
    if name == "ln2":
        return cpy_math_const_str(6, precision)
    if name == "ln10":
        return cpy_math_const_str(7, precision)
    if name == "euler_gamma":
        return cpy_math_const_str(8, precision)
    if name == "catalan":
        return cpy_math_const_str(9, precision)
    return ""

public def pi(precision int) -> str:
    return math_constant("pi", precision)

public def e(precision int) -> str:
    return math_constant("e", precision)

public def tau(precision int) -> str:
    return math_constant("tau", precision)

public def phi(precision int) -> str:
    return math_constant("phi", precision)

public def sqrt2(precision int) -> str:
    return math_constant("sqrt2", precision)

public def sqrt3(precision int) -> str:
    return math_constant("sqrt3", precision)

public def ln2(precision int) -> str:
    return math_constant("ln2", precision)

public def ln10(precision int) -> str:
    return math_constant("ln10", precision)

public def euler_gamma(precision int) -> str:
    return math_constant("euler_gamma", precision)

public def catalan(precision int) -> str:
    return math_constant("catalan", precision)
