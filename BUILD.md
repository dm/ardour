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
make build         # Build only
make clean         # Clean build artifacts
make check-deps    # Verify dependencies installed
```

## Run Ardour

After building:

```bash
./build/gtk2_ardour/ardour-9.0.rc4.4
```

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

### 4. Include Path Fix

Fixed incorrect glibmm include paths in `libs/surfaces/console1/c1_plugin_operations.cc`:

```cpp
// Changed from:
#include "glibmm-2.4/glibmm/main.h"

// To:
#include "glibmm/main.h"
```

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
**Last Updated:** 2026-01-28
