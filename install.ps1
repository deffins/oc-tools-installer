# OC & Benchmark Tools Manager
# Features:
# - Install selected tools (Space marks, Enter starts)
# - Remove selected installed tools
# - Update all installed supported tools
# - Detect previous runs on this computer via state file

$ErrorActionPreference = 'Stop'
$scriptVersion = '2.0.0'

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host 'ERROR: This script must be run as Administrator.' -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    pause
    exit 1
}

# State file used to detect if this script was previously run on this computer
$stateDir = Join-Path $env:ProgramData 'FonsLv\OcTools'
$stateFile = Join-Path $stateDir 'state.json'

# Package definitions
$packages = @(
    @{ Name='hwinfo'; DisplayName='HWiNFO'; Description='Hardware monitoring & diagnostics'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='cpu-z.portable'; DisplayName='CPU-Z'; Description='CPU information & monitoring'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='gpu-z'; DisplayName='GPU-Z'; Description='Graphics card information'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='aida64-extreme'; DisplayName='AIDA64 Extreme'; Description='System info & benchmarks (30-day trial)'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='prime95'; DisplayName='Prime95'; Description='CPU stress testing'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='occt'; DisplayName='OCCT'; Description='CPU/GPU/RAM stability testing'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='furmark'; DisplayName='FurMark'; Description='GPU stress test & burn-in'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='cinebench'; DisplayName='Cinebench 2024'; Description='CPU rendering benchmark'; DefaultInstall=$false; CustomInstall=$false },
    @{ Name='cinebench-r23'; DisplayName='Cinebench R23'; Description='CPU rendering benchmark (custom install)'; DefaultInstall=$false; CustomInstall=$true },
    @{ Name='testmem5'; DisplayName='TestMem5'; Description='RAM stability testing (custom install)'; DefaultInstall=$false; CustomInstall=$true },
    @{ Name='crystaldiskmark.portable'; DisplayName='CrystalDiskMark'; Description='SSD/HDD benchmark tool'; DefaultInstall=$false; CustomInstall=$false }
)

$shortcutCandidates = @{
    'hwinfo' = @('hwinfo.exe','HWiNFO64.EXE')
    'cpu-z.portable' = @('cpuz.exe','CPU-Z.exe')
    'gpu-z' = @('GPU-Z.exe','gpuz.exe')
    'prime95' = @('prime95.exe')
    'cinebench' = @('Cinebench.exe')
    'crystaldiskmark.portable' = @('CrystalDiskMark.exe','diskmark32.exe','diskmark64.exe')
    'occt' = @('occt.exe')
    'furmark' = @('FurMark.exe','FurMark64.exe')
}

function Ensure-StateDirectory {
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
}

function New-DefaultState {
    return [ordered]@{
        Version = $scriptVersion
        ComputerName = $env:COMPUTERNAME
        FirstRun = $null
        LastRun = $null
        LastAction = $null
        RunCount = 0
        LastKnownInstalled = @()
    }
}

function Load-InstallerState {
    if (-not (Test-Path $stateFile)) {
        return (New-DefaultState)
    }

    try {
        $raw = Get-Content -Path $stateFile -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return (New-DefaultState)
        }

        $state = $raw | ConvertFrom-Json -AsHashtable
        if (-not $state) {
            return (New-DefaultState)
        }

        if (-not $state.ContainsKey('Version')) { $state['Version'] = $scriptVersion }
        if (-not $state.ContainsKey('ComputerName')) { $state['ComputerName'] = $env:COMPUTERNAME }
        if (-not $state.ContainsKey('FirstRun')) { $state['FirstRun'] = $null }
        if (-not $state.ContainsKey('LastRun')) { $state['LastRun'] = $null }
        if (-not $state.ContainsKey('LastAction')) { $state['LastAction'] = $null }
        if (-not $state.ContainsKey('RunCount')) { $state['RunCount'] = 0 }
        if (-not $state.ContainsKey('LastKnownInstalled')) { $state['LastKnownInstalled'] = @() }

        return $state
    } catch {
        Write-Host "WARNING: Could not parse state file: $stateFile" -ForegroundColor Yellow
        return (New-DefaultState)
    }
}

function Save-InstallerState {
    param(
        [hashtable]$State
    )

    Ensure-StateDirectory
    $json = $State | ConvertTo-Json -Depth 8
    Set-Content -Path $stateFile -Value $json -Encoding UTF8
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Ensure-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host 'Chocolatey not found. Installing Chocolatey...' -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Refresh-Path

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw 'Chocolatey installation failed.'
    }

    Write-Host 'Chocolatey installed successfully.' -ForegroundColor Green
}

