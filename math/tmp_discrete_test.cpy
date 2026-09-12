import "discrete.cpy"

def main():
    print(euc_gcd(48, 18))
    print(bin_gcd(48, 18))
    print(lcm(4, 6))
    ExtendedGCDResult g = extended_gcd(240, 46)
    print(g.gcd, g.x, g.y)
    print(inverse_mod(3, 11))
    print(mod_pow(7, 13, 11))
    print(is_prime(97))
