# @std/fs — file metadata, directory operations, and file contents I/O.
#
# Byte-oriented paths (`const char*`), so this covers POSIX plus Windows-ANSI
# paths; wide/UTF-16 Windows paths are out of scope.
#
# Provides: existence/kind checks, metadata, directory listing, mkdir/copy/
# rename/remove, path helpers, plus file handle open/read/write/seek/tell/
# close and whole-file read/write/append helpers (stdio-backed). Use raw byte
# modes like "rb"/"wb"/"ab" for binary data.
#
# Every string this package returns comes from a GC `char[]` buffer that the C
# side fills and terminates; no C-`malloc`'d pointer ever escapes into cpy.

ccode:
    #include <stdio.h>
    #include <stdint.h>
    #include <string.h>
    #include <sys/stat.h>

    #define CPY_FS_MAX 4096
    #define CPY_FS_MAX_ENTRIES 65536
    #define FS_MAX_HANDLES 64

    #ifdef _WIN32
        #include <direct.h>
        #include <io.h>
        #include <windows.h>
        #define CPY_STAT struct _stati64
        #define cpy_stat64 _stati64
        #define CPY_SEP '\\'
        #define S_CPY_ISDIR(m) (((m) & _S_IFMT) == _S_IFDIR)
        #define S_CPY_ISREG(m) (((m) & _S_IFMT) == _S_IFREG)
    #else
        #include <dirent.h>
        #include <stdlib.h>
        #include <sys/types.h>
        #include <unistd.h>
        #define CPY_STAT struct stat
        #define cpy_stat64 stat
        #define CPY_SEP '/'
        #define S_CPY_ISDIR(m) S_ISDIR(m)
        #define S_CPY_ISREG(m) S_ISREG(m)
    #endif

    static int64_t cpy_fs_len(const char* s) {
        return s == NULL ? (int64_t)0 : (int64_t)strlen(s);
    }

    /* ── existence + kind ─────────────────────────────────────── */

    int64_t cpy_fs_exists(const char* path) {
        CPY_STAT st;
        if (path == NULL || *path == 0) return (int64_t)0;
        return (int64_t)(cpy_stat64(path, &st) == 0);
    }

    int64_t cpy_fs_is_file(const char* path) {
        CPY_STAT st;
        if (path == NULL || cpy_stat64(path, &st) != 0) return (int64_t)0;
        return S_CPY_ISREG(st.st_mode) ? (int64_t)1 : (int64_t)0;
    }

    int64_t cpy_fs_is_dir(const char* path) {
        CPY_STAT st;
        if (path == NULL || cpy_stat64(path, &st) != 0) return (int64_t)0;
        return S_CPY_ISDIR(st.st_mode) ? (int64_t)1 : (int64_t)0;
    }

    /* 0 when readable, negative code otherwise. */
    int64_t cpy_fs_can_read(const char* path) {
        FILE* f;
        if (path == NULL || *path == 0) return (int64_t)-1;
        if (cpy_fs_is_dir(path)) return (int64_t)0; /* via readdir */
        #ifndef _WIN32
            if (access(path, 4) != 0) return (int64_t)-2;
        #endif
        f = fopen(path, "rb");
        if (f == NULL) return (int64_t)-3;
        fclose(f);
        return (int64_t)0;
    }

    int64_t cpy_fs_can_write(const char* path) {
        if (path == NULL || *path == 0) return (int64_t)-1;
        #ifdef _WIN32
            if (cpy_fs_is_dir(path)) {
                char probe[CPY_FS_MAX];
                FILE* f;
                if (strlen(path) + 24 >= sizeof(probe)) return (int64_t)-2;
                sprintf(probe, "%s\\.cpytest.%ld", path, (long)GetTickCount());
                f = fopen(probe, "wb");
                if (f == NULL) return (int64_t)-3;
                fclose(f);
                remove(probe);
                return (int64_t)0;
            }
            return (access(path, 2) == 0) ? (int64_t)0 : (int64_t)-4;
        #else
            return (access(path, 2) == 0) ? (int64_t)0 : (int64_t)-4;
        #endif
    }

    /* ── scalar metadata ──────────────────────────────────────── */

    int64_t cpy_fs_size(const char* path) {
        CPY_STAT st;
        if (path == NULL || cpy_stat64(path, &st) != 0) return (int64_t)-1;
        if (S_CPY_ISDIR(st.st_mode)) return (int64_t)-2;
        return (int64_t)st.st_size;
    }

    /* which: 0 = mode bits, 1 = mtime, 2 = ctime, 3 = atime, 4 = inode,
       5 = device, 6 = link count. */
    int64_t cpy_fs_field(const char* path, int which) {
        CPY_STAT st;
        if (path == NULL || cpy_stat64(path, &st) != 0) return (int64_t)-1;
        switch (which) {
            case 0: return (int64_t)(unsigned int)(st.st_mode & 07777);
            case 1: return (int64_t)st.st_mtime;
            case 2: return (int64_t)st.st_ctime;
            case 3: return (int64_t)st.st_atime;
            case 4: return (int64_t)st.st_ino;
            case 5: return (int64_t)st.st_dev;
            default: return (int64_t)st.st_nlink;
        }
    }

    /* Octal permission string, e.g. "644"; -1 when the path is missing. */
    int64_t cpy_fs_mode_text(const char* path, void* dst) {
        int64_t mode = cpy_fs_field(path, 0);
        if (mode < 0) return mode;
        sprintf((char*)dst, "%03o", (unsigned int)(mode & 07777));
        return (int64_t)4;
    }

    /* ── directory entries ────────────────────────────────────── */

    #ifndef _WIN32
        int64_t cpy_dir_count(const char* path) {
            DIR* d;
            struct dirent* e;
            int64_t n = 0;
            if (path == NULL) return (int64_t)-1;
            d = opendir(path);
            if (d == NULL) return (int64_t)-1;
            while ((e = readdir(d)) != NULL) {
                if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
                n++;
                if (n > CPY_FS_MAX_ENTRIES) break;
            }
            closedir(d);
            if (n > CPY_FS_MAX_ENTRIES) n = CPY_FS_MAX_ENTRIES;
            return n;
        }

        /* Total bytes needed to store every name (each NUL-terminated). */
        int64_t cpy_dir_bytes(const char* path) {
            DIR* d;
            struct dirent* e;
            int64_t total = 1;
            int64_t i = 0;
            d = opendir(path);
            if (d == NULL) return (int64_t)-1;
            while ((e = readdir(d)) != NULL) {
                if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
                total += (int64_t)strlen(e->d_name) + 1;
                i++;
                if (i >= CPY_FS_MAX_ENTRIES) break;
            }
            closedir(d);
            return total;
        }

        /* Copy up to `want` names into `buf` and store their addresses in
           `out` (a cpy str[]). Returns how many were written. */
        int64_t cpy_dir_fill(const char* path, void* out, void* buf,
                             int64_t cap, int64_t want) {
            DIR* d = opendir(path);
            char** dst = (char**)out;
            char* pool = (char*)buf;
            int64_t used = 0;
            int64_t n = 0;
            struct dirent* e;
            if (d == NULL) return (int64_t)0;
            while (n < want && (e = readdir(d)) != NULL) {
                if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
                int64_t need = (int64_t)strlen(e->d_name) + 1;
                if (used + need > cap) break;
                memcpy(pool + used, e->d_name, (size_t)need);
                dst[n] = pool + used;
                used += need;
                n++;
            }
            closedir(d);
            return n;
        }
    #else
        int64_t cpy_dir_count(const char* path) {
            struct _finddata_t iob;
            intptr_t h;
            int64_t n = 0;
            char pattern[CPY_FS_MAX];
            if (path == NULL || strlen(path) + 3 >= sizeof(pattern)) return (int64_t)-1;
            sprintf(pattern, "%s/*", path);
            h = _findfirst(pattern, &iob);
            if (h == -1) return (int64_t)-1;
            do {
                if (strcmp(iob.name, ".") == 0 || strcmp(iob.name, "..") == 0) { if (_findnext(h, &iob) == 0) continue; else break; }
                n++;
                if (n > CPY_FS_MAX_ENTRIES) break;
            } while (_findnext(h, &iob) == 0);
            _findclose(h);
            if (n > CPY_FS_MAX_ENTRIES) n = CPY_FS_MAX_ENTRIES;
            return n;
        }

        int64_t cpy_dir_bytes(const char* path) {
            struct _finddata_t iob;
            intptr_t h;
            int64_t total = 1;
            int64_t i = 0;
            char pattern[CPY_FS_MAX];
            if (strlen(path) + 3 >= sizeof(pattern)) return (int64_t)-1;
            sprintf(pattern, "%s/*", path);
            h = _findfirst(pattern, &iob);
            if (h == -1) return (int64_t)-1;
            do {
                if (strcmp(iob.name, ".") == 0 || strcmp(iob.name, "..") == 0) { if (_findnext(h, &iob) != 0) break; continue; }
                total += (int64_t)strlen(iob.name) + 1;
                i++;
                if (i >= CPY_FS_MAX_ENTRIES) break;
            } while (_findnext(h, &iob) == 0);
            _findclose(h);
            return total;
        }

        int64_t cpy_dir_fill(const char* path, void* out, void* buf,
                             int64_t cap, int64_t want) {
            struct _finddata_t iob;
            intptr_t h;
            char** dst = (char**)out;
            char* pool = (char*)buf;
            char pattern[CPY_FS_MAX];
            int64_t used = 0;
            int64_t n = 0;
            if (strlen(path) + 3 >= sizeof(pattern)) return (int64_t)0;
            sprintf(pattern, "%s/*", path);
            h = _findfirst(pattern, &iob);
            if (h == -1) return (int64_t)0;
            do {
                int64_t need;
                if (n >= want) break;
                if (strcmp(iob.name, ".") == 0 || strcmp(iob.name, "..") == 0) { if (_findnext(h, &iob) != 0) break; continue; }
                need = (int64_t)strlen(iob.name) + 1;
                if (used + need > cap) break;
                memcpy(pool + used, iob.name, (size_t)need);
                dst[n] = pool + used;
                used += need;
                n++;
            } while (_findnext(h, &iob) == 0);
            _findclose(h);
            return n;
        }
    #endif

    /* ── file handles (stdio-backed) ─────────────────────────── */

    static FILE* cpy_fs_handles[FS_MAX_HANDLES];
    static int64_t cpy_fs_handle_used[FS_MAX_HANDLES];

    static int64_t cpy_fs_alloc_handle(FILE* f) {
        for (int i = 0; i < FS_MAX_HANDLES; i++) {
            if (!cpy_fs_handle_used[i]) {
                cpy_fs_handles[i] = f;
                cpy_fs_handle_used[i] = 1;
                return (int64_t)(i + 1); /* 1-based */
            }
        }
        return (int64_t)-10;
    }

    static FILE* cpy_fs_get_handle(int64_t h) {
        if (h < 1 || h > FS_MAX_HANDLES) return NULL;
        if (!cpy_fs_handle_used[h - 1]) return NULL;
        return cpy_fs_handles[h - 1];
    }

    int64_t cpy_fs_open(const char* path, const char* mode) {
        FILE* f;
        int64_t id;
        if (path == NULL || *path == 0 || mode == NULL || *mode == 0) return (int64_t)-1;
        f = fopen(path, mode);
        if (f == NULL) return (int64_t)-2;
        id = cpy_fs_alloc_handle(f);
        if (id < 0) { fclose(f); return id; }
        return id;
    }

    int64_t cpy_fs_close(int64_t h) {
        FILE* f = cpy_fs_get_handle(h);
        if (f == NULL) return (int64_t)-1;
        cpy_fs_handle_used[h - 1] = 0;
        cpy_fs_handles[h - 1] = NULL;
        return (int64_t)fclose(f);
    }

    int64_t cpy_fs_read(int64_t h, void* dst, int64_t n) {
        FILE* f = cpy_fs_get_handle(h);
        size_t got;
        if (f == NULL || (n > 0 && dst == NULL) || n < 0) return (int64_t)-1;
        if (n == 0) return (int64_t)0;
        got = fread(dst, 1, (size_t)n, f);
        if (got == 0 && ferror(f)) return (int64_t)-2;
        return (int64_t)got;
    }

    int64_t cpy_fs_write(int64_t h, const void* src, int64_t n) {
        FILE* f = cpy_fs_get_handle(h);
        size_t wrote;
        if (f == NULL || (n > 0 && src == NULL) || n < 0) return (int64_t)-1;
        if (n == 0) return (int64_t)0;
        wrote = fwrite(src, 1, (size_t)n, f);
        if (wrote != (size_t)n) return (int64_t)-2;
        return (int64_t)wrote;
    }

    int64_t cpy_fs_tell(int64_t h) {
        FILE* f = cpy_fs_get_handle(h);
        long pos;
        if (f == NULL) return (int64_t)-1;
        pos = ftell(f);
        if (pos < 0) return (int64_t)-2;
        return (int64_t)pos;
    }

    int64_t cpy_fs_seek(int64_t h, int64_t offset, int whence) {
        FILE* f = cpy_fs_get_handle(h);
        int w;
        if (f == NULL) return (int64_t)-1;
        if (whence == 0) w = SEEK_SET;
        else if (whence == 1) w = SEEK_CUR;
        else if (whence == 2) w = SEEK_END;
        else return (int64_t)-2;
        return (int64_t)fseek(f, (long)offset, w);
    }

    int64_t cpy_fs_eof(int64_t h) {
        FILE* f = cpy_fs_get_handle(h);
        if (f == NULL) return (int64_t)1;
        return feof(f) ? (int64_t)1 : (int64_t)0;
    }

    int64_t cpy_fs_flush(int64_t h) {
        FILE* f = cpy_fs_get_handle(h);
        if (f == NULL) return (int64_t)-1;
        return (int64_t)fflush(f);
    }

    /* whole-file helpers (reuse cpy_fs_size) */
    int64_t cpy_fs_file_size2(const char* path) {
        return cpy_fs_size(path);
    }

    int64_t cpy_fs_read_file_all(const char* path, void* dst, int64_t cap) {
        FILE* f;
        size_t got;
        if (path == NULL || dst == NULL || cap < 0) return (int64_t)-1;
        f = fopen(path, "rb");
        if (f == NULL) return (int64_t)-2;
        got = fread(dst, 1, (size_t)cap, f);
        if (ferror(f)) { fclose(f); return (int64_t)-3; }
        fclose(f);
        return (int64_t)got;
    }

    int64_t cpy_fs_write_file_all(const char* path, const void* src, int64_t n) {
        FILE* f;
        size_t wrote;
        if (path == NULL || (n > 0 && src == NULL) || n < 0) return (int64_t)-1;
        f = fopen(path, "wb");
        if (f == NULL) return (int64_t)-2;
        wrote = fwrite(src, 1, (size_t)n, f);
        fclose(f);
        if (wrote != (size_t)n) return (int64_t)-3;
        return (int64_t)wrote;
    }

    int64_t cpy_fs_append_file_all(const char* path, const void* src, int64_t n) {
        FILE* f;
        size_t wrote;
        if (path == NULL || (n > 0 && src == NULL) || n < 0) return (int64_t)-1;
        f = fopen(path, "ab");
        if (f == NULL) return (int64_t)-2;
        wrote = fwrite(src, 1, (size_t)n, f);
        fclose(f);
        if (wrote != (size_t)n) return (int64_t)-3;
        return (int64_t)wrote;
    }

    /* ── mutations ────────────────────────────────────────────── */

    int64_t cpy_fs_remove(const char* path) {
        if (path == NULL || *path == 0) return (int64_t)-1;
        if (!cpy_fs_exists(path)) return (int64_t)-2;
        if (cpy_fs_is_dir(path)) {
            #ifdef _WIN32
                return (int64_t)_rmdir(path);
            #else
                return (int64_t)rmdir(path);
            #endif
        }
        return (int64_t)remove(path);
    }

    int64_t cpy_fs_remove_file(const char* path) {
        if (path == NULL || *path == 0) return (int64_t)-1;
        return (int64_t)remove(path);
    }

    int64_t cpy_fs_mkdir_one(const char* path) {
        if (path == NULL || *path == 0) return (int64_t)-1;
        #ifdef _WIN32
            return (int64_t)_mkdir(path);
        #else
            return (int64_t)mkdir(path, 0777);
        #endif
    }

    int64_t cpy_fs_rename(const char* from, const char* to) {
        if (from == NULL || to == NULL || *from == 0 || *to == 0) return (int64_t)-1;
        return (int64_t)rename(from, to);
    }

    /* Create `path` and every missing parent. 0 on success, negative on error.
       A path that already names a directory counts as success. */
    int64_t cpy_fs_mkdirs(const char* path) {
        char buf[CPY_FS_MAX];
        size_t i;
        size_t n;
        if (path == NULL || path[0] == 0) return (int64_t)-1;
        n = strlen(path);
        if (n >= sizeof(buf)) return (int64_t)-2;
        memcpy(buf, path, n + 1);
        while (n > 1 && (buf[n - 1] == '/' || buf[n - 1] == '\\')) {
            buf[--n] = 0;
        }
        if (n == 0) return (int64_t)-3;
        for (i = 1; i < n; i++) {
            char sep;
            if (buf[i] != '/' && buf[i] != '\\') continue;
            sep = buf[i];
            buf[i] = 0;
            if (!cpy_fs_exists(buf)) {
                if (cpy_fs_mkdir_one(buf) != 0 && !cpy_fs_is_dir(buf)) return (int64_t)-4;
            }
            buf[i] = sep;
        }
        if (!cpy_fs_is_dir(buf)) {
            if (cpy_fs_mkdir_one(buf) != 0 && !cpy_fs_is_dir(buf)) return (int64_t)-5;
        }
        return (int64_t)0;
    }

    /* Byte-exact copy. Returns bytes written, or a negative code. */
    int64_t cpy_fs_copy(const char* from, const char* to, int64_t overwrite) {
        char buf[8192];
        FILE* src;
        FILE* dst;
        size_t got;
        int64_t total = 0;
        if (from == NULL || to == NULL || *from == 0 || *to == 0) return (int64_t)-1;
        if (strcmp(from, to) == 0) return (int64_t)0;
        if (!overwrite && cpy_fs_exists(to)) return (int64_t)-3;
        if (cpy_fs_is_dir(from)) return (int64_t)-8;
        src = fopen(from, "rb");
        if (src == NULL) return (int64_t)-2;
        dst = fopen(to, "wb");
        if (dst == NULL) {
            fclose(src);
            return (int64_t)-4;
        }
        while ((got = fread(buf, 1, sizeof(buf), src)) > 0) {
            if (fwrite(buf, 1, got, dst) != got) {
                fclose(src);
                fclose(dst);
                return (int64_t)-5;
            }
            total += (int64_t)got;
        }
        if (ferror(src)) {
            fclose(src);
            fclose(dst);
            return (int64_t)-6;
        }
        fclose(src);
        if (fclose(dst) != 0) return (int64_t)-7;
        return total;
    }

    /* ── paths the OS knows about ─────────────────────────────── */

    /* Working directory into dst; byte length or -1. */
    int64_t cpy_fs_cwd(void* dst, int64_t cap) {
        #ifdef _WIN32
            char* p = _getcwd((char*)dst, (int)cap);
        #else
            char* p = getcwd((char*)dst, (size_t)cap);
        #endif
        if (p == NULL) return (int64_t)-1;
        return (int64_t)strlen(p);
    }

    /* OS temp directory into dst; byte length or -1 (never trailing slash). */
    int64_t cpy_fs_temp_dir(void* dst, int64_t cap) {
        const char* v;
        int64_t n;
        if (dst == NULL || cap <= 1) return (int64_t)-1;
        #ifdef _WIN32
            {
                DWORD got = GetTempPathA((DWORD)cap, (char*)dst);
                if (got == 0 || (int64_t)got >= cap) return (int64_t)-1;
            }
        #else
            v = getenv("TMPDIR");
            if (v == NULL || *v == 0) v = getenv("TMP");
            if (v == NULL || *v == 0) v = getenv("TEMP");
            if (v == NULL || *v == 0) v = "/tmp";
            if ((int64_t)strlen(v) >= cap) return (int64_t)-1;
            strcpy((char*)dst, v);
        #endif
        n = (int64_t)strlen((char*)dst);
        while (n > 1 && (((char*)dst)[n - 1] == '/' || ((char*)dst)[n - 1] == '\\')) {
            ((char*)dst)[--n] = 0;
        }
        return n;
    }

    /* Fully resolved absolute path (requires the path to exist on POSIX);
       byte length written into dst or -1. */
    int64_t cpy_fs_absolute(const char* path, void* dst, int64_t cap) {
        char tmp[CPY_FS_MAX];
        int64_t n;
        if (path == NULL || dst == NULL || cap <= 1 || *path == 0) return (int64_t)-1;
        #ifdef _WIN32
            {
                DWORD got = GetFullPathNameA(path, (DWORD)sizeof(tmp), tmp, NULL);
                if (got == 0 || (int64_t)got >= sizeof(tmp)) return (int64_t)-1;
            }
        #else
            if (realpath(path, tmp) == NULL) {
                /* Missing path: fall back to cwd-joining a lexical copy. */
                int64_t base;
                if (path[0] == '/') {
                    if ((int64_t)strlen(path) >= (int64_t)sizeof(tmp)) return (int64_t)-1;
                    strcpy(tmp, path);
                    base = (int64_t)strlen(tmp);
                } else {
                    base = cpy_fs_cwd(tmp, (int64_t)sizeof(tmp));
                    if (base < 0) return (int64_t)-1;
                    if (base + (int64_t)strlen(path) + 2 >= (int64_t)sizeof(tmp))
                        return (int64_t)-1;
                    tmp[base] = '/';
                    strcpy(tmp + base + 1, path);
                    base = (int64_t)strlen(tmp);
                }
                n = base;
            } else {
                n = (int64_t)strlen(tmp);
            }
        #endif
        if (n >= cap) return (int64_t)-1;
        memcpy(dst, tmp, (size_t)n + 1);
        return n;
    }

