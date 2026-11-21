ccode:
  #include <stddef.h>
  #include <string.h>
  #include <openssl/rand.h>
  #include <openssl/crypto.h>

  static void secure_zero(void* b, size_t n) {
    if (n == 0 || b == NULL) return;
    OPENSSL_cleanse(b, n);
  }

  int cpy_fill_random(void* b, size_t n) {
    if (n == 0) return 0;
    if (RAND_bytes((unsigned char*)b, (int)n) != 1) {
      return -1;
    }
    return 0;
  }

  void cpy_zero(void* b, size_t n) {
    secure_zero(b, n);
  }

private def _randbyte(dst void*, n int64) -> int:
    char* p = (char*)dst
    int64 left = n
    while left > 0:
        int64 chunk = left
        if chunk > 0x7FFFFFFF:
            chunk = 0x7FFFFFFF
        if cpy_fill_random(p, (size_t)chunk) != 0:
            return -1
        p = p + (int)chunk
        left -= chunk
    return 0

public def random_bytes(dst void*, n int64) -> int:
    if n < 0:
        return -1
    if n == 0:
        return 0
    if _randbyte(dst, n) != 0:
        return -1
    return 0

public def random_bits(dst void*, n int64) -> int:
    if n < 0:
        return -1
    if n == 0:
        return 0

    int64 bytes = n / 8
    if n % 8 != 0:
        bytes += 1
    if bytes > 0x7FFFFFFF:
        return -1

    char[] buf = new char[(int)bytes]
    if _randbyte(buf, bytes) != 0:
        cpy_zero((void*)buf, (size_t)bytes)
        return -1

    int rem = (int)(n & 7)
    if rem != 0:
        int idx = (int)(bytes - 1)
        buf[idx] = (char)((int)buf[idx] & ((1 << rem) - 1))

    char* pdst = (char*)dst
    char* psrc = (char*)buf
    int i = 0
    int bcount = (int)bytes
    while i < bcount:
        pdst[i] = psrc[i]
        i += 1
    cpy_zero((void*)buf, (size_t)bytes)
    return 0

public def random_u8() -> int:
    char[] b = new char[1]
    if _randbyte(b, 1) != 0:
        cpy_zero((void*)b, 1)
        return 0
    int v = (int)b[0] & 0xFF
    cpy_zero((void*)b, 1)
    return v

public def random_u16() -> int64:
    char[] b = new char[2]
    if _randbyte(b, 2) != 0:
        cpy_zero((void*)b, 2)
        return 0
    uint64 raw = 0
    raw = raw | (uint64)((int)b[0] & 0xFF)
    raw = raw | ((uint64)((int)b[1] & 0xFF)) << 8
    int64 r = (int64)raw
    cpy_zero((void*)b, 2)
    return r

public def random_u32() -> int64:
    char[] b = new char[4]
    if _randbyte(b, 4) != 0:
        cpy_zero((void*)b, 4)
        return 0
    uint64 raw = 0
    raw = raw | (uint64)((int)b[0] & 0xFF)
    raw = raw | ((uint64)((int)b[1] & 0xFF)) << 8
    raw = raw | ((uint64)((int)b[2] & 0xFF)) << 16
    raw = raw | ((uint64)((int)b[3] & 0xFF)) << 24
    int64 r = (int64)raw
    cpy_zero((void*)b, 4)
    return r

public def random_u64() -> uint64:
    char[] b = new char[8]
    if _randbyte(b, 8) != 0:
        cpy_zero((void*)b, 8)
        return 0
    uint64 raw = 0
    raw = raw | (uint64)((int)b[0] & 0xFF)
    raw = raw | ((uint64)((int)b[1] & 0xFF)) << 8
    raw = raw | ((uint64)((int)b[2] & 0xFF)) << 16
    raw = raw | ((uint64)((int)b[3] & 0xFF)) << 24
    raw = raw | ((uint64)((int)b[4] & 0xFF)) << 32
    raw = raw | ((uint64)((int)b[5] & 0xFF)) << 40
    raw = raw | ((uint64)((int)b[6] & 0xFF)) << 48
    raw = raw | ((uint64)((int)b[7] & 0xFF)) << 56
    cpy_zero((void*)b, 8)
    return raw

public def random_u128(lo void*, hi void*) -> int:
    if lo == 0 or hi == 0:
        return -1
    char[] b = new char[16]
    if _randbyte(b, 16) != 0:
        cpy_zero((void*)b, 16)
        return -1
    char* plo = (char*)lo
    char* phi = (char*)hi
    int i = 0
    while i < 8:
        plo[i] = b[i]
        i += 1
    i = 0
    while i < 8:
        phi[i] = b[8 + i]
        i += 1
    cpy_zero((void*)b, 16)
    return 0
