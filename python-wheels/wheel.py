#!/usr/bin/env python3
"""Build once, publish a versioned wheel, then consume it without compilation."""
from __future__ import annotations

import hashlib
import importlib.metadata
import json
import os
import platform
import subprocess
import sys
from pathlib import Path

SPEC = json.loads((Path(__file__).with_name("grpcio.json")).read_text())
FILENAME = "{package}-{version}-{python_tag}-{abi_tag}-{platform_tag}.whl".format(**SPEC)


def command(*args: str) -> None:
    subprocess.run(args, check=True)


def compatible() -> None:
    actual = {
        "fedora": platform.freedesktop_os_release().get("VERSION_ID"),
        "python_tag": f"cp{sys.version_info.major}{sys.version_info.minor}",
        "abi_tag": f"cp{sys.version_info.major}{sys.version_info.minor}{sys.abiflags}",
        "platform_tag": f"linux_{platform.machine()}",
    }
    if sys.implementation.name != "cpython" or any(actual[k] != SPEC[k] for k in actual):
        raise RuntimeError(f"Wheel target does not match this interpreter/platform: {actual}")


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify(directory: Path) -> Path:
    manifest = json.loads((directory / "manifest.json").read_text())
    for key in ("package", "version", "fedora", "python_tag", "abi_tag", "platform_tag", "release"):
        if manifest.get(key) != SPEC[key]:
            raise RuntimeError(f"Wheel manifest differs from the pinned specification: {key}")
    wheel = directory / FILENAME
    if manifest.get("filename") != FILENAME or digest(wheel) != manifest.get("sha256"):
        raise RuntimeError("Wheel filename or SHA-256 verification failed")
    return wheel


def build(directory: Path) -> None:
    compatible()
    directory.mkdir(parents=True, exist_ok=True)
    if list(directory.iterdir()):
        raise RuntimeError("Build output directory must be empty")
    command(sys.executable, "-m", "pip", "wheel", "--no-deps", "--no-binary=grpcio",
            "--wheel-dir", str(directory), f"{SPEC['package']}=={SPEC['version']}")
    wheel = directory / FILENAME
    if not wheel.is_file():
        raise RuntimeError(f"Build did not produce the expected wheel: {FILENAME}")
    command(sys.executable, "-m", "pip", "install", "--no-index", "--no-deps", str(wheel))
    command(sys.executable, "-c", f"import grpc; assert grpc.__version__ == {SPEC['version']!r}")
    manifest = dict(SPEC, filename=FILENAME, sha256=digest(wheel), python=sys.version,
                    source_commit=os.environ.get("GITHUB_SHA", ""))
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    verify(directory)


def fetch(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    if (directory / "manifest.json").exists() and (directory / FILENAME).exists():
        verify(directory)
        print(f"DIESDAS: verified cached {FILENAME}")
        return
    command("gh", "release", "download", SPEC["release"], "--repo", SPEC["repository"],
            "--pattern", FILENAME, "--pattern", "manifest.json", "--dir", str(directory), "--clobber")
    verify(directory)
    print(f"DIESDAS: downloaded and verified {FILENAME}")


def install(directory: Path) -> None:
    compatible()
    try:
        installed = importlib.metadata.version(SPEC["package"])
    except importlib.metadata.PackageNotFoundError:
        installed = None
    if installed == SPEC["version"]:
        print(f"DIESDAS: reusing installed {SPEC['package']} {installed}")
        return
    wheel = verify(directory)
    command(sys.executable, "-m", "pip", "install", "--no-index", "--no-deps",
            "--only-binary=:all:", str(wheel))
    command(sys.executable, "-c", f"import grpc; assert grpc.__version__ == {SPEC['version']!r}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in {"build", "fetch", "install", "verify"}:
        raise SystemExit("Usage: wheel.py build|fetch|install|verify DIRECTORY")
    globals()[sys.argv[1]](Path(sys.argv[2]).resolve())