# ── existence + kind ────────────────────────────────────────────

public def fs_exists(path str) -> bool:
    return cpy_fs_exists(path) != (int64)0

public def fs_is_file(path str) -> bool:
    return cpy_fs_is_file(path) != (int64)0

public def fs_is_dir(path str) -> bool:
    return cpy_fs_is_dir(path) != (int64)0

# 0 when the path can be read.
public def fs_can_read(path str) -> int:
    return (int)cpy_fs_can_read(path)

# 0 when the path can be written.
public def fs_can_write(path str) -> int:
    return (int)cpy_fs_can_write(path)

# ── scalar metadata ─────────────────────────────────────────────

# Byte size; -1 when missing, -2 for a directory.
public def fs_size(path str) -> int64:
    return cpy_fs_size(path)

# Permission bits (st_mode & 07777); -1 when missing.
public def fs_mode(path str) -> int:
    return (int)cpy_fs_field(path, 0)

public def fs_mtime(path str) -> int64:
    return cpy_fs_field(path, 1)

public def fs_ctime(path str) -> int64:
    return cpy_fs_field(path, 2)

public def fs_atime(path str) -> int64:
    return cpy_fs_field(path, 3)

public def fs_inode(path str) -> int64:
    return cpy_fs_field(path, 4)

public def fs_nlink(path str) -> int64:
    return cpy_fs_field(path, 6)

