# Self-check for @std/time. Everything asserted here is timezone-independent:
# the UTC calendar is fixed, and the local functions are only checked for
# round-tripping against themselves.

import "time.cpy"

def check_i(name str, got int64, want int64) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_s(name str, got str, want str) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_b(name str, got bool, want bool) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

# 2023-11-14T22:13:20Z
def epoch_ref() -> int64:
    return (int64)1700000000

def test_calendar() -> int:
    int n = 0
    int64 ts = epoch_ref()
    n += check_i("utc year", (int64)time_utc_year(ts), 2023)
    n += check_i("utc month", (int64)time_utc_month(ts), 11)
    n += check_i("utc day", (int64)time_utc_day(ts), 14)
    n += check_i("utc hour", (int64)time_utc_hour(ts), 22)
    n += check_i("utc minute", (int64)time_utc_minute(ts), 13)
    n += check_i("utc second", (int64)time_utc_second(ts), 20)
    n += check_i("utc weekday tue", (int64)time_utc_weekday(ts), 2)
    n += check_i("utc yday", (int64)time_utc_yday(ts), 318)
    n += check_i("epoch year", (int64)time_utc_year((int64)0), 1970)
    n += check_i("epoch month", (int64)time_utc_month((int64)0), 1)
    n += check_i("epoch day", (int64)time_utc_day((int64)0), 1)
    n += check_i("epoch weekday thu", (int64)time_utc_weekday((int64)0), 4)
    n += check_i("epoch yday", (int64)time_utc_yday((int64)0), 1)
    n += check_i("one day", (int64)time_utc_day((int64)86400), 2)
    n += check_i("leap day year", (int64)time_utc_year((int64)1709164800), 2024)
    n += check_i("leap day month", (int64)time_utc_month((int64)1709164800), 2)
    n += check_i("leap day", (int64)time_utc_day((int64)1709164800), 29)
    return n

def test_conversion() -> int:
    int n = 0
    n += check_i("from_parts utc",
                 time_utc_from_parts(2023, 11, 14, 22, 13, 20), epoch_ref())
    n += check_i("from_parts epoch", time_utc_from_parts(1970, 1, 1, 0, 0, 0), (int64)0)
    n += check_i("from_parts 2000", time_utc_from_parts(2000, 1, 1, 0, 0, 0), (int64)946684800)
    # Local fields rebuilt into a local timestamp must land on the same instant.
    int64 ts = epoch_ref()
    n += check_i("local round trip",
                 time_local_from_parts(time_local_year(ts), time_local_month(ts),
                                       time_local_day(ts), time_local_hour(ts),
                                       time_local_minute(ts), time_local_second(ts)),
                 ts)
    n += check_b("leap 2024", time_is_leap(2024), true)
    n += check_b("leap 2023", time_is_leap(2023), false)
    n += check_b("leap 1900", time_is_leap(1900), false)
    n += check_b("leap 2000", time_is_leap(2000), true)
    n += check_i("feb leap", (int64)time_days_in_month(2024, 2), 29)
    n += check_i("feb common", (int64)time_days_in_month(2023, 2), 28)
    n += check_i("april", (int64)time_days_in_month(2024, 4), 30)
    n += check_i("december", (int64)time_days_in_month(2024, 12), 31)
    n += check_i("bad month", (int64)time_days_in_month(2024, 13), 0)
    return n

def test_format() -> int:
    int n = 0
    int64 ts = epoch_ref()
    n += check_s("iso", time_utc_iso(ts), "2023-11-14T22:13:20Z")
    n += check_s("date", time_utc_date(ts), "2023-11-14")
    n += check_s("custom", time_utc_format(ts, "%Y/%m/%d %H:%M"), "2023/11/14 22:13")
    n += check_s("epoch iso", time_utc_iso((int64)0), "1970-01-01T00:00:00Z")
    n += check_s("empty fmt", time_utc_format(ts, ""), "")
    return n

def test_clocks() -> int:
    int n = 0
    int64 now = time_now()
    if now < (int64)1700000000:
        print("FAIL wall clock looks wrong", now)
        n += 1
    int64 delta_ms = time_millis() - now * (int64)1000
    if delta_ms < (int64)0:
        delta_ms = delta_ms * (int64)-1
    if delta_ms > (int64)5000:
        print("FAIL millis disagrees with seconds", delta_ms)
        n += 1
    if time_micros() < time_millis() * (int64)1000 - (int64)1000000:
        print("FAIL micros behind millis")
        n += 1
    int64 mono_a = time_mono_nanos()
    int64 spin = 0
    while spin < 200000:
        spin = spin + 1
    int64 mono_b = time_mono_nanos()
    if mono_b < mono_a:
        print("FAIL monotonic went backwards")
        n += 1
    int64 before = time_mono_nanos()
    sleep_millis(20)
    int64 after = time_mono_nanos()
    if after - before < (int64)10000000:
        print("FAIL sleep returned early", after - before)
        n += 1
    sleep_for(0.0)
    if time_cpu_micros() < (int64)0:
        print("FAIL cpu clock negative")
        n += 1
    return n

public def main() -> int:
    int n = 0
    n += test_calendar()
    n += test_conversion()
    n += test_format()
    n += test_clocks()
    if n == 0:
        print("time: PASS")
    else:
        print("time: FAIL", n)
    return n
