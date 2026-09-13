# Dies Das Ananas

Shared build artifacts and utilities used by the Safrano images.

## Reusable Python wheels

JUGO's Google Cloud TTS client depends on `grpcio`. Fedora 45 currently uses
Python 3.15, for which grpcio 1.83.1 has no upstream binary wheel. Compiling it
inside every Safrano image build previously took roughly 22 minutes.

`python-wheels/grpcio.json` pins the package version, Python ABI, Fedora version,
architecture and release tag. The `Reusable Python wheels` workflow builds that
wheel once in Fedora 45, verifies that it can be imported, and publishes it with
a SHA-256 manifest. A repeat workflow run reuses the existing release.

The workflow source lives in `SCRIPTS/githubactions/DIESDAS-/workflows/` and is
published through `fire.sh`.

To create a wheel for a new package version or target platform, update the
specification with a new release tag and dispatch `python-wheels.yml`. Existing
release assets are never overwritten by the workflow.