# Permissions as an octal string, e.g. "644". "" when missing.
public def fs_mode_text(path str) -> str:
    char[] buf = new char[8]
    if cpy_fs_mode_text(path, (void*)buf) < (int64)0:
        return ""
    return (str)buf

# ── directory entries ───────────────────────────────────────────

# Entry names ("." and ".." included on POSIX). Empty array on error;
# use fs_is_dir to tell "empty directory" from "no such directory".
public def fs_list_dir(path str) -> str[]:
    str[] names = new str[0]
    int64 want = cpy_dir_count(path)
    if want < (int64)0:
        return names
    int64 i = (int64)0
    while i < want:
        append(names, "")
        i = i + (int64)1
    int64 bytes = cpy_dir_bytes(path)
    if bytes < (int64)1:
        return names
    char[] pool = new char[bytes + (int64)1]
    cpy_dir_fill(path, (void*)names, (void*)pool, bytes, want)
    return names

# Entry names without "." and "..".
public def fs_list_entries(path str) -> str[]:
    str[] all = fs_list_dir(path)
    str[] out = new str[0]
    int64 n = len(all)
    int64 i = (int64)0
    while i < n:
        if all[i] != "." and all[i] != "..":
            append(out, all[i])
        i = i + (int64)1
    return out

# ── mutations ───────────────────────────────────────────────────

