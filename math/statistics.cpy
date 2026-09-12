import stdlib
import "scalar.cpy"

public def stats_sum(values double*, n int) -> double:
    assert n >= 0, "Statistics length cannot be negative"
    double total = 0.0
    int i = 0
    while i < n:
        total = total + values[i]
        i = i + 1
    return total

public def stats_mean(values double*, n int) -> double:
    assert n > 0, "Mean requires at least one value"
    return stats_sum(values, n) / n

public def stats_min(values double*, n int) -> double:
    assert n > 0, "Minimum requires at least one value"
    double result = values[0]
    int i = 1
    while i < n:
        if values[i] < result:
            result = values[i]
        i = i + 1
    return result

public def stats_max(values double*, n int) -> double:
    assert n > 0, "Maximum requires at least one value"
    double result = values[0]
    int i = 1
    while i < n:
        if values[i] > result:
            result = values[i]
        i = i + 1
    return result

public def stats_variance(values double*, n int) -> double:
    assert n > 0, "Variance requires at least one value"
    double mean = stats_mean(values, n)
    double total = 0.0
    int i = 0
    while i < n:
        double delta = values[i] - mean
        total = total + delta * delta
        i = i + 1
    return total / n

public def stats_sample_variance(values double*, n int) -> double:
    assert n > 1, "Sample variance requires at least two values"
    double mean = stats_mean(values, n)
    double total = 0.0
    int i = 0
    while i < n:
        double delta = values[i] - mean
        total = total + delta * delta
        i = i + 1
    return total / (n - 1)

public def stats_stddev(values double*, n int) -> double:
    return scalar_sqrt(stats_variance(values, n))

public def stats_sample_stddev(values double*, n int) -> double:
    return scalar_sqrt(stats_sample_variance(values, n))

public def stats_dot(a double*, b double*, n int) -> double:
    assert n >= 0, "Dot-product length cannot be negative"
    double total = 0.0
    int i = 0
    while i < n:
        total = total + a[i] * b[i]
        i = i + 1
    return total

public def stats_rms(values double*, n int) -> double:
    assert n > 0, "RMS requires at least one value"
    return scalar_sqrt(stats_dot(values, values, n) / n)

public def stats_weighted_mean(values double*, weights double*, n int) -> double:
    assert n > 0, "Weighted mean requires at least one value"
    double weighted = stats_dot(values, weights, n)
    double total_weight = stats_sum(weights, n)
    assert total_weight != 0.0, "Weighted mean requires non-zero total weight"
    return weighted / total_weight
