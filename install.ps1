# OC & Benchmarking Tools Installer/Uninstaller
# Description: Installs or uninstalls Chocolatey and essential overclocking/benchmarking tools

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# Mode selection
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OC & Benchmark Tools Manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Select mode:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  [1] Install tools" -ForegroundColor Green
Write-Host "  [2] Uninstall tools" -ForegroundColor Red
Write-Host "  [3] Exit" -ForegroundColor Gray
Write-Host ""
$modeChoice = Read-Host "Enter your choice (1-3)"

if ($modeChoice -eq "3") {
    Write-Host "Exiting..." -ForegroundColor Yellow
    exit 0
}

$isUninstallMode = ($modeChoice -eq "2")

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
    @{Name="testmem5"; Description="TestMem5 - RAM stability testing (custom install)"; Selected=$true; CustomInstall=$true},

    # Storage Benchmarks
    @{Name="crystaldiskmark.portable"; Description="CrystalDiskMark - SSD/HDD benchmark tool"; Selected=$true},

    # Overclocking Utilities
    @{Name="msiafterburner"; Description="MSI Afterburner - GPU overclocking & monitoring"; Selected=$true}
)

$currentIndex = 0
$totalItems = $packages.Count + 1  # +1 for "Start Installation"

function Show-Menu {
    Clear-Host
    $modeTitle = if ($isUninstallMode) { "Uninstaller" } else { "Installer" }
    $actionText = if ($isUninstallMode) { "uninstall" } else { "install" }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  OC & Benchmark Tools $modeTitle" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select tools to ${actionText}:" -ForegroundColor Yellow
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
    
    # "Start Installation/Uninstallation" option
    $startText = if ($isUninstallMode) { "START UNINSTALLATION" } else { "START INSTALLATION" }
    $startColor = if ($isUninstallMode) { "Red" } else { "Yellow" }
    $prefix = if ($currentIndex -eq $packages.Count) { ">" } else { " " }
    if ($currentIndex -eq $packages.Count) {
        Write-Host "$prefix [ $startText ]" -ForegroundColor $startColor -BackgroundColor DarkGreen
    } else {
        Write-Host "$prefix [ $startText ]" -ForegroundColor $startColor
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

# Start installation/uninstallation
Clear-Host
$actionTitle = if ($isUninstallMode) { "Uninstallation" } else { "Installation" }
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting $actionTitle" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $isUninstallMode) {
    # Install Chocolatey if not present (only for install mode)
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
}

Write-Host ""
$actionVerb = if ($isUninstallMode) { "Uninstalling" } else { "Installing" }
Write-Host "$actionVerb selected packages..." -ForegroundColor Yellow
Write-Host ""

# Function to install TestMem5
function Install-TestMem5 {
    Write-Host "Installing TestMem5 (custom install)..." -ForegroundColor Cyan

    # Ensure 7zip is installed
    if (!(Get-Command 7z -ErrorAction SilentlyContinue)) {
        Write-Host "  Installing 7zip (required for extraction)..." -ForegroundColor Yellow
        choco install 7zip.install -y
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    $downloadUrl = "https://github.com/CoolCmd/TestMem5/releases/download/v0.13.1/TestMem5.7z"
    $appDataPath = [Environment]::GetFolderPath("ApplicationData")
    $installPath = Join-Path $appDataPath "TestMem5"
    $downloadFile = Join-Path $env:TEMP "TestMem5.7z"

    try {
        # Download TestMem5
        Write-Host "  Downloading TestMem5..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadFile -UseBasicParsing

        # Create installation directory
        if (!(Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }

        # Extract with 7zip
        Write-Host "  Extracting TestMem5..." -ForegroundColor Yellow
        & 7z x "$downloadFile" -o"$installPath" -y | Out-Null

        # Create desktop shortcut
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $exePath = Join-Path $installPath "TM5.exe"

        if (Test-Path $exePath) {
            $shortcutPath = Join-Path $desktopPath "TestMem5.lnk"
            $WScriptShell = New-Object -ComObject WScript.Shell
            $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exePath
            $shortcut.WorkingDirectory = $installPath
            $shortcut.Description = "TestMem5 - RAM Stability Testing"
            $shortcut.Save()

            Write-Host "  TestMem5 installed to: $installPath" -ForegroundColor Green
            Write-Host "  Desktop shortcut created!" -ForegroundColor Green
        } else {
            Write-Host "  Warning: TM5.exe not found after extraction" -ForegroundColor Red
        }

        # Cleanup
        Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Host "  Error installing TestMem5: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# Function to uninstall TestMem5
function Uninstall-TestMem5 {
    Write-Host "Uninstalling TestMem5 (custom uninstall)..." -ForegroundColor Cyan

    $appDataPath = [Environment]::GetFolderPath("ApplicationData")
    $installPath = Join-Path $appDataPath "TestMem5"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "TestMem5.lnk"

    try {
        # Remove desktop shortcut
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Host "  Desktop shortcut removed" -ForegroundColor Green
        }

        # Remove installation directory
        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force
            Write-Host "  TestMem5 folder removed from: $installPath" -ForegroundColor Green
        } else {
            Write-Host "  TestMem5 folder not found (may already be uninstalled)" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "  Error uninstalling TestMem5: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# Install or Uninstall each selected package
foreach ($pkg in $selectedPackages) {
    if ($pkg.CustomInstall -and $pkg.Name -eq "testmem5") {
        if ($isUninstallMode) {
            Uninstall-TestMem5
        } else {
            Install-TestMem5
        }
    } else {
        $action = if ($isUninstallMode) { "Uninstalling" } else { "Installing" }
        Write-Host "$action $($pkg.Name)..." -ForegroundColor Cyan
        if ($isUninstallMode) {
            choco uninstall $pkg.Name -y
        } else {
            choco install $pkg.Name -y
        }
        Write-Host ""
    }
}

$completeText = if ($isUninstallMode) { "Uninstallation Complete!" } else { "Installation Complete!" }
$listTitle = if ($isUninstallMode) { "Uninstalled tools:" } else { "Installed tools:" }

Write-Host "========================================" -ForegroundColor Green
Write-Host "  $completeText" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "$listTitle" -ForegroundColor White
foreach ($pkg in $selectedPackages) {
    Write-Host "  - $($pkg.Description)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Yellow
pause
