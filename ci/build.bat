rem This file is licensed under the public domain.

@echo off

SETLOCAL EnableDelayedExpansion
if NOT DEFINED VSCMD_VER (
   echo error: this script must be run within the visual studio developer command prompt
   exit /b 1
)

where ninja >nul 2>nul
if %ERRORLEVEL% neq 0 (
   echo error: this script requires ninja to be installed, as the Visual Studio cmake generator doesn't support alternate compilers
   exit /b %ERRORLEVEL%
)

if "%1" == "" (set "TARGET=x86_64-windows-gnu") ELSE (set TARGET=%~1)
if "%2" == "" (set "MCPU=native") ELSE (set MCPU=%~2)
if "%VSCMD_ARG_HOST_ARCH%"=="x86" set HOST_TARGET=x86-windows-msvc
if "%VSCMD_ARG_HOST_ARCH%"=="x64" set HOST_TARGET=x86_64-windows-msvc
echo Boostrapping targeting %TARGET% (%MCPU%), using %HOST_TARGET% as the host compiler

set TARGET_ABI=
set TARGET_OS_CMAKE=
FOR /F "tokens=2,3 delims=-" %%i IN ("%TARGET%") DO (
  IF "%%i"=="macos" set "TARGET_OS_CMAKE=Darwin"
  IF "%%i"=="freebsd" set "TARGET_OS_CMAKE=FreeBSD"
  IF "%%i"=="netbsd" set "TARGET_OS_CMAKE=NetBSD"
  IF "%%i"=="openbsd" set "TARGET_OS_CMAKE=OpenBSD"
  IF "%%i"=="windows" set "TARGET_OS_CMAKE=Windows"
  IF "%%i"=="linux" set "TARGET_OS_CMAKE=Linux"
  set TARGET_ABI=%%j
)

set OUTDIR=out
if "%VSCMD_ARG_HOST_ARCH%"=="x86" set OUTDIR=out-x86

set ROOTDIR=%cd%
set "ROOTDIR_CMAKE=%ROOTDIR:\=/%"
set JOBS_ARG=

rem Detect sccache
set CMAKE_LAUNCHER=
where sccache >nul 2>nul
if %ERRORLEVEL% equ 0 (
   echo sccache detected, enabling...
   set CMAKE_LAUNCHER=-DCMAKE_C_COMPILER_LAUNCHER=sccache -DCMAKE_CXX_COMPILER_LAUNCHER=sccache
)

pushd %ROOTDIR%

rem Build the libraries for Zig to link against, as well as native `llvm-tblgen` using msvc
mkdir "%ROOTDIR%\build-llvm-host"
cd "%ROOTDIR%\build-llvm-host"
cmake "%ROOTDIR%/llvm" ^
  -G "Ninja" ^
  %CMAKE_LAUNCHER% ^
  -DCMAKE_INSTALL_PREFIX="%ROOTDIR%/%OUTDIR%/host" ^
  -DCMAKE_PREFIX_PATH="%ROOTDIR%/%OUTDIR%/host" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DLLVM_ENABLE_BINDINGS=OFF ^
  -DLLVM_ENABLE_LIBEDIT=OFF ^
  -DLLVM_ENABLE_LIBPFM=OFF ^
  -DLLVM_ENABLE_LIBXML2=OFF ^
  -DLLVM_ENABLE_OCAMLDOC=OFF ^
  -DLLVM_ENABLE_PLUGINS=OFF ^
  -DLLVM_ENABLE_PROJECTS="lld;clang" ^
  -DLLVM_ENABLE_Z3_SOLVER=OFF ^
  -DLLVM_ENABLE_ZSTD=OFF ^
  -DLLVM_ENABLE_ZLIB=OFF ^
  -DLLVM_INCLUDE_UTILS=OFF ^
  -DLLVM_INCLUDE_TESTS=OFF ^
  -DLLVM_INCLUDE_EXAMPLES=OFF ^
  -DLLVM_INCLUDE_BENCHMARKS=OFF ^
  -DLLVM_INCLUDE_DOCS=OFF ^
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF ^
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF ^
  -DLLVM_TOOL_LTO_BUILD=OFF ^
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF ^
  -DCLANG_BUILD_TOOLS=OFF ^
  -DCLANG_INCLUDE_DOCS=OFF ^
  -DCLANG_INCLUDE_TESTS=OFF ^
  -DCLANG_ENABLE_ARCMT=OFF ^
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF ^
  -DCLANG_ENABLE_LIBCLANG=OFF ^
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF ^
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF ^
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF ^
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF ^
  -DCLANG_TOOL_SCAN_BUILD_BUILD=OFF ^
  -DCLANG_TOOL_SCAN_VIEW_BUILD=OFF ^
  -DLLVM_BUILD_LLVM_C_DYLIB=NO
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
cmake --build . %JOBS_ARG% --target install
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

popd
