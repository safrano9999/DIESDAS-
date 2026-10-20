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
