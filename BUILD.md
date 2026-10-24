# Building Ardour on macOS ARM64

## Quick Start

```bash
make full
```

This will create the Python venv, install dependencies, configure, and build Ardour (~3 minutes).

## Prerequisites

- macOS ARM64 (Apple Silicon)
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew: https://brew.sh
- uv: `brew install uv`

## Common Commands

```bash
make help          # Show all available commands
make full          # Complete build from scratch
make rebuild       # Clean and rebuild
make configure     # Configure only
make build         # Build (configures first if needed)
make clean         # Clean build artifacts and the .app bundle
make run           # Run Ardour from the build tree
make app           # Package a self-contained build/Ardour9.app
make run-app       # Launch build/Ardour9.app
make check-deps    # Verify dependencies installed
```

## Run Ardour

From the build tree:

```bash
make run
```

## macOS App Bundle

```bash
make app
```

Produces `build/Ardour9.app` with all Homebrew libraries bundled and ad-hoc signed, so it can be
copied to `/Applications` and run on this machine. It reuses `tools/osx_packaging/osx_build`
with `--nodmg`, which stops before downloading extra plugins/video tools and building a DMG.
A debug build (the default `make configure`) produces a large (~1.4 GB) unstripped bundle.

## macOS-Specific Fixes Applied

### 1. GCC Alias Attributes Not Supported

Clang on macOS doesn't support GCC's `__attribute__((alias(...)))`.

**Solution:** Added `DISABLE_VISIBILITY` define in:
- `libs/tk/ydk/wscript`
- `libs/tk/ytk/wscript`

```python
if sys.platform == 'darwin':
    obj.defines += ['DISABLE_VISIBILITY']
```

### 2. glibmm Version Compatibility

Ardour requires glibmm-2.4, but modern Homebrew provides glibmm-2.68.

**Solution:** Use glibmm@2.66 (provides glibmm-2.4 compatibility):
```bash
brew unlink glibmm || true
brew install glibmm@2.66
brew link glibmm@2.66
```

### 3. Keg-Only Libraries

Several libraries (libarchive, raptor) are keg-only and need explicit paths.

**Solution:** Makefile sets `PKG_CONFIG_PATH`, `CPPFLAGS`, and `LDFLAGS` automatically.

### 4. Legacy C++ Bindings

Ardour needs `cairomm-1.0` and `pangomm-1.4`, but Homebrew's `cairomm`/`pangomm` are the newer
1.16/2.48 APIs.

**Solution:** `make deps` installs `cairomm@1.14` and `pangomm@2.46`.

### 5. `@rpath` Dependencies in App Bundle

Some Homebrew libraries (e.g. brotli) reference dependencies via `@rpath/`, which the upstream
bundler did not follow. `tools/osx_packaging/osx_build` now copies those from the stack's `lib/`.

## Troubleshooting

### Build fails

```bash
make distclean     # Complete clean
make check-deps    # Verify dependencies
make full          # Rebuild from scratch
```

### Python not found

Ensure virtual environment is created:
```bash
make venv
```

### Missing headers/libraries

Install dependencies:
```bash
make deps
```

## Notes

- Build uses `uv` for fast Python environment management
- Makefile handles all environment variables automatically
- Linker warnings about dylib versions are normal and can be ignored
- Build time: ~3 minutes on Apple Silicon

---

**Version:** Ardour 9.x
**Last Updated:** 2026-10-24
