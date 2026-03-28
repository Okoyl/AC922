# Building MLC LLM from Source on ppc64le (IBM AC922)

Tested on:

- **Hardware**: IBM AC922 POWER9 NVLinik with 4x NVIDIA V100-SXM2-16GB GPUs
- **OS**: RHEL 8 / AlmaLinux 8 (ppc64le)
- **CUDA**: 12.4
- **Python**: 3.12
- **GCC**: 12.x (Red Hat gcc-toolset-12)
- **LLVM**: 20 (RHEL 8)

## Prerequisites

### System Packages

```bash
# GCC toolset (CUDA 12.4 supports up to GCC 13; GCC 12 is recommended)
sudo dnf install -y gcc-toolset-12

# LLVM development packages (for TVM's LLVM codegen backend)
# Ensure llvm-config is in PATH

# Rust/Cargo (for tokenizer builds)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

### Important: GCC Version on RHEL 8

RHEL 8 ships GCC 8.5, which is too old for both CUDA (needs >= 9) and NumPy (needs >= 9.3).
CUDA 12.4 does **not** support GCC >= 14, so use **gcc-toolset-12** (GCC 12) for everything.

> **Warning:** Using gcc-toolset-13 or gcc-toolset-14 with nvcc will fail:
> `error: unsupported GNU version! gcc versions later than 13 are not supported!`

### GPU Compute Capability

V100 = compute capability **7.0**.

## Step 1: Create Python venv and Install Dependencies

```bash
source /opt/rh/gcc-toolset-12/enable   # IMPORTANT: always enable before any build step

mkdir -p ~/Projects/mlc_llm && cd ~/Projects/mlc_llm
python3.12 -m venv venv
source venv/bin/activate