function Ensure-SevenZip {
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        return
    }

    Ensure-Chocolatey
    Write-Host 'Installing 7-Zip (required for TestMem5 extraction)...' -ForegroundColor Yellow
    choco install 7zip.install -y --no-progress | Out-Host
    Refresh-Path

    if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) {
        throw '7-Zip installation failed.'
    }
}

function Get-ShortcutDisplayName {
    param([string]$PackageName)

    switch ($PackageName) {
        'cpu-z.portable' { return 'CPU-Z' }
        'hwinfo' { return 'HWiNFO' }
        'gpu-z' { return 'GPU-Z' }
        'prime95' { return 'Prime95' }
        'cinebench' { return 'Cinebench' }
        'crystaldiskmark.portable' { return 'CrystalDiskMark' }
        'occt' { return 'OCCT' }
        'furmark' { return 'FurMark' }
        default { return $PackageName }
    }
}

function Create-DesktopShortcutForPackage {
    param([string]$PackageName)

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $displayName = Get-ShortcutDisplayName $PackageName
    $shortcutPath = Join-Path $desktopPath "$displayName.lnk"

    if (-not $shortcutCandidates.ContainsKey($PackageName)) {
        return
    }

    $candidates = @($shortcutCandidates[$PackageName])

    foreach ($candidate in $candidates) {
        $pathsToCheck = @(
            (Join-Path 'C:\ProgramData\chocolatey\bin' $candidate),
            (Join-Path (Join-Path 'C:\ProgramData\chocolatey\lib' $PackageName) (Join-Path 'tools' $candidate)),
            (Join-Path (Join-Path $env:ProgramFiles $displayName) $candidate),
            (Join-Path (Join-Path ${env:ProgramFiles(x86)} $displayName) $candidate)
        )

        foreach ($path in $pathsToCheck) {
            if (Test-Path $path) {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $path
                $shortcut.WorkingDirectory = Split-Path $path
                $shortcut.Description = "$displayName - created by OC tools manager"
                $shortcut.Save()
                Write-Host "  Desktop shortcut created: $shortcutPath" -ForegroundColor Green
                return
            }
        }
    }

    Write-Host "  Could not find executable for $PackageName. Shortcut not created." -ForegroundColor Yellow
}

function Remove-DesktopShortcutForPackage {
    param([string]$PackageName)

    $displayName = Get-ShortcutDisplayName $PackageName
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "$displayName.lnk"

    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force -ErrorAction SilentlyContinue
        Write-Host "  Desktop shortcut removed: $shortcutPath" -ForegroundColor Green
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$Label
    )

    Write-Host "  Downloading $Label..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    Write-Host "  Download complete: $Label" -ForegroundColor Green
}

function Install-TestMem5 {
    Write-Host 'Installing TestMem5 (custom install)...' -ForegroundColor Cyan

    Ensure-SevenZip

    $downloadUrl = 'https://github.com/CoolCmd/TestMem5/releases/download/v0.13.1/TestMem5.7z'
    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    $installPath = Join-Path $appDataPath 'TestMem5'
    $downloadFile = Join-Path $env:TEMP 'TestMem5.7z'

    try {
        Download-File -Url $downloadUrl -OutFile $downloadFile -Label 'TestMem5'

        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null

        Write-Host '  Extracting TestMem5...' -ForegroundColor Yellow
        & 7z x "$downloadFile" "-o$installPath" -y | Out-Null

        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $exePath = Join-Path $installPath 'TM5.exe'

        if (Test-Path $exePath) {
            $shortcutPath = Join-Path $desktopPath 'TestMem5.lnk'
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exePath
            $shortcut.WorkingDirectory = $installPath
            $shortcut.Description = 'TestMem5 - RAM stability testing'
            $shortcut.Save()

            Write-Host "  TestMem5 installed: $installPath" -ForegroundColor Green
            Write-Host '  Desktop shortcut created.' -ForegroundColor Green
        } else {
            Write-Host '  Warning: TM5.exe not found after extraction.' -ForegroundColor Yellow
        }

        Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Error installing TestMem5: $_" -ForegroundColor Red
    }

    Write-Host ''
}