# Remove a file or an empty directory. 0 on success.
public def fs_remove(path str) -> int:
    return (int)cpy_fs_remove(path)

public def fs_remove_file(path str) -> int:
    return (int)cpy_fs_remove_file(path)

# Create one directory (no parents). 0 on success.
public def fs_mkdir(path str) -> int:
    return cpy_fs_mkdir_one(path)

# Create a directory and every missing parent. 0 on success.
public def fs_mkdirs(path str) -> int:
    return cpy_fs_mkdirs(path)

public def fs_rename(from str, to str) -> int:
    return cpy_fs_rename(from, to)

# Byte-exact copy overwriting `to`; returns bytes written (negative on error).
public def fs_copy_file(from str, to str) -> int64:
    return cpy_fs_copy(from, to, (int64)1)

# Like fs_copy_file but refuses to clobber an existing destination.
public def fs_copy_file_no_overwrite(from str, to str) -> int64:
    return cpy_fs_copy(from, to, (int64)0)

# ── paths the OS knows about ────────────────────────────────────

public def fs_current_dir() -> str:
    char[] buf = new char[4096]
    if cpy_fs_cwd((void*)buf, (int64)4096) < (int64)0:
        return ""
    return (str)buf

public def fs_temp_dir() -> str:
    char[] buf = new char[4096]
    if cpy_fs_temp_dir((void*)buf, (int64)4096) < (int64)0:
        return ""
    return (str)buf

