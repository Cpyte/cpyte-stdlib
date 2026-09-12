import stdlib
import "statistics.cpy"
import "discrete.cpy"
import "scalar.cpy"

def main():
    double[] v = new double[4]
    v[0] = 1.0
    v[1] = 2.0
    v[2] = 3.0
    v[3] = 4.0
    print("sum", stats_sum((double*)v, 4))
    print("mean", stats_mean((double*)v, 4))
    print("min", stats_min((double*)v, 4))
    print("max", stats_max((double*)v, 4))
    print("std", stats_stddev((double*)v, 4))
    print("gcd", euc_gcd(48, 36))
    print("lcm", lcm(4, 6))
    print("isprime97", is_prime(97))
    print("m5 PASS")
