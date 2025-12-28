# Setup Guide

This guide will help you set up the automatic deployment from GitHub to your Hostinger server.

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `oc-tools-installer` (or whatever you prefer)
3. Description: "One-command installer for overclocking and benchmarking tools"
4. Set to **Public**
5. **Do NOT** initialize with README (we already have one)
6. Click "Create repository"

## Step 2: Get Your Hostinger FTP Credentials

1. Log in to your Hostinger panel
2. Go to **Files** → **FTP Accounts**
3. You'll need:
   - **FTP Server/Host**: Usually something like `ftp.fons.lv` or an IP address
   - **FTP Username**: Your FTP username
   - **FTP Password**: Your FTP password

## Step 3: Add GitHub Secrets

1. In your GitHub repository, go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these three secrets:

   **Secret 1:**
   - Name: `FTP_SERVER`
   - Value: Your FTP server address (e.g., `ftp.fons.lv` or IP address)

   **Secret 2:**
   - Name: `FTP_USERNAME`
   - Value: Your FTP username

   **Secret 3:**
   - Name: `FTP_PASSWORD`
   - Value: Your FTP password

## Step 4: Verify FTP Path

The GitHub Action is configured to upload to `/public_html/oc-tools/`

Check if this path is correct for your Hostinger setup:
- Log in via FTP client (FileZilla, WinSCP, etc.)
- Navigate to where you want the files
- If the path is different, update it in `.github/workflows/deploy.yml` on line 20

Common Hostinger paths:
- `/public_html/oc-tools/` (most common)
- `/domains/fons.lv/public_html/oc-tools/`
- `/home/username/public_html/oc-tools/`

## Step 5: Push to GitHub

Run these commands in PowerShell (in the project directory):

```powershell
# Set your GitHub username
$username = "YOUR_GITHUB_USERNAME"

# Add all files
git add .

# Create first commit
git commit -m "Initial commit: OC Tools Installer"

# Add remote repository (replace YOUR_GITHUB_USERNAME)
git remote add origin "https://github.com/$username/oc-tools-installer.git"

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

## Step 6: Verify Deployment

1. After pushing, go to your GitHub repository
2. Click the **Actions** tab
3. You should see a workflow running called "Deploy to Hostinger"
4. Wait for it to complete (green checkmark)
5. Visit `https://fons.lv/oc-tools/` to see your landing page
6. Test the installer: `irm fons.lv/oc-tools/install.ps1 | iex`

## Troubleshooting

### FTP Connection Failed
- Double-check FTP server address in GitHub secrets
- Verify FTP username and password
- Check if Hostinger requires FTP or FTPS (port 21 vs 990)
- Some hosts use SFTP instead - you may need a different GitHub Action

### Files Not Appearing
- Check the `server-dir` path in `.github/workflows/deploy.yml`
- Verify permissions on your Hostinger folder
- Check GitHub Actions logs for errors

### PowerShell Script Won't Download
- Ensure `install.ps1` was uploaded
- Check file permissions (should be readable)
- Try accessing directly: `https://fons.lv/oc-tools/install.ps1`

## Future Updates

After initial setup, just commit and push changes:

```powershell
git add .
git commit -m "Update description of changes"
git push
```

GitHub Actions will automatically deploy to your server!

## Need Help?

- Check GitHub Actions logs: Repository → Actions → Latest workflow
- Verify FTP credentials in Hostinger panel
- Test FTP connection with FileZilla or WinSCP first
