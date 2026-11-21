ccode:
    #include <stddef.h>
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>
    #include <openssl/evp.h>
    #include <openssl/hmac.h>
    #include <openssl/crypto.h>
    #include <openssl/params.h>
    #include <openssl/core_names.h>

    static void cpy_hash_wipe(void *ptr, size_t length) {
      if (!ptr || length == 0) return;
      OPENSSL_cleanse(ptr, length);
    }

    static int cpy_evp_digest(const EVP_MD *md, const void *input, size_t length, void *output) {
      if ((!input && length) || !output || !md) return -1;
      EVP_MD_CTX *ctx = EVP_MD_CTX_new();
      if (!ctx) return -1;
      int ok = 0;
      if (EVP_DigestInit_ex(ctx, md, NULL) == 1 &&
          (length == 0 || EVP_DigestUpdate(ctx, input, length) == 1) &&
          EVP_DigestFinal_ex(ctx, (unsigned char*)output, NULL) == 1) {
        ok = 1;
      }
      EVP_MD_CTX_free(ctx);
      return ok ? 0 : -1;
    }

    int cpy_sha256_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha256(), input, length, output);
    }
    int cpy_sha384_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha384(), input, length, output);
    }
    int cpy_sha512_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha512(), input, length, output);
    }
    int cpy_sha3_256_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha3_256(), input, length, output);
    }
    int cpy_sha3_384_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha3_384(), input, length, output);
    }
    int cpy_sha3_512_digest(const void *input, size_t length, void *output) {
      return cpy_evp_digest(EVP_sha3_512(), input, length, output);
    }

    /* BLAKE2: unkeyed via EVP_Digest (blake2b512/s256), keyed via EVP_MAC (BLAKE2BMAC/BLAKE2SMAC). */
    int cpy_blake2b(const void *input, size_t length, const void *key, size_t keylen, void *output, size_t outlen) {
      if ((!input && length) || (!key && keylen) || !output || outlen == 0 || outlen > 64 || keylen > 64) return -1;
    #if defined(OPENSSL_VERSION_NUMBER) && OPENSSL_VERSION_NUMBER >= 0x30000000L
      if (keylen == 0) {
        EVP_MD_CTX *ctx = EVP_MD_CTX_new();
        if (!ctx) return -1;
        const EVP_MD *md = EVP_blake2b512();
        if (!md) { EVP_MD_CTX_free(ctx); return -1; }
        int ok = -1;
        if (EVP_DigestInit_ex(ctx, md, NULL) != 1) { EVP_MD_CTX_free(ctx); return -1; }
        if (length > 0) {
          if (EVP_DigestUpdate(ctx, input, length) != 1) { EVP_MD_CTX_free(ctx); return -1; }
        }
        unsigned char tmp[64];
        unsigned int got = (unsigned int)outlen;
        if (EVP_DigestFinal_ex(ctx, tmp, &got) == 1 && got == (unsigned int)outlen) {
          memcpy(output, tmp, outlen);
          ok = 0;
        }
        EVP_MD_CTX_free(ctx);
        return ok;
      } else {
        EVP_MAC *mac = EVP_MAC_fetch(NULL, "BLAKE2BMAC", NULL);
        if (!mac) return -1;
        EVP_MAC_CTX *ctx = EVP_MAC_CTX_new(mac);
        EVP_MAC_free(mac);
        if (!ctx) return -1;
        int ok = -1;
        OSSL_PARAM params[2];
        size_t pcount = 0;
        params[pcount++] = OSSL_PARAM_construct_size_t(OSSL_MAC_PARAM_SIZE, &outlen);
        params[pcount++] = OSSL_PARAM_construct_end();
        const unsigned char *k = (const unsigned char*)key;
        if (EVP_MAC_init(ctx, k, keylen, params) != 1) {
          EVP_MAC_CTX_free(ctx);
          return -1;
        }
        if (length > 0) {
          if (EVP_MAC_update(ctx, (const unsigned char*)input, length) != 1) {
            EVP_MAC_CTX_free(ctx);
            return -1;
          }
        }
        size_t out_written = 0;
        if (EVP_MAC_final(ctx, (unsigned char*)output, &out_written, outlen) == 1 && out_written == outlen) {
          ok = 0;
        }
        EVP_MAC_CTX_free(ctx);
        return ok;
      }
    #else
      (void)input; (void)length; (void)key; (void)keylen; (void)output; (void)outlen;
      return -1;
    #endif
    }

    int cpy_blake2s(const void *input, size_t length, const void *key, size_t keylen, void *output, size_t outlen) {
      if ((!input && length) || (!key && keylen) || !output || outlen == 0 || outlen > 32 || keylen > 32) return -1;
    #if defined(OPENSSL_VERSION_NUMBER) && OPENSSL_VERSION_NUMBER >= 0x30000000L
      if (keylen == 0) {
        EVP_MD_CTX *ctx = EVP_MD_CTX_new();
        if (!ctx) return -1;
        const EVP_MD *md = EVP_blake2s256();
        if (!md) { EVP_MD_CTX_free(ctx); return -1; }
        int ok = -1;
        if (EVP_DigestInit_ex(ctx, md, NULL) != 1) { EVP_MD_CTX_free(ctx); return -1; }
        if (length > 0) {
          if (EVP_DigestUpdate(ctx, input, length) != 1) { EVP_MD_CTX_free(ctx); return -1; }
        }
        unsigned char tmp[32];
        unsigned int got = (unsigned int)outlen;
        if (EVP_DigestFinal_ex(ctx, tmp, &got) == 1 && got == (unsigned int)outlen) {
          memcpy(output, tmp, outlen);
          ok = 0;
        }
        EVP_MD_CTX_free(ctx);
        return ok;
      } else {
        EVP_MAC *mac = EVP_MAC_fetch(NULL, "BLAKE2SMAC", NULL);
        if (!mac) return -1;
        EVP_MAC_CTX *ctx = EVP_MAC_CTX_new(mac);
        EVP_MAC_free(mac);
        if (!ctx) return -1;
        int ok = -1;
        OSSL_PARAM params[2];
        size_t pcount = 0;
        params[pcount++] = OSSL_PARAM_construct_size_t(OSSL_MAC_PARAM_SIZE, &outlen);
        params[pcount++] = OSSL_PARAM_construct_end();
        const unsigned char *k = (const unsigned char*)key;
        if (EVP_MAC_init(ctx, k, keylen, params) != 1) {
          EVP_MAC_CTX_free(ctx);
          return -1;
        }
        if (length > 0) {
          if (EVP_MAC_update(ctx, (const unsigned char*)input, length) != 1) {
            EVP_MAC_CTX_free(ctx);
            return -1;
          }
        }
        size_t out_written = 0;
        if (EVP_MAC_final(ctx, (unsigned char*)output, &out_written, outlen) == 1 && out_written == outlen) {
          ok = 0;
        }
        EVP_MAC_CTX_free(ctx);
        return ok;
      }
    #else
      (void)input; (void)length; (void)key; (void)keylen; (void)output; (void)outlen;
      return -1;
    #endif
    }

    int cpy_hmac_sha256(const void *key, size_t keylen, const void *data, size_t len, void *out) {
      if ((!key && keylen) || (!data && len) || !out) return -1;
      unsigned int outlen = 0;
      unsigned char *res = HMAC(EVP_sha256(), key, (int)keylen, (const unsigned char*)data, len, (unsigned char*)out, &outlen);
      if (res == NULL) return -1;
      return (outlen == 32) ? 0 : -1;
    }

    int cpy_hmac_sha512(const void *key, size_t keylen, const void *data, size_t len, void *out) {
      if ((!key && keylen) || (!data && len) || !out) return -1;
      unsigned int outlen = 0;
      unsigned char *res = HMAC(EVP_sha512(), key, (int)keylen, (const unsigned char*)data, len, (unsigned char*)out, &outlen);
      if (res == NULL) return -1;
      return (outlen == 64) ? 0 : -1;
    }

    int cpy_hash_hex(const void *input, size_t length, char *output, size_t digest_len) {
      static const char hex[] = "0123456789abcdef";
      if ((!input && length) || !output || digest_len > SIZE_MAX / 2) return -1;
      const unsigned char *p = (const unsigned char*)input;
      for (size_t i = 0; i < digest_len; ++i) {
        output[i*2] = hex[p[i] >> 4];
        output[i*2+1] = hex[p[i] & 15];
      }
      output[digest_len*2] = 0;
      return 0;
    }

    int cpy_hash_equal(const void *a, const void *b, size_t n) {
      if ((!a || !b) && n) return 0;
      const volatile unsigned char *x = (const volatile unsigned char*)a;
      const volatile unsigned char *y = (const volatile unsigned char*)b;
      unsigned char diff = 0;
      for (size_t i = 0; i < n; ++i) diff |= x[i] ^ y[i];
      return diff == 0;
    }

