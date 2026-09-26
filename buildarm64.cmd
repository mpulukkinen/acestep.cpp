@echo off
setlocal

rem Native Windows ARM64 CPU-only build. GGML explicitly rejects MSVC for
rem ARM, so use Visual Studio's ClangCL toolset while targeting ARM64.
rem Keep accelerator backends disabled for the first bring-up.
cmake -S . -B build-arm64 -A ARM64 -T ClangCL ^
  -DGGML_CUDA=OFF ^
  -DGGML_VULKAN=OFF ^
  -DGGML_SYCL=OFF ^
  -DGGML_HIP=OFF ^
  -DGGML_CPU_ALL_VARIANTS=OFF ^
  -DGGML_BACKEND_DL=OFF
if errorlevel 1 exit /b %errorlevel%

cmake --build build-arm64 --config Release -j %NUMBER_OF_PROCESSORS%
exit /b %errorlevel%
