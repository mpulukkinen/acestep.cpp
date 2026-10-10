# Windows x64 CI host cross-compiling Vulkan binaries for Windows ARM64.
# Installs ARM64 Vulkan import libraries but keeps x64 host shader tooling.
$ErrorActionPreference = "Stop"
$version = "1.4.357.0"
$installer = Join-Path $env:RUNNER_TEMP "VulkanSDK-$version.exe"
$url = "https://sdk.lunarg.com/sdk/download/$version/windows/vulkansdk-windows-X64-$version.exe"
& curl.exe --fail --location --retry 3 --output $installer $url
if ($LASTEXITCODE -ne 0) { throw "Unable to download Vulkan SDK" }
& $installer --accept-licenses --default-answer --confirm-command install com.lunarg.vulkan.arm64
if ($LASTEXITCODE -notin @(0, 3010)) { throw "Vulkan SDK setup failed: $LASTEXITCODE" }
$sdk = "C:\VulkanSDK\$version"
if (-not (Test-Path "$sdk\Lib-ARM64\vulkan-1.lib")) {
    throw "Vulkan SDK ARM64 import library missing: $sdk\Lib-ARM64\vulkan-1.lib"
}
if (-not (Test-Path "$sdk\Bin\glslc.exe")) { throw "x64 glslc shader compiler is missing" }
"VULKAN_SDK=$sdk" | Out-File -FilePath $env:GITHUB_ENV -Append
"$sdk\Bin" | Out-File -FilePath $env:GITHUB_PATH -Append

# The ACE-Step ggml submodule requires find_package(SPIRV-Headers CONFIG).
# Install headers into a local prefix and pass that prefix to CMake.
$source = Join-Path $env:GITHUB_WORKSPACE ".deps/SPIRV-Headers"
$build = Join-Path $env:GITHUB_WORKSPACE ".deps/SPIRV-Headers-build"
$prefix = Join-Path $env:GITHUB_WORKSPACE ".deps/spirv-headers"
& git clone --depth 1 --branch vulkan-sdk-$version https://github.com/KhronosGroup/SPIRV-Headers.git $source
if ($LASTEXITCODE -ne 0) { throw "Unable to clone SPIRV-Headers" }
& cmake -S $source -B $build "-DCMAKE_INSTALL_PREFIX=$prefix"
if ($LASTEXITCODE -ne 0) { throw "SPIRV-Headers configure failed" }
& cmake --install $build
if ($LASTEXITCODE -ne 0) { throw "SPIRV-Headers install failed" }
"CMAKE_PREFIX_PATH=$prefix" | Out-File -FilePath $env:GITHUB_ENV -Append
