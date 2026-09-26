@echo off
setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" arm64 2>nul
if errorlevel 1 call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" arm64
if errorlevel 1 exit /b %errorlevel%

if exist build-arm64 rd /s /q build-arm64

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
