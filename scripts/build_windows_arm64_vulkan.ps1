[CmdletBinding()]
param([switch]$Clean)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$sdk = $env:VULKAN_SDK
if (-not $sdk) { throw "Set VULKAN_SDK to a Vulkan SDK with ARM64 components" }
$library = Join-Path $sdk "Lib-ARM64/vulkan-1.lib"
$includes = Join-Path $sdk "Include"
$glslc = Join-Path $sdk "Bin/glslc.exe"
foreach ($path in @($library, $includes, $glslc)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing ARM64 Vulkan build dependency: $path" }
}
$build = Join-Path $repo "build-arm64-vulkan"
if ($Clean -and (Test-Path $build)) { Remove-Item -LiteralPath $build -Recurse -Force }
$configure = @(
    "-S", $repo, "-B", $build, "-G", "Visual Studio 17 2022", "-A", "ARM64", "-T", "ClangCL",
    "-DGGML_CUDA=OFF", "-DGGML_VULKAN=ON", "-DGGML_SYCL=OFF", "-DGGML_HIP=OFF",
    "-DGGML_NATIVE=OFF", "-DGGML_CPU_ARM_ARCH=armv8-a",
    "-DGGML_CPU_ALL_VARIANTS=OFF", "-DGGML_BACKEND_DL=OFF",
    "-DGGML_OPENMP=OFF",
    "-DVulkan_LIBRARY=$library", "-DVulkan_INCLUDE_DIR=$includes",
    "-DVulkan_GLSLC_EXECUTABLE=$glslc"
)
& cmake.exe @configure
if ($LASTEXITCODE -ne 0) { throw "ARM64 Vulkan CMake configure failed" }
$cache = Join-Path $build "CMakeCache.txt"
if (-not (Select-String -LiteralPath $cache -Pattern '^GGML_VULKAN:BOOL=(ON|TRUE|1)$' -Quiet)) {
    throw "Refusing to package a build without GGML_VULKAN enabled"
}
& cmake.exe --build $build --config Release --parallel ([Math]::Max(2, [Environment]::ProcessorCount))
if ($LASTEXITCODE -ne 0) { throw "ARM64 Vulkan build failed" }

$package = Join-Path $repo "dist/acestep-windows-arm64-vulkan"
New-Item -ItemType Directory -Force -Path $package | Out-Null
$expected = @("ace-lm", "ace-synth", "ace-server", "ace-understand",
              "quantize", "neural-codec", "mp3-codec")
function Assert-Arm64Pe([string]$file) {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    if ($bytes.Length -lt 0x40) { throw "Not a PE file: $file" }
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($offset -lt 0 -or $offset + 6 -ge $bytes.Length) { throw "Invalid PE header: $file" }
    $machine = [BitConverter]::ToUInt16($bytes, $offset + 4)
    if ($machine -ne 0xAA64) { throw "Not an ARM64 PE binary: $file (0x$($machine.ToString('X4')))" }
}
foreach ($name in $expected) {
    $binary = Get-ChildItem -LiteralPath $build -Recurse -File -Filter "$name.exe" |
              Where-Object { $_.FullName -notlike "$package*" } | Select-Object -First 1
    if (-not $binary) { throw "Missing ARM64 tool: $name.exe" }
    Assert-Arm64Pe $binary.FullName
    Copy-Item -LiteralPath $binary.FullName -Destination $package -Force
}
Get-ChildItem -LiteralPath $build -Recurse -File -Filter "*.dll" | ForEach-Object {
    Assert-Arm64Pe $_.FullName
    Copy-Item -LiteralPath $_.FullName -Destination $package -Force
}
# A genuinely Vulkan-enabled binary or backend DLL must import the Vulkan loader.
$importsVulkan = Get-ChildItem -LiteralPath $package -File |
    Where-Object { $_.Extension -in @(".dll", ".exe") } |
    Where-Object {
        $image = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($_.FullName))
        $image.IndexOf("vulkan-1.dll", [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Select-Object -First 1
if (-not $importsVulkan) {
    throw "No packaged native ARM64 binary imports vulkan-1.dll; refusing CPU-only release"
}
$archive = Join-Path $repo "acestep-windows-arm64-vulkan.zip"
if (Test-Path $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -Path $package -DestinationPath $archive
Write-Host "Built native ARM64 Vulkan release: $archive (Vulkan import: $($importsVulkan.Name))"
