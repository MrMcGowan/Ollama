# Setup Verification Script for Windows K80 Development
# Run this to verify all dependencies are installed correctly

$ErrorActionPreference = "Continue"

Write-Host "`n=== Ollama Windows K80 Development Environment Check ===" -ForegroundColor Cyan
Write-Host "Checking prerequisites...`n" -ForegroundColor Yellow

$allGood = $true

# Check Go
Write-Host "Checking Go..." -NoNewline
try {
    $goVersion = (go version)
    if ($goVersion -match "go1\.2[4-9]" -or $goVersion -match "go1\.[3-9][0-9]") {
        Write-Host " [OK] $goVersion" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] Go 1.24.1+ required, found: $goVersion" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host " [FAIL] Not found" -ForegroundColor Red
    $allGood = $false
}

# Check CUDA
Write-Host "Checking CUDA Toolkit..." -NoNewline
try {
    $nvccVersion = (nvcc --version | Select-String "release").ToString()
    if ($nvccVersion -match "11\.[0-9]" -or $nvccVersion -match "12\.[0-9]") {
        Write-Host " [OK] $nvccVersion" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] CUDA 11.x required" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host " [FAIL] Not found (nvcc.exe)" -ForegroundColor Red
    $allGood = $false
}

# Check CMake
Write-Host "Checking CMake..." -NoNewline
try {
    $cmakeVersion = (cmake --version | Select-Object -First 1)
    if ($cmakeVersion -match "3\.2[1-9]" -or $cmakeVersion -match "3\.[3-9][0-9]") {
        Write-Host " [OK] $cmakeVersion" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] CMake 3.21+ required" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host " [FAIL] Not found" -ForegroundColor Red
    $allGood = $false
}

# Check Node.js
Write-Host "Checking Node.js..." -NoNewline
try {
    $nodeVersion = (node --version)
    if ($nodeVersion -match "v1[8-9]\." -or $nodeVersion -match "v[2-9][0-9]\.") {
        Write-Host " [OK] $nodeVersion" -ForegroundColor Green
    } else {
        Write-Host " [WARN] Node.js 18+ recommended, found: $nodeVersion" -ForegroundColor Yellow
    }
} catch {
    Write-Host " [FAIL] Not found" -ForegroundColor Red
    $allGood = $false
}

# Check TypeScript
Write-Host "Checking TypeScript..." -NoNewline
try {
    $tscVersion = (tsc --version)
    Write-Host " [OK] $tscVersion" -ForegroundColor Green
} catch {
    Write-Host " [WARN] Not found (run: npm install -g typescript)" -ForegroundColor Yellow
}

# Check Git
Write-Host "Checking Git..." -NoNewline
try {
    $gitVersion = (git --version)
    Write-Host " [OK] $gitVersion" -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Not found" -ForegroundColor Red
    $allGood = $false
}

# Check Visual Studio
Write-Host "Checking Visual Studio..." -NoNewline
$vsInstances = Get-CimInstance MSFT_VSInstance -Namespace root/cimv2/vs -ErrorAction SilentlyContinue
if ($vsInstances) {
    $vsVersion = $vsInstances[0].Version
    Write-Host " [OK] Visual Studio $vsVersion" -ForegroundColor Green
} else {
    Write-Host " [FAIL] Not found" -ForegroundColor Red
    $allGood = $false
}

# Check Inno Setup
Write-Host "Checking Inno Setup..." -NoNewline
$innoSetup = Get-Item "C:\Program Files*\Inno Setup*\" -ErrorAction SilentlyContinue
if ($innoSetup) {
    Write-Host " [OK] Found at $($innoSetup[0].FullName)" -ForegroundColor Green
} else {
    Write-Host " [WARN] Not found (required for installer creation)" -ForegroundColor Yellow
}

# Check GPU
Write-Host "`nChecking NVIDIA GPU..." -ForegroundColor Yellow
try {
    $gpuInfo = (nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader)
    Write-Host "GPU Info: $gpuInfo" -ForegroundColor Cyan

    if ($gpuInfo -match "K80" -and $gpuInfo -match "3\.7") {
        Write-Host "[OK] Tesla K80 detected with Compute Capability 3.7!" -ForegroundColor Green
    } elseif ($gpuInfo -match "3\.7") {
        Write-Host "[OK] Kepler GPU detected (Compute Capability 3.7)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] GPU compute capability: Check if compatible" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[FAIL] nvidia-smi not found or no GPU detected" -ForegroundColor Red
    $allGood = $false
}

# Check Go modules
Write-Host "`nChecking Go modules..." -NoNewline
Push-Location $PSScriptRoot\..
try {
    $modStatus = (go mod verify 2>&1)
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK] Verified" -ForegroundColor Green
    } else {
        Write-Host " [WARN] Run 'go mod download' and 'go mod tidy'" -ForegroundColor Yellow
    }
} catch {
    Write-Host " [WARN] Error checking modules" -ForegroundColor Yellow
}
Pop-Location

# Check project structure
Write-Host "`nChecking project structure..." -ForegroundColor Yellow
$requiredDirs = @(
    ".idea\runConfigurations",
    "Documentation",
    "scripts"
)

foreach ($dir in $requiredDirs) {
    $fullPath = Join-Path (Join-Path $PSScriptRoot "..") $dir
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $dir" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $dir missing" -ForegroundColor Red
        $allGood = $false
    }
}

# Check run configurations
$runConfigs = @(
    "Ollama_Server.xml",
    "Ollama_CLI.xml",
    "Build_CUDA_with_K80.xml",
    "Ollama_Build_All.xml",
    "Run_Tests.xml"
)

Write-Host "`nChecking GoLand run configurations..." -ForegroundColor Yellow
foreach ($config in $runConfigs) {
    $configPath = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") ".idea\runConfigurations") $config
    if (Test-Path $configPath) {
        Write-Host "  [OK] $($config -replace '\.xml$', '')" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($config -replace '\.xml$', '') missing" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
if ($allGood) {
    Write-Host "[OK] All critical prerequisites are installed!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Open D:\Ollama in GoLand" -ForegroundColor White
    Write-Host "  2. Run: .\scripts\build_cuda_k80.ps1" -ForegroundColor White
    Write-Host "  3. Use 'Ollama - Server' run configuration to start" -ForegroundColor White
    Write-Host "`nFor detailed setup, see: Documentation\windows-development-setup.md" -ForegroundColor Cyan
} else {
    Write-Host "[FAIL] Some prerequisites are missing!" -ForegroundColor Red
    Write-Host "`nPlease install missing components and run this script again." -ForegroundColor Yellow
    Write-Host "See Documentation\windows-development-setup.md for installation instructions." -ForegroundColor Cyan
}
Write-Host ("=" * 60) -ForegroundColor Cyan

