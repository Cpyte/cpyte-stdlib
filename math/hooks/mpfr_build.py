"""Build hook exposing MPFR include/lib paths to @std/math's constants.cpy."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess

from cpyte.extension_hooks import BuildHook, HookMetadata


def _find_mpfr_include() -> str | None:
    inc = os.environ.get("CPYTE_MPFR_INCLUDE")
    if inc and os.path.isfile(os.path.join(inc, "mpfr.h")):
        return inc
    try:
        r = subprocess.run(
            ["pkg-config", "--cflags-only-I", "mpfr"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            for flag in (r.stdout or "").strip().split():
                if flag.startswith("-I") and len(flag) > 2:
                    path = flag[2:]
                    if os.path.isfile(os.path.join(path, "mpfr.h")):
                        return path
    except Exception:
        pass
    if shutil.which("brew"):
        try:
            r = subprocess.run(
                ["brew", "--prefix", "mpfr"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0:
                path = os.path.join(r.stdout.strip(), "include")
                if os.path.isfile(os.path.join(path, "mpfr.h")):
                    return path
        except Exception:
            pass
    candidates = ["/usr/include", "/usr/local/include"]
    if platform.system().lower() == "darwin":
        candidates = [
            "/opt/homebrew/opt/mpfr/include",
            "/usr/local/opt/mpfr/include",
        ] + candidates
    for path in candidates:
        if os.path.isfile(os.path.join(path, "mpfr.h")):
            return path
    return None


def _find_gmp_include() -> str | None:
    inc = os.environ.get("CPYTE_GMP_INCLUDE")
    if inc and os.path.isfile(os.path.join(inc, "gmp.h")):
        return inc
    try:
        r = subprocess.run(
            ["pkg-config", "--cflags-only-I", "gmp"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            for flag in (r.stdout or "").strip().split():
                if flag.startswith("-I") and len(flag) > 2:
                    path = flag[2:]
                    if os.path.isfile(os.path.join(path, "gmp.h")):
                        return path
    except Exception:
        pass
    if shutil.which("brew"):
        try:
            r = subprocess.run(
                ["brew", "--prefix", "gmp"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0:
                path = os.path.join(r.stdout.strip(), "include")
                if os.path.isfile(os.path.join(path, "gmp.h")):
                    return path
        except Exception:
            pass
    candidates = ["/usr/include", "/usr/local/include"]
    if platform.system().lower() == "darwin":
        candidates = [
            "/opt/homebrew/opt/gmp/include",
            "/usr/local/opt/gmp/include",
        ] + candidates
    for path in candidates:
        if os.path.isfile(os.path.join(path, "gmp.h")):
            return path
    return None


def _find_mpfr_libdir() -> str | None:
    libdir = os.environ.get("CPYTE_MPFR_LIBDIR")
    if libdir and os.path.isdir(libdir):
        return libdir
    try:
        r = subprocess.run(
            ["pkg-config", "--libs-only-L", "mpfr"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            for flag in (r.stdout or "").strip().split():
                if flag.startswith("-L") and len(flag) > 2:
                    path = flag[2:]
                    if os.path.isdir(path):
                        return path
    except Exception:
        pass
    if platform.system().lower() == "darwin" and shutil.which("brew"):
        try:
            r = subprocess.run(
                ["brew", "--prefix", "mpfr"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0:
                path = os.path.join(r.stdout.strip(), "lib")
                if os.path.isdir(path):
                    return path
        except Exception:
            pass
    for path in ["/usr/lib", "/usr/local/lib", "/usr/lib64", "/usr/lib/x86_64-linux-gnu"]:
        if os.path.isdir(path):
            return path
    return None


class MPFRBuildHook(BuildHook):
    def __init__(self):
        super().__init__(
            "math",
            metadata=HookMetadata(
                name="math:mpfr", version="1.0.6", priority=10
            ),
        )

    def get_include_paths(self, context):
        paths = []
        for inc in (_find_mpfr_include(), _find_gmp_include()):
            if inc and inc not in paths:
                paths.append(inc)
        return paths

    def get_library_paths(self, context):
        libdir = _find_mpfr_libdir()
        return [libdir] if libdir else []

    def get_libraries(self, context):
        return ["mpfr"]

    def get_defines(self, context):
        return {}


def get_hooks():
    return [MPFRBuildHook()]
