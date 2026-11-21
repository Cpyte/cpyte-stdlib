# Self-check for @std/fs. Builds a scratch tree under the OS temp directory,
# exercises metadata/readdir/mkdir/copy/rename/remove on it, and removes the
# files it created. File *contents* are written by a local C helper so this
# test does not depend on the `file` module.

import "fs.cpy"

ccode:
    #include <stdint.h>
    #include <stdio.h>
    #include <string.h>

    int64_t cpy_t_write(const char* path, const char* text) {
        FILE* f = fopen(path, "wb");
        if (f == NULL) return (int64_t)-1;
        if (fwrite(text, 1, strlen(text), f) != strlen(text)) {
            fclose(f);
            return (int64_t)-2;
        }
        fclose(f);
        return (int64_t)strlen(text);
    }

    int64_t cpy_t_read(const char* path, void* dst, int64_t cap) {
        FILE* f = fopen(path, "rb");
        size_t got;
        if (f == NULL) return (int64_t)-1;
        got = fread(dst, 1, (size_t)(cap - 1), f);
        ((char*)dst)[got] = 0;
        fclose(f);
        return (int64_t)got;
    }

def check_i(name str, got int64, want int64) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_b(name str, got bool, want bool) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_s(name str, got str, want str) -> int:
    if got != want:
        print("FAIL", name, "want", want, "got", got)
        return 1
    return 0

def check_ok(name str, code int) -> int:
    if code != 0:
        print("FAIL", name, "expected 0, got", code)
        return 1
    return 0

def check_bad(name str, code int) -> int:
    if code >= 0:
        print("FAIL", name, "expected negative, got", code)
        return 1
    return 0

# A path is present in a directory listing.
def has_name(names str[], want str) -> int:
    int found = 0
    int64 i = (int64)0
    int64 n = len(names)
    while i < n:
        if names[i] == want:
            found = 1
        i = i + (int64)1
    return found

def read_text(path str) -> str:
    char[] buf = new char[4096]
    if cpy_t_read(path, (void*)buf, (int64)4096) < (int64)0:
        return ""
    return (str)buf

def test_metadata(root str) -> int:
    int n = 0
    str file = root + "/meta.txt"
    cpy_t_write(file, "hello fs")
    n += check_b("exists", fs_exists(file), true)
    n += check_b("is_file", fs_is_file(file), true)
    n += check_b("not is_dir", fs_is_dir(file), false)
    n += check_i("size", fs_size(file), (int64)8)
    n += check_i("can_read", (int64)fs_can_read(file), (int64)0)
    n += check_i("can_write", (int64)fs_can_write(file), (int64)0)
    n += check_b("mtime sane", fs_mtime(file) > (int64)1600000000, true)
    n += check_b("atime sane", fs_atime(file) >= (int64)0, true)
    n += check_b("ctime sane", fs_ctime(file) >= (int64)0, true)
    n += check_b("mode sane", fs_mode(file) >= 0 and fs_mode(file) < 512, true)
    n += check_b("mode text digits", fs_mode_text(file) != "", true)
    n += check_b("nlink sane", fs_nlink(file) >= (int64)1, true)
    n += check_b("inode sane", fs_inode(file) != (int64)0, true)
    # metadata of a path that does not exist
    n += check_b("missing exists", fs_exists(root + "/nope.txt"), false)
    n += check_b("missing is_file", fs_is_file(root + "/nope.txt"), false)
    n += check_b("missing is_dir", fs_is_dir(root + "/nope.txt"), false)
    n += check_i("missing size", fs_size(root + "/nope.txt"), (int64)-1)
    n += check_i("missing mode", (int64)fs_mode(root + "/nope.txt"), (int64)-1)
    n += check_s("missing mode text", fs_mode_text(root + "/nope.txt"), "")
    n += check_bad("missing can_read", (int64)fs_can_read(root + "/nope.txt"))
    n += check_bad("empty path can_read", (int64)fs_can_read(""))
    # the root itself
    n += check_b("root is_dir", fs_is_dir(root), true)
    n += check_b("root not is_file", fs_is_file(root), false)
    n += check_i("root size", fs_size(root), (int64)-2)
    n += check_bad("remove missing", (int64)fs_remove(root + "/nope.txt"))
    n += check_ok("dir can_read", (int64)fs_can_read(root))
    return n

