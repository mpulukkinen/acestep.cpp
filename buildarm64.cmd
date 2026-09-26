@echo off
setlocal

rem Native Windows ARM64 CPU-only build. Keep accelerators disabled for the
rem first bring-up so the package is easy to validate on Snapdragon X.
cmake -S . -B build-arm64 -A ARM64 ^
  -DGGML_CUDA=OFF ^
  -DGGML_VULKAN=OFF ^
  -DGGML_SYCL=OFF ^
  -DGGML_HIP=OFF ^
  -DGGML_CPU_ALL_VARIANTS=OFF ^
  -DGGML_BACKEND_DL=OFF
if errorlevel 1 exit /b %errorlevel%

cmake --build build-arm64 --config Release -j %NUMBER_OF_PROCESSORS%
exit /b %errorlevel%
