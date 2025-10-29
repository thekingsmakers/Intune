# GitHub Repository Setup Guide

## Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click the "+" icon → "New repository"
3. Repository name: `Intune` (or your preferred name)
4. Make it **Public** (so bootstrap can download files)
5. **Do NOT** initialize with README (we'll upload our own)
6. Click "Create repository"

## Step 2: Upload Files to GitHub

### Option A: Git Upload (Recommended for developers)

```bash
# Initialize git repository (if not already done)
cd "d:\Projects\Intune"
git init
git add .
git commit -m "Initial commit - THE KINGSMAKERS WINAPP TOOL"

# Add GitHub remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/thekingsmakers/Intune.git
git push -u origin main
```

### Option B: Manual Upload via GitHub Web Interface

1. Go to your repository: `https://github.com/thekingsmakers/Intune`
2. Click "Add file" → "Upload files"
3. Upload these files:
   - `bootstrap.ps1` (most important - this is what users download!)
   - `THEKINGSMAKERS-WINAPP-TOOL-MONOLITHIC.ps1`
   - `Utils.ps1`
   - `Aliases.ps1`
   - `PackageManagers.ps1`
   - `Detection.ps1`
   - `Winget.ps1`
   - `Chocolatey.ps1`
   - `Install.ps1`
   - `Uninstall.ps1`
   - `Upgrade.ps1`
   - `package-aliases.json`
   - `README.md`
   - Documentation files (optional)

## Step 3: Update Bootstrap Script with Your GitHub URLs

Edit `bootstrap.ps1` and update the GitHub details AND the specific raw URLs:

```powershell
# UPDATE THESE FOR YOUR REPO
$GitHubUser = "thekingsmakers"
$Repository = "Intune"
$Branch = "main"
$Folder = "TKM-WinAppInstaller/"

# UPDATE THESE URLs WITH YOUR ACTUAL RAW GITHUB URLs
$moduleUrls = @{
    "Utils" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Utils.ps1"
    "Aliases" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Aliases.ps1"
    "PackageManagers" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/PackageManagers.ps1"
    "Detection" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Detection.ps1"
    "Winget" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Winget.ps1"
    "Chocolatey" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Chocolatey.ps1"
    "Install" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Install.ps1"
    "Uninstall" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Uninstall.ps1"
    "Upgrade" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Upgrade.ps1"
    "AliasesJson" = "https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/package-aliases.json"
}
```

### How to Get Your Raw URLs:

1. Upload all files to GitHub first
2. Go to each file in GitHub web interface
3. Click "Raw" button
4. Copy the URL from address bar
5. Replace the placeholder URLs above

Example URLs:
```
https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Utils.ps1
https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/Install.ps1
https://raw.githubusercontent.com/thekingsmakers/Intune/99a94c74ed6b956336ef47868ac41909872cb23f/TKM-WinAppInstaller/package-aliases.json
```

## Step 4: Create Release

1. Go to your repository → "Releases" → "Create a new release"
2. Tag version: `v1.0.0`
3. Release title: `THE KINGSMAKERS WINAPP TOOL v1.0.0`
4. Description:
   ```
   Initial release of THE KINGSMAKERS WINAPP TOOL

   ## Quick Start
   1. Download `bootstrap.ps1`
   2. Run: `.\bootstrap.ps1 -List`

   ## Features
   - Advanced package management with intelligent fallbacks
   - Automatic module downloading from GitHub
   - Cross-platform package manager support
   - Professional branding and comprehensive logging
   ```
5. **Attach `bootstrap.ps1`** as a release asset
6. Publish release

## Step 5: Test the Bootstrap

### Local Testing (before GitHub)
```powershell
# Test bootstrap locally (simulates GitHub download)
.\bootstrap.ps1 -List
```

### GitHub Testing (after upload)
```powershell
# Download from your GitHub and test
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/thekingsmakers/Intune/main/TKM-WinAppInstaller/bootstrap.ps1" -OutFile "bootstrap-test.ps1"
.\bootstrap-test.ps1 -List
```

## Step 6: Update Documentation Links

Update any links in documentation to point to your repository:
- `README.md`
- Any other documentation files

## File Structure After Upload

Your GitHub repository should look like this:

```
thekingsmakers/Intune/
├── TKM-WinAppInstaller/
│   ├── bootstrap.ps1                           # ⭐ MAIN FILE - What users download
│   ├── THEKINGSMAKERS-WINAPP-TOOL-MONOLITHIC.ps1
│   ├── Utils.ps1
│   ├── Aliases.ps1
│   ├── PackageManagers.ps1
│   ├── Detection.ps1
│   ├── Winget.ps1
│   ├── Chocolatey.ps1
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   ├── Upgrade.ps1
│   ├── package-aliases.json
│   └── README.md                               # Repository documentation
└── docs/                                   # Additional documentation
```

## Important Notes

### Repository Visibility
- **Must be PUBLIC** for bootstrap to download files
- Users need internet access to download modules

### File Naming
- Keep file names exactly as they are
- Bootstrap script looks for specific filenames

### Version Control
- Use releases for version management
- Tag important versions (v1.0.0, v1.1.0, etc.)

### Security
- Bootstrap downloads from `raw.githubusercontent.com`
- Users should verify file integrity if concerned
- Consider code signing for enterprise use

## User Distribution

Tell users to:

1. **Download**: `bootstrap.ps1` from your GitHub releases
2. **Run**: `.\bootstrap.ps1 -List` (first time downloads modules)
3. **Use**: All commands work normally after initial download

## Example User Workflow

```powershell
# Download bootstrap.ps1 from the repository
# Run with any command - it will download required modules automatically
.\bootstrap.ps1 -List
.\bootstrap.ps1 -Install vscode
.\bootstrap.ps1 -Uninstall chrome
```

## Maintenance

### Updating Modules
1. Update local files
2. Test thoroughly
3. Commit and push to GitHub
4. Create new release

### Bootstrap Updates
- `bootstrap.ps1` rarely changes (only if download logic needs updates)
- Most updates happen in the module files

## Troubleshooting Repository Issues

### "File not found" errors
- Check repository name matches exactly in bootstrap script
- Ensure files are in root directory (not in subfolders)
- Verify repository is public

### "Access denied" errors
- Repository must be public for raw file access
- Check GitHub status (may be temporary outage)

### Bootstrap not working
- Test raw URLs directly: `https://raw.githubusercontent.com/YOUR_USERNAME/WinAppInstaller/main/Utils.ps1`
- Verify branch name (main vs master)

## Success Checklist

- ✅ Repository created and public
- ✅ All files uploaded to correct locations
- ✅ `bootstrap.ps1` updated with correct GitHub info
- ✅ Release created with `bootstrap.ps1` attached
- ✅ Local testing passes
- ✅ README.md provides clear instructions
- ✅ Raw GitHub URLs are accessible

**Once complete, users can download one file and have full access to your Windows package management tool!** 🚀

---

*Created by thekingsmakers | Setup complete when users can run `.\bootstrap.ps1 -List` successfully*