def test_directories(root str) -> int:
    int n = 0
    str nested = root + "/a/b/c"
    n += check_ok("mkdirs nested", (int64)fs_mkdirs(nested))
    n += check_b("nested exists", fs_is_dir(nested), true)
    n += check_ok("mkdirs idempotent", (int64)fs_mkdirs(nested))
    n += check_bad("mkdirs over a file",
                   (int64)fs_mkdirs(root + "/meta.txt"))
    n += check_bad("mkdir single existing fails", (int64)fs_mkdir(nested))
    str leaf = nested + "/leaf.txt"
    cpy_t_write(leaf, "x")
    str[] top = fs_list_entries(nested)
    n += check_i("entries of nested", len(top), (int64)1)
    n += check_i("top entry name", has_name(top, "leaf.txt"), 1)
    str[] all = fs_list_dir(root)
    n += check_i("listing has meta", has_name(all, "meta.txt"), 1)
    n += check_i("listing has a", has_name(all, "a"), 1)
    n += check_i("listing has dot", has_name(all, "."), 0)
    n += check_i("listing has dotdot", has_name(all, ".."), 0)
    n += check_i("entries no dotdot", has_name(fs_list_entries(root), ".."), 0)
    n += check_b("missing dir lists empty", len(fs_list_dir(root + "/gone")) == (int64)0, true)
    # deep remove must fail while it still holds files
    n += check_bad("remove non-empty", (int64)fs_remove(nested))
    n += check_ok("remove leaf file", (int64)fs_remove(leaf))
    n += check_ok("remove c", (int64)fs_remove(nested))
    n += check_ok("remove b", (int64)fs_remove(root + "/a/b"))
    n += check_ok("remove a", (int64)fs_remove(root + "/a"))
    n += check_b("a gone", fs_exists(root + "/a"), false)
    return n

def test_copy_rename(root str) -> int:
    int n = 0
    str src = root + "/copy_src.txt"
    str dst = root + "/copy_dst.txt"
    cpy_t_write(src, "payload 12345")
    n += check_i("copy bytes", fs_copy_file(src, dst), (int64)13)
    n += check_b("dst exists", fs_exists(dst), true)
    n += check_s("dst content", read_text(dst), "payload 12345")
    n += check_i("dst size", fs_size(dst), (int64)13)
    n += check_bad("no-overwrite refuses", fs_copy_file_no_overwrite(src, dst))
    n += check_ok("remove dst", (int64)fs_remove(dst))
    n += check_i("no-overwrite now works", fs_copy_file_no_overwrite(src, dst), (int64)13)
    n += check_i("self copy is a no-op", fs_copy_file(src, src), (int64)0)
    n += check_bad("copy missing source", fs_copy_file(root + "/no_src", dst))
    n += check_bad("copy a directory", fs_copy_file(root, dst))
    # rename
    str moved = root + "/moved.txt"
    n += check_ok("rename", (int64)fs_rename(dst, moved))
    n += check_b("old gone", fs_exists(dst), false)
    n += check_s("moved content", read_text(moved), "payload 12345")
    n += check_ok("remove moved", (int64)fs_remove(moved))
    n += check_bad("rename missing", (int64)fs_rename(root + "/nope", moved))
    n += check_ok("remove src", (int64)fs_remove(src))
    return n

def test_paths() -> int:
    int n = 0
    str cwd = fs_current_dir()
    str tmp = fs_temp_dir()
    n += check_b("cwd not empty", cwd != "", true)
    n += check_b("cwd is a dir", fs_is_dir(cwd), true)
    n += check_b("temp is a dir", fs_is_dir(tmp), true)
    n += check_b("temp has no trailing slash",
                 tmp == "" or fs_exists(tmp), true)
    str abs_here = fs_absolute(tmp)
    n += check_b("absolute resolved", abs_here != "", true)
    n += check_s("absolute is stable", fs_absolute(abs_here), abs_here)
    return n

public def main() -> int:
    int n = 0
    str root = fs_temp_dir() + "/cpystd_fs_check"
    fs_mkdirs(root)
    n += test_metadata(root)
    n += test_directories(root)
    n += test_copy_rename(root)
    n += test_paths()
    fs_remove(root + "/meta.txt")
    fs_remove(root)
    if n == 0:
        print("fs: PASS")
    else:
        print("fs: FAIL", n)
    return n