public def sha256_into(data void*, length size_t, output void*) -> int:
    return cpy_sha256_digest(data, length, output)

public def sha384_into(data void*, length size_t, output void*) -> int:
    return cpy_sha384_digest(data, length, output)

public def sha512_into(data void*, length size_t, output void*) -> int:
    return cpy_sha512_digest(data, length, output)

public def sha3_256_into(data void*, length size_t, output void*) -> int:
    return cpy_sha3_256_digest(data, length, output)

public def sha3_384_into(data void*, length size_t, output void*) -> int:
    return cpy_sha3_384_digest(data, length, output)

public def sha3_512_into(data void*, length size_t, output void*) -> int:
    return cpy_sha3_512_digest(data, length, output)

public def blake2b_into(data void*, length size_t, key void*, key_length size_t, output void*, output_length size_t) -> int:
    return cpy_blake2b(data, length, key, key_length, output, output_length)

public def blake2s_into(data void*, length size_t, key void*, key_length size_t, output void*, output_length size_t) -> int:
    return cpy_blake2s(data, length, key, key_length, output, output_length)

public def hmac_sha256_into(key void*, key_length size_t, data void*, length size_t, output void*) -> int:
    return cpy_hmac_sha256(key, key_length, data, length, output)

public def hmac_sha512_into(key void*, key_length size_t, data void*, length size_t, output void*) -> int:
    return cpy_hmac_sha512(key, key_length, data, length, output)

