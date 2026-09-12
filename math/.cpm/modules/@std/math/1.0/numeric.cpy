import stdlib

public def numeric_abs_int(value int) -> int:
    if value < 0:
        return -value
    return value

public def numeric_min_int(a int, b int) -> int:
    if a < b:
        return a
    return b

public def numeric_max_int(a int, b int) -> int:
    if a > b:
        return a
    return b

public def numeric_clamp_int(value int, lo int, hi int) -> int:
    if value < lo:
        return lo
    if value > hi:
        return hi
    return value

public def numeric_gcd(a int, b int) -> int:
    if a < 0:
        a = -a
    if b < 0:
        b = -b
    while b != 0:
        int remainder = a % b
        a = b
        b = remainder
    return a

public def numeric_lcm(a int, b int) -> int:
    if a == 0 or b == 0:
        return 0
    int g = numeric_gcd(a, b)
    int result = (a / g) * b
    if result < 0:
        return -result
    return result

public def numeric_popcount(value uint64) -> int:
    int count = 0
    while value != 0:
        value = value & (value - 1)
        count = count + 1
    return count

public def numeric_parity(value uint64) -> int:
    return numeric_popcount(value) & 1

public def numeric_is_power_of_two(value uint64) -> int:
    if value == 0:
        return 0
    if (value & (value - 1)) == 0:
        return 1
    return 0

public def numeric_next_power_of_two(value uint64) -> uint64:
    if value <= 1:
        return 1
    uint64 result = 1
    while result < value:
        result = result << 1
    return result

public def numeric_reverse_bits(value uint64) -> uint64:
    uint64 result = 0
    int i = 0
    while i < 64:
        result = (result << 1) | (value & 1)
        value = value >> 1
        i = i + 1
    return result

public def numeric_is_even(value int) -> int:
    if (value % 2) == 0:
        return 1
    return 0

public def numeric_is_odd(value int) -> int:
    if (value % 2) != 0:
        return 1
    return 0