public def fs_absolute(path str) -> str:
    char[] buf = new char[4096]
    if cpy_fs_absolute(path, (void*)buf, (int64)4096) < (int64)0:
        return ""
    return (str)buf

# ── file handles + contents (stdio-backed) ─────────────────────
# Modes: "r","rb","w","wb","a","ab","r+","rb+",... passed to fopen.
# Handles are integer ids (>=1). Prefer "rb"/"wb"/"ab" for raw bytes.

public def fs_open(path str, mode str) -> int64:
    return cpy_fs_open(path, mode)

public def fs_close(h int64) -> int:
    return cpy_fs_close(h)

# Reads up to n bytes; returns a byte array of the bytes read (may be shorter at EOF).
public def fs_read(h int64, n int64) -> char[]:
    if n <= (int64)0:
        return new char[(int64)0]
    char[] buf = new char[n]
    int64 got = cpy_fs_read(h, (void*)buf, n)
    if got < (int64)0:
        return new char[(int64)0]
    if got == n:
        return buf
    char[] out = new char[got]
    int64 i = (int64)0
    while i < got:
        out[i] = buf[i]
        i = i + (int64)1
    return out

# Reads exactly n bytes or returns an empty array.
public def fs_read_exact(h int64, n int64) -> char[]:
    char[] buf = new char[n]
    if n <= (int64)0:
        return buf
    int64 got = cpy_fs_read(h, (void*)buf, n)
    if got != n:
        return new char[(int64)0]
    return buf