function Uninstall-TestMem5 {
    Write-Host 'Uninstalling TestMem5 (custom uninstall)...' -ForegroundColor Cyan

    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    $installPath = Join-Path $appDataPath 'TestMem5'
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath 'TestMem5.lnk'

    try {
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Host '  Desktop shortcut removed.' -ForegroundColor Green
        }

        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force
            Write-Host "  TestMem5 folder removed: $installPath" -ForegroundColor Green
        } else {
            Write-Host '  TestMem5 folder not found (already removed).' -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Error uninstalling TestMem5: $_" -ForegroundColor Red
    }

    Write-Host ''
}

function Install-CinebenchR23 {
    Write-Host 'Installing Cinebench R23 (custom install)...' -ForegroundColor Cyan

    Ensure-SevenZip

    $downloadUrl = 'https://installer.maxon.net/cinebench/CinebenchR23.zip'
    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    $installPath = Join-Path $appDataPath 'CinebenchR23'
    $downloadFile = Join-Path $env:TEMP 'CinebenchR23.zip'

    try {
        Download-File -Url $downloadUrl -OutFile $downloadFile -Label 'Cinebench R23'

        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null

        Write-Host '  Extracting Cinebench R23...' -ForegroundColor Yellow
        & 7z x "$downloadFile" "-o$installPath" -y | Out-Null

        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $exePath = Join-Path $installPath 'Cinebench.exe'

        if (Test-Path $exePath) {
            $shortcutPath = Join-Path $desktopPath 'Cinebench R23.lnk'
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exePath
            $shortcut.WorkingDirectory = $installPath
            $shortcut.Description = 'Cinebench R23 - CPU rendering benchmark'
            $shortcut.Save()

            Write-Host "  Cinebench R23 installed: $installPath" -ForegroundColor Green
            Write-Host '  Desktop shortcut created.' -ForegroundColor Green
        } else {
            Write-Host '  Warning: Cinebench.exe not found after extraction.' -ForegroundColor Yellow
        }

        Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Error installing Cinebench R23: $_" -ForegroundColor Red
    }

    Write-Host ''
}

function Uninstall-CinebenchR23 {
    Write-Host 'Uninstalling Cinebench R23 (custom uninstall)...' -ForegroundColor Cyan

    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    $installPath = Join-Path $appDataPath 'CinebenchR23'
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath 'Cinebench R23.lnk'

    try {
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Host '  Desktop shortcut removed.' -ForegroundColor Green
        }

        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force
            Write-Host "  Cinebench R23 folder removed: $installPath" -ForegroundColor Green
        } else {
            Write-Host '  Cinebench R23 folder not found (already removed).' -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Error uninstalling Cinebench R23: $_" -ForegroundColor Red
    }

    Write-Host ''
}

function Get-ChocoInstalledPackageMap {
    $packageMap = @{}

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        return $packageMap
    }

    try {
        $output = choco list --local-only --limit-output 2>$null
        foreach ($line in $output) {
            if ($line -match '^([^|]+)\|') {
                $name = $matches[1].Trim().ToLowerInvariant()
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    $packageMap[$name] = $true
                }
            }
        }
    } catch {
        # If Chocolatey query fails, return empty map and keep script running.
    }

    return $packageMap
}

function Test-CustomPackageInstalled {
    param([string]$PackageName)

    $appDataPath = [Environment]::GetFolderPath('ApplicationData')

    switch ($PackageName) {
        'testmem5' {
            return (Test-Path (Join-Path $appDataPath 'TestMem5\TM5.exe'))
        }
        'cinebench-r23' {
            return (Test-Path (Join-Path $appDataPath 'CinebenchR23\Cinebench.exe'))
        }
        default {
            return $false
        }
    }
}

