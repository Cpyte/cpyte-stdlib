import "hash.cpy"

ccode:
    #include <stddef.h>
    #include <string.h>

    /* <string.h> fortifies memcpy/memset on Darwin and glibc, so the libc names
     * cannot be re-declared from cpyte; call through these shims instead. The
     * cpy_ prefix keeps them from colliding with collections/mem.cpy. */
    void* cpy_kdf_memcpy(void* dst, void* src, long long n) {
        return memcpy(dst, src, (size_t)n);
    }
    void* cpy_kdf_memset(void* dst, int c, long long n) {
        return memset(dst, c, (size_t)n);
    }

public def hkdf_extract(salt void*, salt_len size_t, ikm void*, ikm_len size_t) -> char[]:
    char[] prk = new char[32]
    void* _salt = salt
    size_t _salt_len = salt_len

    # RFC 5869 2.2: a zero-length salt is replaced by HashLen zeros.
    if salt_len == 0:
        char[32] zero_salt
        cpy_kdf_memset((void*)zero_salt, 0, 32)
        _salt = (void*)zero_salt
        _salt_len = 32

    hmac_sha256_into(_salt, _salt_len, ikm, ikm_len, (void*)prk)
    return prk

public def hkdf_expand(prk void*, prk_len size_t, info void*, info_len size_t, output void*, L size_t) -> int:
    if L > 8160:
        return -1
    if L == 0:
        return 0

    # msg is the reusable HMAC input T(i-1) || info || counter, with info parked
    # at offset 32 so the (empty) T(0) round can simply start the input there.
    size_t msg_len = 32 + info_len + 1
    char[] msg = new char[msg_len]
    char[] block = new char[32]
    if info_len > 0:
        cpy_kdf_memcpy((void*)((char*)msg + 32), info, (int64)info_len)

    size_t offset = 0
    size_t t_len = 0
    int counter = 1
    while offset < L:
        msg[32 + info_len] = (char)counter
        char* hmsg = (char*)msg + (32 - t_len)
        hmac_sha256_into(prk, prk_len, (void*)hmsg, t_len + info_len + 1, (void*)block)

        size_t take = L - offset
        if take > 32:
            take = 32

        cpy_kdf_memcpy((void*)((char*)output + offset), (void*)block, (int64)take)
        cpy_kdf_memcpy((void*)msg, (void*)block, 32)
        offset += take
        t_len = 32
        counter += 1

    return 0

public def hkdf(salt void*, salt_len size_t, ikm void*, ikm_len size_t,
                info void*, info_len size_t, L size_t) -> char[]:
    char[] okm = new char[L]
    char[] prk = hkdf_extract(salt, salt_len, ikm, ikm_len)
    hkdf_expand((void*)prk, 32, info, info_len, (void*)okm, L)
    return okm
