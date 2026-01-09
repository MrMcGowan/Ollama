# Build script for NVIDIA Tesla K80 (Compute Capability 3.7)
# powershell -ExecutionPolicy Bypass -File .\scripts\build_cuda_k80.ps1

$ErrorActionPreference = "Stop"

Write-Host "Building Ollama with NVIDIA Tesla K80 (Kepler) Support" -ForegroundColor Green
Write-Host "Compute Capability: 3.7" -ForegroundColor Cyan

$SRC_DIR = $PWD
$ARCH = "amd64"
$DIST_DIR = "${SRC_DIR}\dist\windows-${ARCH}"

# Check for CUDA
$cudaList = (Get-Item "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v*\bin\" -ea 'silentlycontinue')
if ($cudaList.length -eq 0) {
    $d = (Get-Command -ea 'silentlycontinue' nvcc).path
    if ($null -ne $d) {
        $CUDA_DIRS = @($d | Split-Path -parent)
    }
} else {
    $CUDA_DIRS = ($cudaList | Sort-Object -Descending)
}

if ($CUDA_DIRS.length -eq 0) {
    Write-Host "ERROR: No CUDA installation found!" -ForegroundColor Red
    Write-Host "Please install CUDA Toolkit 11.x or 12.x" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found CUDA: $CUDA_DIRS" -ForegroundColor Green

# Create dist directory
New-Item -Force -ItemType Directory -Path "${DIST_DIR}\lib\ollama\" | Out-Null

# Determine which CUDA version to use (prefer 11.x for K80 compatibility)
$cuda = $null
foreach ($d in $CUDA_DIRS) {
    if ($d.FullName.Contains("v11")) {
        if (Test-Path -LiteralPath (Join-Path -Path $d -ChildPath "nvcc.exe")) {
            $cuda = ($d.FullName | Split-Path -Parent)
            Write-Host "Using CUDA 11.x for best K80 compatibility: $cuda" -ForegroundColor Green
            break
        }
    }
}

# If no CUDA 11.x found, use the first available
if ($null -eq $cuda) {
    foreach ($d in $CUDA_DIRS) {
        if (Test-Path -LiteralPath (Join-Path -Path $d -ChildPath "nvcc.exe")) {
            $cuda = ($d.FullName | Split-Path -Parent)
            Write-Host "Using CUDA: $cuda" -ForegroundColor Yellow
            break
        }
    }
}

if ($null -eq $cuda) {
    Write-Host "ERROR: nvcc.exe not found in CUDA directories!" -ForegroundColor Red
    exit 1
}

# Set environment
$env:CUDAToolkit_ROOT = $cuda
$JOBS = ([Environment]::ProcessorCount)

Write-Host "`nBuilding K80-optimized CUDA backend..." -ForegroundColor Cyan
Write-Host "Target Architecture: sm_37 (Kepler)" -ForegroundColor Cyan

# Build CUDA K80 target
& cmake -B build\cuda_k80 --preset "CUDA K80" -T cuda="$cuda" -DCMAKE_CUDA_COMPILER="$cuda\bin\nvcc.exe" --install-prefix "$DIST_DIR"
if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake configuration failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

& cmake --build build\cuda_k80 --target ggml-cuda --config Release --parallel $JOBS
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

& cmake --install build\cuda_k80 --component "CUDA" --strip
if ($LASTEXITCODE -ne 0) {
    Write-Host "Install failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`nâœ“ K80 CUDA backend built successfully!" -ForegroundColor Green
Write-Host "Output: $DIST_DIR\lib\ollama\" -ForegroundColor Cyan