public def fs_write(h int64, data char[]) -> int64:
    return cpy_fs_write(h, (void*)data, len(data))

# Write a str as bytes (C string bytes up to NUL in practice for this form; prefer char[] for raw).
public def fs_write_str(h int64, s str) -> int64:
    # write the raw string bytes including no extra NUL handling beyond what caller wants
    return cpy_fs_write(h, (void*)s, (int64)len(s))

public def fs_tell(h int64) -> int64:
    return cpy_fs_tell(h)

# whence: 0=SEEK_SET, 1=SEEK_CUR, 2=SEEK_END
public def fs_seek(h int64, offset int64, whence int) -> int:
    return cpy_fs_seek(h, offset, whence)

public def fs_eof(h int64) -> bool:
    return cpy_fs_eof(h) != (int64)0

public def fs_flush(h int64) -> int:
    return cpy_fs_flush(h)

# Whole-file helpers (binary by default via C).
public def fs_read_all(path str) -> char[]:
    int64 cap = cpy_fs_file_size2(path)
    if cap < (int64)0:
        return new char[(int64)0]
    char[] buf = new char[cap]
    int64 got = cpy_fs_read_file_all(path, (void*)buf, cap)
    if got < (int64)0:
        return new char[(int64)0]
    if got == cap:
        return buf
    char[] out = new char[got]
    int64 i = (int64)0
    while i < got:
        out[i] = buf[i]
        i = i + (int64)1
    return out

public def fs_write_all(path str, data char[]) -> int64:
    return cpy_fs_write_file_all(path, (void*)data, len(data))

public def fs_write_all_str(path str, s str) -> int64:
    return cpy_fs_write_file_all(path, (void*)s, (int64)len(s))

public def fs_append_all(path str, data char[]) -> int64:
    return cpy_fs_append_file_all(path, (void*)data, len(data))

public def fs_append_all_str(path str, s str) -> int64:
    return cpy_fs_append_file_all(path, (void*)s, (int64)len(s))
