@echo off
setlocal EnableDelayedExpansion

set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
    set "VCVARS=!VSINSTALL!\VC\Auxiliary\Build\vcvars64.bat"
)

if not exist "%VCVARS%" (
    echo Could not find a Visual Studio C++ toolchain.
    exit /b 1
)

call "%VCVARS%"
if errorlevel 1 exit /b %errorlevel%

rem rd /s /q build 2>nul
if not exist build mkdir build
pushd build
if errorlevel 1 exit /b %errorlevel%

cmake .. -DGGML_CPU_ALL_VARIANTS=ON -DGGML_CUDA=ON -DGGML_VULKAN=ON -DGGML_BACKEND_DL=ON
if errorlevel 1 goto build_failed

cmake --build . --config Release -j %NUMBER_OF_PROCESSORS%
if errorlevel 1 goto build_failed

popd
exit /b 0

:build_failed
set "BUILD_EXIT=%errorlevel%"
popd
exit /b %BUILD_EXIT%
