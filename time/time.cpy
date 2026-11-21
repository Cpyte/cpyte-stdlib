# @std/time — wall clock, monotonic clock, calendar fields and sleep.
#
# One C runtime, three platforms: Windows uses the filetime/query-performance
# APIs, everything else uses clock_gettime with a gettimeofday fallback. The
# cpy surface is scalar on purpose — calendar fields come back one at a time
# instead of through a struct, so no C layout is exposed to callers.
#
# Timestamps are Unix time (seconds since 1970-01-01T00:00:00Z) unless the name
# says otherwise; `time_utc_*` functions are the deterministic ones and
# `time_*` without `utc` uses the process's local timezone.

ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <string.h>
    #include <time.h>

    #ifdef _WIN32
        #define WIN32_LEAN_AND_MEAN
        #include <windows.h>
        /* 100ns ticks between 1601-01-01 and 1970-01-01. */
        #define EPOCH_AS_FILETIME (116444736000000000ULL)

        static void filetime_to_parts(const FILETIME* ft, int64_t* secs, int64_t* nanos) {
            unsigned long long raw =
                ((unsigned long long)ft->dwHighDateTime << 32) | ft->dwLowDateTime;
            if (raw < EPOCH_AS_FILETIME) {
                *secs = 0;
                *nanos = 0;
                return;
            }
            raw -= EPOCH_AS_FILETIME;
            *secs = (int64_t)(raw / 10000000ULL);
            *nanos = (int64_t)((raw % 10000000ULL) * 100ULL);
        }

        static void win_gmtime(const time_t* t, struct tm* out) {
            memset(out, 0, sizeof(*out));
            gmtime_s(out, t);
        }

        static void win_localtime(const time_t* t, struct tm* out) {
            memset(out, 0, sizeof(*out));
            localtime_s(out, t);
        }

        static time_t win_timegm(struct tm* tm) {
            return _mkgmtime(tm);
        }
    #else
        #include <sys/time.h>
        #if defined(__APPLE__) || defined(__unix__) || defined(__linux__)
            #include <unistd.h>
        #endif

        static void win_gmtime(const time_t* t, struct tm* out) {
            memset(out, 0, sizeof(*out));
            gmtime_r(t, out);
        }

        static void win_localtime(const time_t* t, struct tm* out) {
            memset(out, 0, sizeof(*out));
            localtime_r(t, out);
        }

        /* time_gm() is the BSD name, timegm() the glibc one; fall back to an
           explicit timezone offset if neither is declared. */
        static time_t win_timegm(struct tm* tm) {
            #if defined(__GLIBC__) || defined(__bsd__) || defined(__NetBSD__) || \
                defined(__OpenBSD__) || defined(__APPLE__)
                extern time_t timegm(struct tm*);
                return timegm(tm);
            #else
                return mktime(tm);
            #endif
        }
    #endif

    static void now_parts(int64_t* secs, int64_t* nanos) {
        #ifdef _WIN32
            FILETIME ft;
            GetSystemTimeAsFileTime(&ft);
            filetime_to_parts(&ft, secs, nanos);
        #elif defined(CLOCK_REALTIME)
            struct timespec ts;
            if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
                *secs = (int64_t)ts.tv_sec;
                *nanos = (int64_t)ts.tv_nsec;
                return;
            }
            struct timeval tv;
            gettimeofday(&tv, NULL);
            *secs = (int64_t)tv.tv_sec;
            *nanos = (int64_t)tv.tv_usec * 1000;
        #else
            struct timeval tv;
            gettimeofday(&tv, NULL);
            *secs = (int64_t)tv.tv_sec;
            *nanos = (int64_t)tv.tv_usec * 1000;
        #endif
    }

    int64_t cpy_time_now(void) {
        int64_t s = 0, ns = 0;
        now_parts(&s, &ns);
        return s;
    }

    int64_t cpy_time_millis(void) {
        int64_t s = 0, ns = 0;
        now_parts(&s, &ns);
        return s * 1000 + ns / 1000000;
    }

    int64_t cpy_time_micros(void) {
        int64_t s = 0, ns = 0;
        now_parts(&s, &ns);
        return s * 1000000 + ns / 1000;
    }

    int64_t cpy_time_nanos(void) {
        int64_t s = 0, ns = 0;
        now_parts(&s, &ns);
        return s * 1000000000 + ns;
    }

    int64_t cpy_time_mono_nanos(void) {
        #ifdef _WIN32
            LARGE_INTEGER freq, count;
            QueryPerformanceFrequency(&freq);
            QueryPerformanceCounter(&count);
            if (freq.QuadPart == 0) return (int64_t)GetTickCount64() * 1000000ULL;
            return (int64_t)((count.QuadPart * 1000000000ULL) / freq.QuadPart);
        #elif defined(CLOCK_MONOTONIC)
            struct timespec ts;
            if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0)
                return (int64_t)ts.tv_sec * 1000000000 + (int64_t)ts.tv_nsec;
            return (int64_t)0;
        #else
            return (int64_t)clock();
        #endif
    }

    int64_t cpy_time_cpu_micros(void) {
        /* CLOCKS_PER_SEC is 1e6 on MSVC and 1e7 on Darwin; scale to microseconds. */
        int64_t ticks = (int64_t)clock();
        int64_t per = (int64_t)CLOCKS_PER_SEC;
        if (per <= 0) return (int64_t)0;
        return ticks * 1000000 / per;
    }

    /* which: 0 year, 1 month (1-12), 2 day of month, 3 hour, 4 minute,
       5 second, 6 weekday (0=Sunday), 7 day of year (1-based), 8 dst flag. */
    int64_t cpy_time_field(int64_t secs, int which, int utc) {
        time_t t = (time_t)secs;
        struct tm parts;
        if (utc) win_gmtime(&t, &parts); else win_localtime(&t, &parts);
        switch (which) {
            case 0: return (int64_t)parts.tm_year + 1900;
            case 1: return (int64_t)parts.tm_mon + 1;
            case 2: return (int64_t)parts.tm_mday;
            case 3: return (int64_t)parts.tm_hour;
            case 4: return (int64_t)parts.tm_min;
            case 5: return (int64_t)parts.tm_sec;
            case 6: return (int64_t)parts.tm_wday;
            case 7: return (int64_t)parts.tm_yday + 1;
            default: return (int64_t)parts.tm_isdst;
        }
    }

    int64_t cpy_time_from_parts(int year, int month, int day, int hour,
                                int minute, int second, int utc) {
        struct tm parts;
        memset(&parts, 0, sizeof(parts));
        parts.tm_year = year - 1900;
        parts.tm_mon = month - 1;
        parts.tm_mday = day;
        parts.tm_hour = hour;
        parts.tm_min = minute;
        parts.tm_sec = second;
        parts.tm_isdst = -1;
        if (utc) return (int64_t)win_timegm(&parts);
        return (int64_t)mktime(&parts);
    }

    int64_t cpy_time_offset_seconds(void) {
        /* Local time minus UTC, in seconds: what Python calls `localtime().tm_gmtoff`. */
        time_t t = time(NULL);
        struct tm local_parts, utc_parts;
        win_localtime(&t, &local_parts);
        win_gmtime(&t, &utc_parts);
        int64_t a = (int64_t)mktime(&local_parts);
        int64_t b = (int64_t)win_timegm(&utc_parts);
        return a - b;
    }

    /* strftime into dst; returns the byte length, or -1 if it did not fit. */
    int64_t cpy_time_format(int64_t secs, const char* fmt, void* dst,
                            int64_t cap, int utc) {
        if (dst == NULL || cap <= 0 || fmt == NULL) return (int64_t)-1;
        time_t t = (time_t)secs;
        struct tm parts;
        if (utc) win_gmtime(&t, &parts); else win_localtime(&t, &parts);
        size_t written = strftime((char*)dst, (size_t)cap, fmt, &parts);
        if (written == 0) return (int64_t)-1;
        return (int64_t)written;
    }

    void cpy_sleep_seconds(double seconds) {
        if (seconds <= 0.0) return;
        #ifdef _WIN32
            Sleep((DWORD)(seconds * 1000.0));
        #elif defined(_POSIX_VERSION) || defined(__APPLE__) || defined(__unix__) || defined(__linux__)
            struct timespec req;
            req.tv_sec = (time_t)seconds;
            req.tv_nsec = (long)((seconds - (double)req.tv_sec) * 1e9);
            while (nanosleep(&req, &req) != 0) { }
        #else
            Sleep((DWORD)(seconds * 1000.0));
        #endif
    }

