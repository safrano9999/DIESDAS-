# Dies Das Ananas

Shared dependencies and utilities used by the Safrano images.

## Fedora image integration

JUGO's Google Cloud TTS client depends on `grpcio`. PyPI provides upstream
grpcio 1.84.0 wheels for CPython 3.15 on Linux x86_64.

DIESDAS contributes `requirements.txt` to the Base layer's normal dependency
installation. Pip installs grpcio 1.84.0 or newer from PyPI together with its
dependencies, including `typing_extensions`. The binary-only requirement for
grpcio prevents an unexpected source compilation during an image build.
Later layers reuse the installed package.

No separate wheel build, GitHub release download, or host/container build hook
is required. Image builds and their validation run on GitHub Actions.

## ARM64 toolchains

This repository also contains ARM64 build definitions for runtime components
that are not distributed as Linux ARM64 binaries upstream.

The `Build ARM64 toolchains` workflow builds Electrum and Agave/Solana on a
GitHub-hosted `ubuntu-24.04-arm` runner. It publishes versioned tarballs,
SHA-256 checksums, and a manifest. The Fedora ARM64 image consumes those
release assets by exact version and checksum; it does not build either
component during the image build.

The generated bundles are Linux ARM64 artifacts and are separate from the
native macOS Apple-Silicon builds.
