# OC & Benchmarking Tools Installer
# Description: Installs Chocolatey and essential overclocking/benchmarking tools

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# Package definitions
$packages = @(
    # Monitoring & Diagnostics
    @{Name="hwinfo"; Description="HWiNFO - Hardware monitoring & diagnostics"; Selected=$true},
    @{Name="cpu-z.portable"; Description="CPU-Z - CPU information & monitoring"; Selected=$true},
    @{Name="gpu-z"; Description="GPU-Z - Graphics card information"; Selected=$true},
    @{Name="aida64-extreme"; Description="AIDA64 Extreme - System info & benchmarks (30-day trial)"; Selected=$false},

    # Stress Testing & Benchmarks
    @{Name="prime95.portable"; Description="Prime95 - CPU stress testing"; Selected=$true},
    @{Name="occt"; Description="OCCT - CPU/GPU/RAM stability testing"; Selected=$true},
    @{Name="furmark"; Description="FurMark - GPU stress test & burn-in"; Selected=$true},
    @{Name="cinebench"; Description="Cinebench - CPU rendering benchmark"; Selected=$true},

    # Storage Benchmarks
    @{Name="crystaldiskmark.portable"; Description="CrystalDiskMark - SSD/HDD benchmark tool"; Selected=$true},

    # Overclocking Utilities
    @{Name="msiafterburner"; Description="MSI Afterburner - GPU overclocking & monitoring"; Selected=$true}
)

$currentIndex = 0
$totalItems = $packages.Count + 1  # +1 for "Start Installation"

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  OC & Benchmark Tools Installer" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select tools to install:" -ForegroundColor Yellow
    Write-Host "(Use UP/DOWN arrows, SPACE to toggle, ENTER to select, ESC to exit)" -ForegroundColor Gray
    Write-Host ""
    
    for ($i = 0; $i -lt $packages.Count; $i++) {
        $checkbox = if ($packages[$i].Selected) { "[X]" } else { "[ ]" }
        $prefix = if ($i -eq $currentIndex) { ">" } else { " " }
        
        if ($i -eq $currentIndex) {
            Write-Host "$prefix $checkbox $($packages[$i].Description)" -ForegroundColor Green
        } else {
            Write-Host "$prefix $checkbox $($packages[$i].Description)"
        }
    }
    
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    
    # "Start Installation" option
    $prefix = if ($currentIndex -eq $packages.Count) { ">" } else { " " }
    if ($currentIndex -eq $packages.Count) {
        Write-Host "$prefix [ START INSTALLATION ]" -ForegroundColor Yellow -BackgroundColor DarkGreen
    } else {
        Write-Host "$prefix [ START INSTALLATION ]" -ForegroundColor Yellow
    }
    
    Write-Host ""
    $selectedCount = ($packages | Where-Object { $_.Selected }).Count
    Write-Host "Selected: $selectedCount / $($packages.Count)" -ForegroundColor Cyan
}

# Interactive menu loop
:MenuLoop while ($true) {
    Show-Menu

    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $totalItems - 1 }
        }
        40 { # Down arrow
            $currentIndex = if ($currentIndex -lt $totalItems - 1) { $currentIndex + 1 } else { 0 }
        }
        32 { # Space - only toggle if not on "Start Installation"
            if ($currentIndex -lt $packages.Count) {
                $packages[$currentIndex].Selected = -not $packages[$currentIndex].Selected
            }
        }
        13 { # Enter - toggle package or start installation
            if ($currentIndex -eq $packages.Count) {
                break MenuLoop
            } else {
                # Toggle package selection like Space does
                $packages[$currentIndex].Selected = -not $packages[$currentIndex].Selected
            }
        }
        27 { # Escape
            Clear-Host
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
}

# Get selected packages
$selectedPackages = $packages | Where-Object { $_.Selected }

if ($selectedPackages.Count -eq 0) {
    Clear-Host
    Write-Host "No packages selected. Exiting." -ForegroundColor Yellow
    pause
    exit 0
}

# Start installation
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Install Chocolatey if not present
Write-Host "Checking for Chocolatey..." -ForegroundColor Yellow
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Green
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Chocolatey installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Chocolatey is already installed." -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing selected packages..." -ForegroundColor Yellow
Write-Host ""

# Install each selected package
foreach ($pkg in $selectedPackages) {
    Write-Host "Installing $($pkg.Name)..." -ForegroundColor Cyan
    choco install $pkg.Name -y
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed tools:" -ForegroundColor White
foreach ($pkg in $selectedPackages) {
    Write-Host "  - $($pkg.Description)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Yellow
pause