function Refresh-PackageInstallStatus {
    param(
        [array]$PackageList,
        [string]$Reason = 'Status refresh',
        [switch]$Quiet
    )

    if (-not $PackageList) {
        return
    }

    $total = $PackageList.Count
    if ($total -le 0) {
        return
    }

    Write-Progress -Id 1 -Activity 'Scanning installed tools' -Status 'Loading local Chocolatey package cache...' -PercentComplete 0
    $installedChocoPackages = Get-ChocoInstalledPackageMap

    if (-not $Quiet) {
        Write-Host "Refreshing install status: $Reason" -ForegroundColor DarkCyan
        Write-Host 'Please wait. Building Chocolatey local package cache once, then matching tools.' -ForegroundColor DarkGray
    }

    for ($i = 0; $i -lt $total; $i++) {
        $pkg = $PackageList[$i]
        $checkMethod = if ($pkg.CustomInstall) { 'Checking local custom files' } else { 'Matching against cached Chocolatey list' }
        $statusText = "[$($i + 1)/$total] $($pkg.DisplayName) - $checkMethod"
        $percent = [int]((($i + 1) / $total) * 100)

        Write-Progress -Id 1 -Activity 'Scanning installed tools' -Status $statusText -PercentComplete $percent

        if ($pkg.CustomInstall) {
            $pkg['Installed'] = Test-CustomPackageInstalled -PackageName $pkg.Name
        } else {
            $pkg['Installed'] = $installedChocoPackages.ContainsKey($pkg.Name.ToLowerInvariant())
        }
    }

    Write-Progress -Id 1 -Activity 'Scanning installed tools' -Status 'Completed' -PercentComplete 100
    Write-Progress -Id 1 -Activity 'Scanning installed tools' -Completed

    if (-not $Quiet) {
        Write-Host 'Status scan complete.' -ForegroundColor DarkCyan
    }
}

function Show-UsageGuide {
    Write-Host 'How to use this script:' -ForegroundColor Yellow
    Write-Host '  1) Select an action from the main menu.' -ForegroundColor Gray
    Write-Host '  2) In selection screens use:' -ForegroundColor Gray
    Write-Host '     - UP/DOWN arrows: move cursor' -ForegroundColor Gray
    Write-Host '     - SPACE: select or unselect a tool' -ForegroundColor Gray
    Write-Host '     - A: toggle all selectable tools' -ForegroundColor Gray
    Write-Host '     - ENTER: start selected action' -ForegroundColor Gray
    Write-Host '     - ESC: cancel and return to main menu' -ForegroundColor Gray
    Write-Host '  3) Wait for all tasks to finish.' -ForegroundColor Gray
    Write-Host ''
}

function Show-SystemSummary {
    param(
        [hashtable]$State,
        [array]$PackageList
    )

    $installed = @($PackageList | Where-Object { $_.Installed })
    $installedCount = $installed.Count

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "  OC & Benchmark Tools Manager v$scriptVersion" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    if ($State.LastRun -and $State.ComputerName -eq $env:COMPUTERNAME) {
        Write-Host "Detected previous run on this computer ($($State.ComputerName))." -ForegroundColor Green
        Write-Host "Last run: $($State.LastRun) | Last action: $($State.LastAction)" -ForegroundColor Green
    } else {
        Write-Host 'No previous local run record found for this computer.' -ForegroundColor Yellow
    }

    if ($installedCount -gt 0) {
        Write-Host "Detected installed managed tools: $installedCount / $($PackageList.Count)" -ForegroundColor Green
        Write-Host 'Use [2] to remove selected installed tools or [3] to update all installed tools.' -ForegroundColor Gray
    } else {
        Write-Host 'No managed tools currently detected as installed.' -ForegroundColor Yellow
    }

    Write-Host ''
}

function Show-MainMenu {
    Clear-Host
    Show-SystemSummary -State $global:state -PackageList $global:packages
    Show-UsageGuide

    Write-Host 'Main menu:' -ForegroundColor Yellow
    Write-Host '  [1] Install tools (select with Space, Enter starts)' -ForegroundColor Green
    Write-Host '  [2] Remove installed tools (select with Space, Enter starts)' -ForegroundColor Red
    Write-Host '  [3] Update ALL installed tools' -ForegroundColor Cyan
    Write-Host '  [4] Refresh installed-tools detection' -ForegroundColor White
    Write-Host '  [5] Exit' -ForegroundColor Gray
    Write-Host ''

    return (Read-Host 'Enter choice (1-5)')
}