pip install --upgrade pip setuptools wheel
pip install cmake ninja numpy decorator attrs typing-extensions psutil scipy
pip install scikit-build-core setuptools-scm cython   # needed for TVM/tvm-ffi Python packages
```

> **Note:** NumPy and SciPy have no prebuilt ppc64le wheels and will compile from source.

## Step 2: Clone MLC LLM

MLC LLM includes TVM as a git submodule in `3rdparty/tvm` — no need to clone TVM separately.

```bash
cd ~/Projects/mlc_llm
git clone --recursive https://github.com/mlc-ai/mlc-llm.git
cd mlc-llm
```

## Step 3: Apply ppc64le Patches

### 3a. Enable full TVM build (not dummy/runtime-only)

MLC LLM defaults to `BUILD_DUMMY_LIBTVM ON`, which builds only TVM's runtime.
The TVM Python package requires the full compiler. Edit `CMakeLists.txt` line 58:

```diff
- set(BUILD_DUMMY_LIBTVM ON)
+ if(NOT DEFINED BUILD_DUMMY_LIBTVM)
+   set(BUILD_DUMMY_LIBTVM ON)
+ endif()
```

### 3b. Fix libstdc++_nonshared linking (RHEL gcc-toolset ABI gap)

On RHEL 8, gcc-toolset splits libstdc++ into the system `libstdc++.so.6` (GCC 8) plus
`libstdc++_nonshared.a` (newer symbols). This static archive must be explicitly linked
into shared libraries, or you'll get `undefined symbol: _ZNSt7__cxx1119basic_ostringstream...`
at runtime.

Edit `3rdparty/tvm/CMakeLists.txt` — after the `target_link_libraries(tvm_runtime ...)` lines
(around line 555), add:

```cmake
# On RHEL/CentOS with gcc-toolset, newer C++ symbols live in libstdc++_nonshared.a
# which must be explicitly linked into shared libraries.
execute_process(
  COMMAND ${CMAKE_CXX_COMPILER} -print-file-name=libstdc++_nonshared.a
  OUTPUT_VARIABLE STDCXX_NONSHARED
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(STDCXX_NONSHARED AND NOT STDCXX_NONSHARED STREQUAL "libstdc++_nonshared.a")
  message(STATUS "Found libstdc++_nonshared: ${STDCXX_NONSHARED}")
  target_link_libraries(tvm PRIVATE ${STDCXX_NONSHARED})
  target_link_libraries(tvm_runtime PRIVATE ${STDCXX_NONSHARED})
endif()
```

### 3c. Comment out unavailable Python deps

Edit `python/requirements.txt` — comment out packages unavailable on ppc64le:

```diff
- torch
+ # torch  # not available on ppc64le via pip; install separately if needed
- flashinfer-python
+ # flashinfer-python  # not available on ppc64le; skip
- datasets
+ # datasets  # requires pyarrow (hard to build on ppc64le); install separately if needed
```

## Step 4: Configure and Build

```bash
source /opt/rh/gcc-toolset-12/enable
source ~/Projects/mlc_llm/venv/bin/activate

mkdir -p build && cd build

cat > config.cmake << 'EOF'
set(TVM_SOURCE_DIR 3rdparty/tvm)
set(CMAKE_BUILD_TYPE RelWithDebInfo)
set(USE_CUDA ON)
set(CMAKE_CUDA_ARCHITECTURES 70)
set(USE_CUBLAS ON)
set(USE_CUTLASS ON)
set(USE_THRUST ON)
set(USE_NVTX ON)
set(USE_LLVM "llvm-config")
set(HIDE_PRIVATE_SYMBOLS OFF)
set(USE_ALTERNATIVE_LINKER OFF)
set(BUILD_DUMMY_LIBTVM OFF)
EOF

cmake ..
make -j80   # adjust parallelism to your system
```

> **Notes:**
> - If CUTLASS fails to build on ppc64le, set `USE_CUTLASS OFF`.
> - If LLVM is not available, set `USE_LLVM OFF`.
> - `USE_ALTERNATIVE_LINKER OFF` prevents cmake from auto-selecting `lld` (from LLVM),
>   which can cause ABI issues with gcc-toolset on ppc64le.
> - `HIDE_PRIVATE_SYMBOLS OFF` avoids `--exclude-libs,ALL` which strips needed
>   `libstdc++_nonshared.a` symbols.

### Post-build: Fix stdc++_nonshared symbols

Even with the cmake patch above, the static archive symbols may not survive linking
(GNU ld processes archives lazily). Re-link with `--whole-archive` to force inclusion:

```bash
cd tvm

# Re-link libtvm.so
sed 's|libstdc++_nonshared.a|-Wl,--whole-archive & -Wl,--no-whole-archive|' \
  CMakeFiles/tvm.dir/link.txt | bash

# Re-link libtvm_runtime.so
sed 's|libstdc++_nonshared.a|-Wl,--whole-archive & -Wl,--no-whole-archive|' \
  CMakeFiles/tvm_runtime.dir/link.txt | bash

cd ..
```

Verify the fix worked:

```bash
nm -D tvm/libtvm.so | grep "_ZNSt7__cxx1119basic_ostringstreamIcSt11char_traitsIcESaIcEEC1Ev"
# Should show "W" (weak/defined), NOT "U" (undefined)
```

### Symlink TVM libraries for Python

TVM's Python package looks for `libtvm.so` in `3rdparty/tvm/build/`:

```bash
cd ..  # back to mlc-llm root
mkdir -p 3rdparty/tvm/build
ln -sf $(pwd)/build/tvm/libtvm.so 3rdparty/tvm/build/libtvm.so
ln -sf $(pwd)/build/tvm/libtvm_runtime.so 3rdparty/tvm/build/libtvm_runtime.so
```

## Step 5: Install Python Packages

```bash
source /opt/rh/gcc-toolset-12/enable
source ~/Projects/mlc_llm/venv/bin/activate

# Install tvm-ffi (from bundled submodule)
pip install 3rdparty/tvm/3rdparty/tvm-ffi --no-build-isolation

# Install TVM Python package
pip install -e 3rdparty/tvm --no-build-isolation

# Install sentencepiece (older version compatible with system libs)
pip install 'sentencepiece==0.2.0'

# Install MLC LLM Python package
cd python && pip install -e . && cd ..
```

## Step 6: Verify Installation

```bash
source /opt/rh/gcc-toolset-12/enable
source ~/Projects/mlc_llm/venv/bin/activate

python -c "import tvm; print('TVM version:', tvm.__version__)"
python -c "import mlc_llm; print('MLC LLM:', mlc_llm)"
mlc_llm chat -h
```

Expected output (ARM target warnings are harmless — LLVM on ppc64le doesn't have ARM targets):
```
TVM version: 0.24.dev0
MLC LLM: <module 'mlc_llm' from '.../python/mlc_llm/__init__.py'>
usage: MLC LLM Chat CLI [-h] [--device DEVICE] ...
```

## Summary of ppc64le-specific Issues and Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| `unsupported GNU version! gcc > 13` | CUDA 12.4 rejects GCC 14 | Use gcc-toolset-12 |
| `NumPy requires GCC >= 9.3` | System GCC 8 too old | gcc-toolset-12 also works (>= 9.3) |
| `undefined symbol: _ZNSt7__cxx1119basic_ostringstream...` | RHEL gcc-toolset splits libstdc++ into shared + `_nonshared.a` | Link `libstdc++_nonshared.a` with `--whole-archive` |
| `Cannot find object type index for script.PrinterConfig` | `BUILD_DUMMY_LIBTVM ON` builds runtime-only TVM | Set `BUILD_DUMMY_LIBTVM OFF` |
| lld linker errors (`__cxa_call_terminate`) | TVM auto-selects lld from LLVM; ABI mismatch with gcc-toolset | Set `USE_ALTERNATIVE_LINKER OFF` |
| `torch` / `flashinfer-python` not found | No ppc64le wheels on PyPI | Comment out from `requirements.txt` |
| `sentencepiece` build fails | Latest version needs newer system libs | Use `sentencepiece==0.2.0` |
| CMake caches wrong GCC | cmake run under wrong gcc-toolset | Always clean build dir when switching GCC versions |

