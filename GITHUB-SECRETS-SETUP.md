# GitHub Secrets Setup

## Quick Fix: Add Secrets to This Repository

Since you already have FTP credentials from another project, you need to add them to THIS repository.

### Steps:

1. Go to your repository: `https://github.com/YOUR_USERNAME/oc-tools-installer`

2. Click **Settings** (top menu)

3. In the left sidebar, click **Secrets and variables** → **Actions**

4. Click **New repository secret** (green button)

5. Add these THREE secrets:

   **Secret 1: FTP_SERVER**
   - Click "New repository secret"
   - Name: `FTP_SERVER`
   - Secret: Your FTP server - **JUST the hostname or IP, NO protocol prefix**
     - ✅ Correct: `fons.lv` or `45.84.207.147`
     - ❌ Wrong: `ftp://fons.lv` or `ftp://45.84.207.147`
   - Click "Add secret"

   **Secret 2: FTP_USERNAME**
   - Click "New repository secret"
   - Name: `FTP_USERNAME`
   - Secret: Your FTP username
   - Click "Add secret"

   **Secret 3: FTP_PASSWORD**
   - Click "New repository secret"
   - Name: `FTP_PASSWORD`
   - Secret: Your FTP password
   - Click "Add secret"

### After Adding Secrets:

1. Go to **Actions** tab
2. Click on the failed workflow run
3. Click **Re-run all jobs** (top right)

OR just make a small change and push again:

```powershell
git commit --allow-empty -m "Trigger deployment after adding secrets"
git push
```

---

## Alternative: Use Organization Secrets (if applicable)

If you have a GitHub organization and want to share secrets across repositories:

1. Go to your organization settings
2. **Secrets and variables** → **Actions**
3. Click **New organization secret**
4. Select which repositories can access it

This way you only manage secrets in one place!
