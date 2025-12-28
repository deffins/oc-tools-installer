# OC Tools Installer

One-command installation script for essential overclocking and benchmarking tools on Windows.

## Quick Install

Run this command in PowerShell as Administrator:

```powershell
irm fons.lv/oc-tools/install.ps1 | iex
```

## What It Does

This script provides an interactive menu to install the following tools via Chocolatey:

- **HWiNFO** - Hardware monitoring and diagnostics
- **Prime95** - CPU stress testing
- **OCCT** - CPU/GPU/RAM stability testing

## Features

- Interactive menu with arrow key navigation
- Select which tools to install
- Automatic Chocolatey installation if not present
- Clean, user-friendly interface

## Manual Installation

If you prefer to review the script first:

```powershell
# Download the script
Invoke-WebRequest -Uri "https://fons.lv/oc-tools/install.ps1" -OutFile "install.ps1"

# Review it
notepad install.ps1

# Run it (as Administrator)
.\install.ps1
```

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection

## How to Use

1. Right-click PowerShell and select "Run as Administrator"
2. Paste the install command
3. Use arrow keys to navigate the menu
4. Press SPACE or ENTER to toggle tool selection
5. Navigate to "START INSTALLATION" and press ENTER
6. Wait for installation to complete

## Development

View the source on GitHub: https://github.com/deffins/oc-tools-installer

### Local Testing

```powershell
.\install.ps1
```

### Deployment

This repository uses GitHub Actions to automatically deploy to the web server via FTP on every push to the main branch.

## License

MIT License - Feel free to use and modify as needed.