function Show-SelectionMenu {
    param(
        [array]$PackageList,
        [string]$Title,
        [string]$ActionLabel,
        [switch]$OnlyInstalledSelectable
    )

    if (-not $PackageList -or $PackageList.Count -eq 0) {
        return @()
    }

    $currentIndex = 0

    while ($true) {
        Clear-Host
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Controls: UP/DOWN move, SPACE toggle, A toggle all, ENTER start, ESC cancel' -ForegroundColor Gray
        Write-Host ''

        for ($i = 0; $i -lt $PackageList.Count; $i++) {
            $pkg = $PackageList[$i]
            $prefix = if ($i -eq $currentIndex) { '>' } else { ' ' }
            $check = if ($pkg.Selected) { '[x]' } else { '[ ]' }
            $status = if ($pkg.Installed) { 'installed' } else { 'not installed' }

            $isLocked = $OnlyInstalledSelectable -and (-not $pkg.Installed)
            $line = "$prefix $check $($pkg.DisplayName) - $($pkg.Description) ($status)"

            if ($isLocked) {
                if ($pkg.Selected) { $pkg['Selected'] = $false }
                Write-Host "$line [locked]" -ForegroundColor DarkGray
            } elseif ($i -eq $currentIndex) {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line
            }
        }

        Write-Host ''
        $selectedCount = @($PackageList | Where-Object { $_.Selected }).Count
        Write-Host "Selected: $selectedCount / $($PackageList.Count)" -ForegroundColor Cyan
        Write-Host "Press ENTER to start: $ActionLabel" -ForegroundColor Yellow

        $key = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { # Up
                $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $PackageList.Count - 1 }
            }
            40 { # Down
                $currentIndex = if ($currentIndex -lt ($PackageList.Count - 1)) { $currentIndex + 1 } else { 0 }
            }
            32 { # Space
                $pkg = $PackageList[$currentIndex]
                $canToggle = (-not $OnlyInstalledSelectable) -or $pkg.Installed
                if ($canToggle) {
                    $pkg['Selected'] = -not $pkg.Selected
                }
            }
            65 { # A
                $selectable = @($PackageList | Where-Object { (-not $OnlyInstalledSelectable) -or $_.Installed })
                if ($selectable.Count -eq 0) { break }

                $allSelected = ($selectable | Where-Object { $_.Selected }).Count -eq $selectable.Count
                foreach ($item in $selectable) {
                    $item['Selected'] = -not $allSelected
                }
            }
            13 { # Enter
                return @($PackageList | Where-Object { $_.Selected })
            }
            27 { # Esc
                return $null
            }
        }
    }
}

function Invoke-PackageInstall {
    param([hashtable]$Package)

    if ($Package.CustomInstall) {
        switch ($Package.Name) {
            'testmem5' { Install-TestMem5; return }
            'cinebench-r23' { Install-CinebenchR23; return }
        }
    }

    Write-Host "Installing $($Package.Name)..." -ForegroundColor Cyan
    choco install $Package.Name -y --no-progress | Out-Host
    Create-DesktopShortcutForPackage -PackageName $Package.Name
    Write-Host ''
}

function Invoke-PackageUninstall {
    param([hashtable]$Package)

    if ($Package.CustomInstall) {
        switch ($Package.Name) {
            'testmem5' { Uninstall-TestMem5; return }
            'cinebench-r23' { Uninstall-CinebenchR23; return }
        }
    }

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Cannot uninstall $($Package.Name): Chocolatey not found." -ForegroundColor Yellow
        return
    }

    Write-Host "Uninstalling $($Package.Name)..." -ForegroundColor Cyan
    choco uninstall $Package.Name -y --no-progress | Out-Host
    Remove-DesktopShortcutForPackage -PackageName $Package.Name
    Write-Host ''
}

function Invoke-InstallSelected {
    param([array]$SelectedPackages)

    if (-not $SelectedPackages -or $SelectedPackages.Count -eq 0) {
        Write-Host 'No tools selected for installation.' -ForegroundColor Yellow
        return
    }

    Ensure-Chocolatey

    Write-Host ''
    Write-Host 'Starting installation...' -ForegroundColor Yellow
    Write-Host ''

    foreach ($pkg in $SelectedPackages) {
        Invoke-PackageInstall -Package $pkg
    }

    Write-Host 'Installation complete.' -ForegroundColor Green
}