# ── clocks ──────────────────────────────────────────────────────

public def time_now() -> int64:
    return cpy_time_now()

public def time_millis() -> int64:
    return cpy_time_millis()

public def time_micros() -> int64:
    return cpy_time_micros()

public def time_nanos() -> int64:
    return cpy_time_nanos()

public def time_mono_nanos() -> int64:
    return cpy_time_mono_nanos()

public def time_cpu_micros() -> int64:
    return cpy_time_cpu_micros()

public def time_epoch_seconds() -> int64:
    return cpy_time_now()

# ── calendar fields ─────────────────────────────────────────────

public def time_utc_year(ts int64) -> int:
    return (int)cpy_time_field(ts, 0, 1)

public def time_utc_month(ts int64) -> int:
    return (int)cpy_time_field(ts, 1, 1)

public def time_utc_day(ts int64) -> int:
    return (int)cpy_time_field(ts, 2, 1)

public def time_utc_hour(ts int64) -> int:
    return (int)cpy_time_field(ts, 3, 1)

public def time_utc_minute(ts int64) -> int:
    return (int)cpy_time_field(ts, 4, 1)

public def time_utc_second(ts int64) -> int:
    return (int)cpy_time_field(ts, 5, 1)

public def time_utc_weekday(ts int64) -> int:
    return (int)cpy_time_field(ts, 6, 1)

