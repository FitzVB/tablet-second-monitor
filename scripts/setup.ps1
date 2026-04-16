# setup.ps1 - Automated Setup Script for Tablet Second Monitor Project
# Purpose: Install all dependencies and verify environment
# Usage: .\setup.ps1 [-Install] [-Verify] [-Full]

param(
    [switch]$Install = $false,
    [switch]$Verify = $false,
    [switch]$Full = $false
)

# If no parameters, show help
if (-not $Install -and -not $Verify -and -not $Full) {
    Write-Host @"
Tablet Second Monitor - Setup Script

Usage:
  .\setup.ps1 -Verify       # Check if all dependencies are installed
  .\setup.ps1 -Install      # Install missing dependencies
  .\setup.ps1 -Full         # Install all dependencies and verify

Options:
  -Install    Install missing tools
  -Verify     Only check status (default)
  -Full       Full setup (install + verify)
"@
    exit 0
}

# Enable running scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Write-Host "================================================"
Write-Host "Tablet Second Monitor - Setup Script"
Write-Host "================================================`n"

# Define dependencies
$dependencies = @{
    "Rust Toolchain" = @{
        "test" = "rustc --version"
        "install" = "Run from https://rustup.rs or use: winget install -e --id Rustlang.Rust.MSVC"
        "category" = "required"
    }
    "Cargo" = @{
        "test" = "cargo --version"
        "install" = "Installed with Rust"
        "category" = "required"
    }
    "ADB" = @{
        "test" = "adb version"
        "install" = "winget install -e --id Google.AndroidStudio.Tools"
        "category" = "required"
    }
    "Java (JDK)" = @{
        "test" = "java -version"
        "install" = "winget install -e --id EclipseAdoptium.Temurin.17 OR scoop install openjdk17"
        "category" = "required"
    }
    "Git" = @{
        "test" = "git --version"
        "install" = "winget install -e --id Git.Git"
        "category" = "required"
    }
    "FFmpeg" = @{
        "test" = "ffmpeg -version"
        "install" = "winget install FFmpeg"
        "category" = "optional"
    }
}

# Results tracking
$results = @{
    "installed" = @()
    "missing" = @()
    "errors" = @()
}

Write-Host "Checking dependencies..." -ForegroundColor Cyan

# Test each dependency
foreach ($dep in $dependencies.GetEnumerator()) {
    $name = $dep.Name
    $testCmd = $dep.Value.test
    $category = $dep.Value.category
    
    try {
        $output = & $testCmd 2>&1 | Select-Object -First 1
        $results.installed += @{ name = $name; version = $output; category = $category }
        $status = "✓ Installed"
        $color = "Green"
    } catch {
        $results.missing += @{ name = $name; category = $category; install = $dep.Value.install }
        $status = "✗ Missing"
        $color = "Yellow"
    }
    
    Write-Host "  [$color]$status[0m $name" -ForegroundColor @($color, $null)[0]
}

# Summary
Write-Host "`n================================================"
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host "Installed: $($results.installed.Count)" -ForegroundColor Green
Write-Host "Missing: $($results.missing.Count)" -ForegroundColor Yellow

$requiredMissing = $results.missing | Where-Object { $_.category -eq "required" }
if ($requiredMissing.Count -gt 0) {
    Write-Host "REQUIRED Missing: $($requiredMissing.Count)" -ForegroundColor Red
}

# Show installed versions
if ($results.installed.Count -gt 0) {
    Write-Host "`nInstalled Versions:" -ForegroundColor Cyan
    foreach ($item in $results.installed) {
        Write-Host "  - $($item.name): $($item.version)" -ForegroundColor Green
    }
}

# Show missing tools
if ($results.missing.Count -gt 0) {
    Write-Host "`nMissing Tools:" -ForegroundColor Cyan
    foreach ($item in $results.missing) {
        $cat = if ($item.category -eq "required") { "REQUIRED" } else { "optional" }
        Write-Host "  - $($item.name) [$cat]" -ForegroundColor Yellow
        Write-Host "    Install: $($item.install)" -ForegroundColor Gray
    }
}

# Install if requested
if ($Install -or $Full) {
    if ($results.missing.Count -gt 0) {
        Write-Host "`n================================================"
        Write-Host "Installing Missing Dependencies..." -ForegroundColor Cyan
        Write-Host "================================================"
        
        $requiredMissing = $results.missing | Where-Object { $_.category -eq "required" }
        
        if ($requiredMissing.Count -gt 0) {
            Write-Host "`nREQUIRED PACKAGES (User Action Needed):" -ForegroundColor Red
            foreach ($item in $requiredMissing) {
                Write-Host "`n1. $($item.name)"
                Write-Host "   Commands:"
                $item.install -split " OR " | ForEach-Object {
                    Write-Host "   - $_" -ForegroundColor Yellow
                }
            }
            Write-Host "`nPlease install these manually, then run setup again." -ForegroundColor Red
        }
    } else {
        Write-Host "`n✓ All required dependencies are installed!" -ForegroundColor Green
    }
}

# Build verification
Write-Host "`n================================================"
Write-Host "Build Configuration" -ForegroundColor Cyan
Write-Host "================================================"

# Check Rust project
If (Test-Path "host-windows\Cargo.toml") {
    Write-Host "✓ Rust Project: host-windows/" -ForegroundColor Green
    $cargoContent = Get-Content "host-windows\Cargo.toml" -Raw
    if ($cargoContent -match 'name = "([^"]+)"') {
        Write-Host "  Package: $($matches[1])" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ Rust Project: host-windows/ NOT FOUND" -ForegroundColor Red
}

# Check Android project
If (Test-Path "android-client\build.gradle.kts") {
    Write-Host "✓ Android Project: android-client/" -ForegroundColor Green
} else {
    Write-Host "✗ Android Project: android-client/ NOT FOUND" -ForegroundColor Red
}

# Quick start guide
Write-Host "`n================================================"
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "================================================"

$nextSteps = @"
1. Verify Setup:
   .\setup.ps1 -Verify

2. Build Host (Rust):
   cd host-windows
   cargo build

3. Build Android:
   cd android-client
   .\gradlew assembleDebug

4. Install APK:
   adb install -r android-client\app\build\outputs\apk\debug\app-debug.apk

5. Run Host Server:
   cd host-windows
   cargo run

6. Connect on Tablet:
   - Launch app
   - Tap "Conectar"
   - Video should appear

For detailed setup instructions, see: SETUP.md
"@

Write-Host $nextSteps -ForegroundColor Cyan

# Exit code
if ($requiredMissing.Count -gt 0) {
    exit 1
} else {
    exit 0
}