function Invoke-UninstallSelected {
    param([array]$SelectedPackages)

    if (-not $SelectedPackages -or $SelectedPackages.Count -eq 0) {
        Write-Host 'No tools selected for removal.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host 'Starting removal...' -ForegroundColor Yellow
    Write-Host ''

    foreach ($pkg in $SelectedPackages) {
        Invoke-PackageUninstall -Package $pkg
    }

    Write-Host 'Removal complete.' -ForegroundColor Green
}

function Invoke-UpdateAllInstalled {
    param([array]$PackageList)

    $installedPackages = @($PackageList | Where-Object { $_.Installed })
    if ($installedPackages.Count -eq 0) {
        Write-Host 'No managed tools are installed. Nothing to update.' -ForegroundColor Yellow
        return
    }

    Write-Host 'This will update all currently installed managed tools.' -ForegroundColor Yellow
    $confirm = Read-Host "Type YES to continue"
    if ($confirm -ne 'YES') {
        Write-Host 'Update canceled.' -ForegroundColor Yellow
        return
    }

    $chocoTargets = @($installedPackages | Where-Object { -not $_.CustomInstall } | ForEach-Object { $_.Name })
    $customTargets = @($installedPackages | Where-Object { $_.CustomInstall })

    if ($chocoTargets.Count -gt 0) {
        Ensure-Chocolatey
        Write-Host ''
        Write-Host 'Updating Chocolatey-managed tools...' -ForegroundColor Cyan
        choco upgrade @chocoTargets -y --no-progress | Out-Host
    }

    if ($customTargets.Count -gt 0) {
        Write-Host ''
        Write-Host 'Reinstalling custom tools to latest script-supported versions...' -ForegroundColor Cyan
        foreach ($pkg in $customTargets) {
            Invoke-PackageInstall -Package $pkg
        }
    }

    Write-Host 'Update-all complete.' -ForegroundColor Green
}

function Update-StateAfterAction {
    param(
        [hashtable]$State,
        [string]$Action,
        [array]$PackageList
    )

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if (-not $State.FirstRun) {
        $State['FirstRun'] = $now
    }

    $State['Version'] = $scriptVersion
    $State['ComputerName'] = $env:COMPUTERNAME
    $State['LastRun'] = $now
    $State['LastAction'] = $Action
    $State['RunCount'] = [int]$State['RunCount'] + 1
    $State['LastKnownInstalled'] = @($PackageList | Where-Object { $_.Installed } | ForEach-Object { $_.Name })
}

# Runtime
Ensure-StateDirectory
$state = Load-InstallerState
Refresh-PackageInstallStatus -PackageList $packages -Reason 'Initial startup'

:MainMenuLoop while ($true) {
    $choice = Show-MainMenu

    switch ($choice) {
        '1' {
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Preparing install menu'
            foreach ($pkg in $packages) {
                $pkg['Selected'] = $pkg.DefaultInstall -and (-not $pkg.Installed)
            }

            $selected = Show-SelectionMenu -PackageList $packages -Title 'Install Tools' -ActionLabel 'Install selected tools'
            if ($null -eq $selected) {
                continue
            }

            Clear-Host
            Invoke-InstallSelected -SelectedPackages $selected
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Verifying installed tools after installation'
            Update-StateAfterAction -State $state -Action 'install' -PackageList $packages
            Save-InstallerState -State $state

            Write-Host ''
            Write-Host 'Press any key to return to main menu...' -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        '2' {
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Preparing remove menu'
            $installedOnly = @($packages | Where-Object { $_.Installed })

            if ($installedOnly.Count -eq 0) {
                Write-Host 'No managed installed tools found to remove.' -ForegroundColor Yellow
                Write-Host 'Press any key to continue...' -ForegroundColor Yellow
                $null = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                continue
            }

            foreach ($pkg in $installedOnly) {
                $pkg['Selected'] = $true
            }

            $selected = Show-SelectionMenu -PackageList $installedOnly -Title 'Remove Installed Tools' -ActionLabel 'Remove selected tools' -OnlyInstalledSelectable
            if ($null -eq $selected) {
                continue
            }

            Clear-Host
            Invoke-UninstallSelected -SelectedPackages $selected
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Verifying installed tools after removal'
            Update-StateAfterAction -State $state -Action 'remove' -PackageList $packages
            Save-InstallerState -State $state

            Write-Host ''
            Write-Host 'Press any key to return to main menu...' -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        '3' {
            Clear-Host
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Collecting installed tools before update-all'
            Invoke-UpdateAllInstalled -PackageList $packages
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Verifying installed tools after update-all'
            Update-StateAfterAction -State $state -Action 'update-all' -PackageList $packages
            Save-InstallerState -State $state

            Write-Host ''
            Write-Host 'Press any key to return to main menu...' -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        '4' {
            Refresh-PackageInstallStatus -PackageList $packages -Reason 'Manual refresh from main menu'
        }
        '5' {
            Write-Host 'Exiting.' -ForegroundColor Yellow
            break MainMenuLoop
        }
        default {
            Write-Host 'Invalid choice. Use 1-5.' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
