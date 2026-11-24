"""Build hook to provide OpenSSL include/lib flags for cryptography ccode."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
from cpyte.extension_hooks import BuildHook, HookMetadata


def _find_openssl_include() -> str | None:
    inc = os.environ.get("CPYTE_OPENSSL_INCLUDE")
    if inc and os.path.isdir(inc):
        return inc
    # pkg-config
    try:
        r = subprocess.run(
            ["pkg-config", "--cflags-only-I", "openssl"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            for f in (r.stdout or "").strip().split():
                if f.startswith("-I") and len(f) > 2:
                    p = f[2:]
                    if os.path.isdir(p):
                        return p
        r2 = subprocess.run(
            ["pkg-config", "--variable=includedir", "openssl"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r2.returncode == 0:
            p = (r2.stdout or "").strip()
            if p and os.path.isdir(p):
                return p
    except Exception:
        pass
    # Homebrew
    if shutil.which("brew"):
        try:
            for name in ("openssl@3", "openssl"):
                r = subprocess.run(
                    ["brew", "--prefix", name],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if r.returncode == 0:
                    prefix = r.stdout.strip()
                    incd = os.path.join(prefix, "include")
                    if os.path.isdir(incd) and os.path.isfile(os.path.join(incd, "openssl", "evp.h")):
                        return incd
        except Exception:
            pass
    # Common paths (macOS/Linux)
    system = platform.system().lower()
    candidates = []
    if system == "darwin":
        candidates.extend([
            "/opt/homebrew/opt/openssl@3/include",
            "/usr/local/opt/openssl@3/include",
            "/opt/homebrew/opt/openssl/include",
            "/usr/local/opt/openssl/include",
        ])
    for c in candidates:
        if os.path.isdir(c) and os.path.isfile(os.path.join(c, "openssl", "evp.h")):
            return c
    # System
    for c in ["/usr/include", "/usr/local/include"]:
        if os.path.isfile(os.path.join(c, "openssl", "evp.h")):
            return c
    return None


def _find_openssl_libdir() -> str | None:
    libdir = os.environ.get("CPYTE_OPENSSL_LIBDIR") or os.environ.get("CPYTE_OPENSSL_LIB")
    if libdir and os.path.isdir(libdir):
        return libdir
    try:
        r = subprocess.run(
            ["pkg-config", "--libs-only-L", "openssl"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            for f in (r.stdout or "").strip().split():
                if f.startswith("-L") and len(f) > 2:
                    p = f[2:]
                    if os.path.isdir(p):
                        return p
        r2 = subprocess.run(
            ["pkg-config", "--variable=libdir", "openssl"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r2.returncode == 0:
            p = (r2.stdout or "").strip()
            if p and os.path.isdir(p):
                return p
    except Exception:
        pass
    if shutil.which("brew"):
        try:
            for name in ("openssl@3", "openssl"):
                r = subprocess.run(
                    ["brew", "--prefix", name],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if r.returncode == 0:
                    prefix = r.stdout.strip()
                    libd = os.path.join(prefix, "lib")
                    if os.path.isdir(libd):
                        return libd
        except Exception:
            pass
    system = platform.system().lower()
    if system == "darwin":
        for prefix in ["/opt/homebrew/opt/openssl@3", "/usr/local/opt/openssl@3",
                       "/opt/homebrew/opt/openssl", "/usr/local/opt/openssl"]:
            libd = os.path.join(prefix, "lib")
            if os.path.isdir(libd):
                return libd
    for libd in ["/usr/lib/x86_64-linux-gnu", "/usr/lib64", "/usr/lib", "/usr/local/lib"]:
        if os.path.isdir(libd):
            # Heuristic: if libssl exists
            for name in ("libssl.so", "libssl.dylib", "libssl.a", "libssl.dll.a"):
                if os.path.exists(os.path.join(libd, name)):
                    return libd
    # Fallback: common
    for libd in ["/usr/lib", "/usr/local/lib"]:
        if os.path.isdir(libd):
            return libd
    return None


class OpenSSLBuildHook(BuildHook):
    def __init__(self):
        super().__init__(
            "cryptography",
            metadata=HookMetadata(
                name="cryptography:openssl", version="1.0.1", priority=10
            ),
        )

    def get_include_paths(self, context):
        inc = _find_openssl_include()
        if inc:
            return [inc]
        return []

    def get_library_paths(self, context):
        libdir = _find_openssl_libdir()
        if libdir:
            return [libdir]
        return []

    def get_libraries(self, context):
        # Do not add libs on Windows MSVC toolchain in the same way? But we need cross-platform.
        # OpenSSL typically links as ssl, crypto (or libssl/libcrypto). On Windows with MinGW, -lssl -lcrypto
        # On Windows MSVC, names differ, but our toolchain uses clang+linker; keeping simple for now.
        return ["ssl", "crypto"]

    def get_defines(self, context):
        return {}


def get_hooks():
    return [OpenSSLBuildHook()]