public def time_utc_yday(ts int64) -> int:
    return (int)cpy_time_field(ts, 7, 1)

public def time_local_year(ts int64) -> int:
    return (int)cpy_time_field(ts, 0, 0)

public def time_local_month(ts int64) -> int:
    return (int)cpy_time_field(ts, 1, 0)

public def time_local_day(ts int64) -> int:
    return (int)cpy_time_field(ts, 2, 0)

public def time_local_hour(ts int64) -> int:
    return (int)cpy_time_field(ts, 3, 0)

public def time_local_minute(ts int64) -> int:
    return (int)cpy_time_field(ts, 4, 0)

public def time_local_second(ts int64) -> int:
    return (int)cpy_time_field(ts, 5, 0)

public def time_local_weekday(ts int64) -> int:
    return (int)cpy_time_field(ts, 6, 0)

public def time_utc_offset_seconds() -> int:
    return (int)cpy_time_offset_seconds()

# year is full (2024), month is 1-12; interpreted as UTC.
public def time_utc_from_parts(year int, month int, day int,
                               hour int, minute int, second int) -> int64:
    return cpy_time_from_parts(year, month, day, hour, minute, second, 1)

# Same fields in the process's local timezone (DST resolved by the C library).
public def time_local_from_parts(year int, month int, day int,
                                 hour int, minute int, second int) -> int64:
    return cpy_time_from_parts(year, month, day, hour, minute, second, 0)

public def time_is_leap(year int) -> bool:
    if year % 4 != 0:
        return false
    if year % 100 != 0:
        return true
    return year % 400 == 0

# 1=January; invalid months report 0.
public def time_days_in_month(year int, month int) -> int:
    if month < 1 or month > 12:
        return 0
    if month == 2:
        if time_is_leap(year):
            return 29
        return 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31

# ── formatting ──────────────────────────────────────────────────

def format_with(ts int64, fmt str, utc int) -> str:
    char[] buf = new char[256]
    int64 written = cpy_time_format(ts, fmt, (void*)buf, (int64)256, utc)
    if written < (int64)0:
        return ""
    return (str)buf

public def time_utc_format(ts int64, fmt str) -> str:
    return format_with(ts, fmt, 1)

public def time_local_format(ts int64, fmt str) -> str:
    return format_with(ts, fmt, 0)

# ISO-8601 UTC stamp, e.g. "2023-11-14T22:13:20Z".
public def time_utc_iso(ts int64) -> str:
    return time_utc_format(ts, "%Y-%m-%dT%H:%M:%SZ")

public def time_utc_date(ts int64) -> str:
    return time_utc_format(ts, "%Y-%m-%d")

# ── sleeping ────────────────────────────────────────────────────

public def sleep_for(seconds double) -> void:
    cpy_sleep_seconds(seconds)

public def sleep_millis(milliseconds int) -> void:
    cpy_sleep_seconds((double)milliseconds / 1000.0)