public def hash_to_hex(digest void*, digest_length size_t, output char*) -> int:
    return cpy_hash_hex(digest, digest_length, output, digest_length)

public def sha256(data char[]) -> char[]:
    char[] digest = new char[32]
    sha256_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha384(data char[]) -> char[]:
    char[] digest = new char[48]
    sha384_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha512(data char[]) -> char[]:
    char[] digest = new char[64]
    sha512_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha3_256(data char[]) -> char[]:
    char[] digest = new char[32]
    sha3_256_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha3_384(data char[]) -> char[]:
    char[] digest = new char[48]
    sha3_384_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha3_512(data char[]) -> char[]:
    char[] digest = new char[64]
    sha3_512_into((void*)data, (size_t)len(data), (void*)digest)
    return digest

public def blake2b(data char[]) -> char[]:
    char[] digest = new char[64]
    blake2b_into((void*)data, (size_t)len(data), null, 0, (void*)digest, 64)
    return digest

public def blake2s(data char[]) -> char[]:
    char[] digest = new char[32]
    blake2s_into((void*)data, (size_t)len(data), null, 0, (void*)digest, 32)
    return digest

public def blake2b_keyed(data char[], key char[]) -> char[]:
    char[] digest = new char[64]
    blake2b_into((void*)data, (size_t)len(data), (void*)key, (size_t)len(key), (void*)digest, 64)
    return digest

public def blake2s_keyed(data char[], key char[]) -> char[]:
    char[] digest = new char[32]
    blake2s_into((void*)data, (size_t)len(data), (void*)key, (size_t)len(key), (void*)digest, 32)
    return digest

public def hmac_sha256(key char[], data char[]) -> char[]:
    char[] digest = new char[32]
    hmac_sha256_into((void*)key, (size_t)len(key), (void*)data, (size_t)len(data), (void*)digest)
    return digest

public def hmac_sha512(key char[], data char[]) -> char[]:
    char[] digest = new char[64]
    hmac_sha512_into((void*)key, (size_t)len(key), (void*)data, (size_t)len(data), (void*)digest)
    return digest

public def sha256_string(data str) -> char[]:
    char[] bytes = new char[len(data)]
    int i = 0
    while i < len(data):
        bytes[i] = (char)data[i]
        i += 1
    return sha256(bytes)

public def sha512_string(data str) -> char[]:
    char[] bytes = new char[len(data)]
    int i = 0
    while i < len(data):
        bytes[i] = (char)data[i]
        i += 1
    return sha512(bytes)

public def digest_hex(digest char[]) -> char[]:
    int64 n = len(digest)
    char[] output = new char[n * 2 + 1]
    cpy_hash_hex((void*)digest, (size_t)n, (char*)output, (size_t)n)
    return output

public def sha256_hex(data char[]) -> char[]:
    return digest_hex(sha256(data))

public def sha384_hex(data char[]) -> char[]:
    return digest_hex(sha384(data))

public def sha512_hex(data char[]) -> char[]:
    return digest_hex(sha512(data))

public def sha3_256_hex(data char[]) -> char[]:
    return digest_hex(sha3_256(data))

public def sha3_384_hex(data char[]) -> char[]:
    return digest_hex(sha3_384(data))

public def sha3_512_hex(data char[]) -> char[]:
    return digest_hex(sha3_512(data))

public def blake2b_hex(data char[]) -> char[]:
    return digest_hex(blake2b(data))

public def blake2s_hex(data char[]) -> char[]:
    return digest_hex(blake2s(data))

public def hash_equal(left void*, right void*, length size_t) -> int:
    return cpy_hash_equal(left, right, length)
