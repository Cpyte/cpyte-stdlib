import "scalar.cpy"

public def euc_gcd(a uint64, b uint64) -> uint64:
    while b != 0:
        c = a
        a = b
        b = c % b
    return a

public def bin_gcd(a uint64, b uint64) -> uint64:
    if a == 0:
        return b
    elif b == 0:
        return a

    k = ctz(a | b)

    a = a >> ctz(a)

    while b != 0:
        b = b >> ctz(b)

        if a > b:
            uint64 temp = a
            a = b
            b = temp

        b = b - a

    return a << k

public def lcm(a uint64, b uint64) -> uint64:
    if a == 0 or b == 0:
        return 0

    uint64 g = bin_gcd(a, b)
    return (a / g) * b

struct ExtendedGCDResult:
    int gcd
    int x
    int y


public def extended_gcd(a int, b int) -> ExtendedGCDResult:
    int old_r = a
    int r = b

    int old_x = 1
    int x = 0

    int old_y = 0
    int y = 1

    while r != 0:
        int q = old_r / r

        int temp = r
        r = old_r - q * r
        old_r = temp

        temp = x
        x = old_x - q * x
        old_x = temp

        temp = y
        y = old_y - q * y
        old_y = temp

    if old_r < 0:
        old_r = -old_r
        old_x = -old_x
        old_y = -old_y

    ExtendedGCDResult result
    result.gcd = old_r
    result.x = old_x
    result.y = old_y

    return result

public def mod_pow(a int, b int, mod int) -> int:
    assert mod > 0, "Value Error: Modulus must be positive"
    assert b >= 0, "Value Error: Exponent must be non-negative"

    int result = 1 % mod
    int base = a % mod

    while b > 0:
        if b % 2 != 0:
            result = (result * base) % mod

        base = (base * base) % mod
        b = b / 2

    return result

public def inverse_mod(a int, mod int) -> int:
    assert mod > 0, "Value Error: Modulus must be positive"
    int old_r = a
    int r = mod
    int old_x = 1
    int x = 0

    while r != 0:
        int q = old_r / r
        int temp = r
        r = old_r - q * r
        old_r = temp
        temp = x
        x = old_x - q * x
        old_x = temp

    if old_r != 1 and old_r != -1:
        return 0
    int result = old_x % mod
    if result < 0:
        result = result + mod
    return result

struct decomposed:
    int s
    int d

private def _decompose(n int) -> decomposed:
    int nm1 = n - 1
    int s = ctz(nm1)
    int d = nm1 >> s
    decomposed result
    result.s = s
    result.d = d
    return result

public def miller_rabin_pass(n int, a int, d int, s int) -> int:
    int x = mod_pow(a, d, n)
    if x == 1 or x == n - 1:
        return 1

    int r = 1
    while r < s:
        x = (x * x) % n
        if x == n - 1:
            return 1
        if x == 1:
            return 0
        r = r + 1

    return 0

public def is_prime(n int) -> int:
    if n < 2:
        return 0
    if n == 2 or n == 3 or n == 5 or n == 7 or n == 11 or n == 13 or n == 17:
        return 1
    if n % 2 == 0 or n % 3 == 0 or n % 5 == 0 or n % 7 == 0 or n % 11 == 0 or n % 13 == 0 or n % 17 == 0:
        return 0

    int s = ctz(n - 1)
    int d = (n - 1) >> s

    if n < 341550071728321:
        if not miller_rabin_pass(n, 2, d, s):
            return 0
        if not miller_rabin_pass(n, 3, d, s):
            return 0
        if not miller_rabin_pass(n, 5, d, s):
            return 0
        if not miller_rabin_pass(n, 7, d, s):
            return 0
        if not miller_rabin_pass(n, 11, d, s):
            return 0
        return miller_rabin_pass(n, 13, d, s)

    if not miller_rabin_pass(n, 2, d, s):
        return 0
    if not miller_rabin_pass(n, 3, d, s):
        return 0
    if not miller_rabin_pass(n, 5, d, s):
        return 0
    if not miller_rabin_pass(n, 7, d, s):
        return 0
    if not miller_rabin_pass(n, 11, d, s):
        return 0
    if not miller_rabin_pass(n, 13, d, s):
        return 0
    if not miller_rabin_pass(n, 17, d, s):
        return 0
    if not miller_rabin_pass(n, 19, d, s):
        return 0
    if not miller_rabin_pass(n, 23, d, s):
        return false
    if not miller_rabin_pass(n, 29, d, s):
        return false
    if not miller_rabin_pass(n, 31, d, s):
        return false
    return miller_rabin_pass(n, 37, d, s)

public def prime_sieve(n int) -> int[]:
    if n <= 1:
        return new int[0]
    if n == 2:
        int[] small_out_2 = new int[1]
        small_out_2[0] = 2
        return small_out_2
    if n == 3:
        int[] small_out_3 = new int[2]
        small_out_3[0] = 2
        small_out_3[1] = 3
        return small_out_3

    int[] sieve = new int[n + 1]
    int i = 0
    while i <= n:
        sieve[i] = 1
        i = i + 1

    if n >= 0:
        sieve[0] = 0
    if n >= 1:
        sieve[1] = 0

    int p = 2
    while p * p <= n:
        if sieve[p] != 0:
            int m = p * p
            while m <= n:
                sieve[m] = 0
                m = m + p
        p = p + 1

    int count = 0
    i = 2
    while i <= n:
        if sieve[i] != 0:
            count = count + 1
        i = i + 1

    int[] primes = new int[count]
    int idx = 0
    i = 2
    while i <= n:
        if sieve[i] != 0:
            primes[idx] = i
            idx = idx + 1
        i = i + 1

    return primes

public def factorial(n int) -> big:
    assert n >= 0, "Value Error: Factorial is undefined for negative values"
    big result = 1
    int i = 2
    while i <= n:
        result = result * i
        i = i + 1
    return result
