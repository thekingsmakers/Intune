<#
.SYNOPSIS
    GitHub Profile README Auto-Deployment Script
    
.DESCRIPTION
    Automatically generates and deploys an updated GitHub profile README with live repository metrics.
    Fetches real-time data from GitHub API and updates the README file with current statistics.
    
.PARAMETER Owner
    GitHub repository owner username (required)
    
.PARAMETER Repo
    GitHub repository name (required)
    
.PARAMETER AutoCommit
    Automatically commit and push changes to the branch (optional)
    
.PARAMETER CommitMessage
    Custom commit message (default: 'docs: Update README with latest metrics')
    
.PARAMETER Branch
    Target branch for deployment (default: 'profile-update')
    
.PARAMETER LogLevel
    Logging verbosity: 'Minimal', 'Normal', 'Verbose' (default: 'Normal')
    
.EXAMPLE
    $env:GITHUB_TOKEN = 'ghp_your_token_here'
    .\Deploy-ProfileREADME.ps1 -Owner 'thekingsmakers' -Repo 'Intune' -AutoCommit
    
.EXAMPLE
    .\Deploy-ProfileREADME.ps1 -Owner 'thekingsmakers' -Repo 'Intune' -LogLevel Verbose
    
.NOTES
    Requires: PowerShell 7.0+, Git, GitHub CLI (gh)
    Environment: GITHUB_TOKEN (GitHub Personal Access Token)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,
    
    [Parameter(Mandatory=$true)]
    [string]$Repo,
    
    [Parameter()]
    [switch]$AutoCommit,
    
    [Parameter()]
    [string]$CommitMessage = 'docs: Update README with latest metrics',
    
    [Parameter()]
    [string]$Branch = 'profile-update',
    
    [Parameter()]
    [ValidateSet('Minimal', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($LogLevel -eq 'Verbose') { 'Continue' } else { 'SilentlyContinue' }
$ProgressPreference = 'SilentlyContinue'

$scriptStartTime = Get-Date
$logPath = Join-Path $env:TEMP "ProfileREADME_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Color codes for output
$colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Verbose = 'Gray'
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Verbose')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    
    if ($Level -eq 'Verbose' -and $LogLevel -ne 'Verbose') { return }
    
    Write-Host $logEntry -ForegroundColor $colors[$Level]
}

function Write-Progress-Custom {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1
    )
    
    if ($LogLevel -ne 'Minimal') {
        if ($PercentComplete -ge 0) {
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        } else {
            Write-Host "→ $Activity`: $Status" -ForegroundColor Cyan
        }
    }
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-Prerequisites {
    Write-Log "Validating prerequisites..." -Level Info
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "PowerShell 7.0 or higher is required (Current: $($PSVersionTable.PSVersion))" -Level Error
        return $false
    }
    Write-Log "✓ PowerShell version: $($PSVersionTable.PSVersion)" -Level Success
    
    # Check GitHub token
    if (-not $env:GITHUB_TOKEN) {
        Write-Log "GITHUB_TOKEN environment variable not set" -Level Error
        Write-Log "Set token: `$env:GITHUB_TOKEN = 'your_token_here'" -Level Info
        return $false
    }
    Write-Log "✓ GitHub token is set" -Level Success
    
    # Check Git
    $gitPath = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitPath) {
        Write-Log "Git is not installed or not in PATH" -Level Error
        return $false
    }
    Write-Log "✓ Git found: $($gitPath.Source)" -Level Success
    
    return $true
}

# ============================================================================
# GITHUB API FUNCTIONS
# ============================================================================

function Get-RepositoryMetrics {
    param(
        [string]$Owner,
        [string]$Repo
    )
    
    Write-Progress-Custom -Activity "Fetching GitHub Metrics" -Status "Retrieving repository data..."
    
    try {
        $headers = @{
            'Authorization' = "token $($env:GITHUB_TOKEN)"
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo"
        Write-Log "Calling GitHub API: $apiUrl" -Level Verbose
        
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
        
        $metrics = @{
            Stars = $response.stargazers_count
            Watchers = $response.watchers_count
            Forks = $response.forks_count
            OpenIssues = $response.open_issues_count
            Created = $response.created_at
            Updated = $response.updated_at
            LastPush = $response.pushed_at
            Size = $response.size
            Language = $response.language
            Description = $response.description
            Topics = $response.topics
            DefaultBranch = $response.default_branch
        }
        
        Write-Log "✓ Retrieved metrics: $($metrics.Stars) stars, $($metrics.Watchers) watchers" -Level Success
        return $metrics
    }
    catch {
        Write-Log "Failed to fetch repository metrics: $_" -Level Error
        throw
    }
}

function Format-GitHubDate {
    param([string]$DateString)
    
    if (-not $DateString) { return 'Unknown' }
    
    $date = [datetime]::Parse($DateString)
    return $date.ToString('MMMM d, yyyy')
}

# ============================================================================
# README GENERATION FUNCTION
# ============================================================================

function New-ProfileREADME {
    param(
        [hashtable]$Metrics
    )
    
    Write-Progress-Custom -Activity "Generating README" -Status "Creating markdown content..."
    
    $createdDate = Format-GitHubDate -DateString $Metrics.Created
    $updatedDate = Format-GitHubDate -DateString $Metrics.Updated
    $lastPushDate = Format-GitHubDate -DateString $Metrics.LastPush
    $generatedDate = Get-Date -Format 'MMMM d, yyyy HH:mm:ss UTC'
    
    $readme = @"
# 👋 Hello, I'm @thekingsmakers

![TheKingsMakers Banner](https://raw.githubusercontent.com/thekingsmakers/Intune/main/thekingsmakers.png)

**Microsoft Intune & MDM Administrator | PowerShell Automation Expert**

Welcome to my GitHub profile! I'm a dedicated **MDM/Intune Admin** with a passion for automating enterprise IT infrastructure and building scalable solutions for modern device management.

[![Twitter Follow](https://img.shields.io/twitter/follow/thekingsmakers?style=social)](https://twitter.com/thekingsmakers)
[![GitHub followers](https://img.shields.io/github/followers/thekingsmakers?style=social)](https://github.com/thekingsmakers)

---

## 🎓 Certifications & Expertise

**Microsoft Certifications:**
- 🏆 **MD-102** – Windows 11 Endpoint Administrator Certified
- 🏆 **AZ-104** – Azure Administrator Certified  
- 🏆 **AZ-900** – Azure Fundamentals Certified

**Technical Specialization:**
- Microsoft Intune administration & policy management
- PowerShell scripting & automation (96% of repository code)
- Azure integration & cloud services
- Windows device management & deployment
- Conditional Access & security policies
- SCCM co-management scenarios

---

## 🚀 Featured Project: Intune Admin Scripts

![GitHub Stars](https://img.shields.io/github/stars/thekingsmakers/Intune?style=flat-square) ![GitHub Watchers](https://img.shields.io/github/watchers/thekingsmakers/Intune?style=flat-square) ![Last Updated](https://img.shields.io/github/last-commit/thekingsmakers/Intune?style=flat-square)

A comprehensive repository of **production-grade Microsoft Intune administration tools** and scripts. Over **23KB** of enterprise-tested automation, with **96% PowerShell**, **1.5% C#**, and **2.5% other**.

**Repository Stats (as of $generatedDate):**
- ⭐ **$($Metrics.Stars)** Stars
- 👁️ **$($Metrics.Watchers)** Watchers  
- 🔀 **$($Metrics.Forks)** Forks
- 📅 Created: $createdDate
- 📝 Updated: $updatedDate
- ⏱️ Last Push: $lastPushDate
- 📁 **25+ Specialized Modules**
- 💾 Size: $($Metrics.Size) KB

---

## 📂 Quick Access to Repository Folders

### 🔧 **[Application Management](https://github.com/thekingsmakers/Intune/tree/main/Application%20Management)**
Comprehensive tools for managing application lifecycle within Intune.

**What's Inside:**
- Win32 app packaging & deployment scripts
- Application assignment automation
- Update & versioning management
- Uninstall & removal procedures
- Dependency resolution tools
- Silent installation configurators
- Application telemetry & reporting

---

### ☁️ **[Azure](https://github.com/thekingsmakers/Intune/tree/main/Azure)**
Azure integration and cloud management utilities for enterprise environments.

**Key Scripts:**
- **PendingDeviceFix.ps1** – Resolves "Pending" device state
  - Clears AAD Broker Plugin cache
  - Syncs system time with web services
  - Resets authentication tokens

---

### 🚀 **[AutoPilot](https://github.com/thekingsmakers/Intune/tree/main/AutoPilot)**
Windows Autopilot deployment and configuration automation suite.

**5 Essential Scripts:**
- Script1.ps1 – Module deployment preparation
- Script2.ps1 – Hardware hash upload & Teams notifications
- Script3.ps1 – SCCM cleanup & Sysprep
- Script4.ps1 – Enterprise SCCM cleanup (fixed)
- Script5.ps1 – Production-safe cleanup with logging

---

### 🎨 **[BGInfo Refresh](https://github.com/thekingsmakers/Intune/tree/main/Bginforefresh)**
Automated BGInfo wallpaper deployment with scheduled refresh.

**Key Features:**
- System info display on desktop wallpaper
- Auto-refresh on logon, lock, unlock
- Sysinternals BGInfo integration
- Scheduled task automation

---

### 🔐 **[Conditional Access Policies](https://github.com/thekingsmakers/Intune/tree/main/Conditional%20Access%20Policies)**
Microsoft Entra Conditional Access policy templates and enforcement scripts.

---

### 💻 **[Device Management](https://github.com/thekingsmakers/Intune/tree/main/Device%20Managemet)**
Enterprise device registration, monitoring, and remediation tools.

---

### 🖼️ **[Image Deploy](https://github.com/thekingsmakers/Intune/tree/main/ImageDeploy)**
Complete Windows image deployment with GUI configuration and C# components.

**Features:**
- Software package installation
- Hostname configuration
- WiFi setup & domain join
- Windows activation
- Error recovery & rollback

---

### 📦 **[InstallApps](https://github.com/thekingsmakers/Intune/tree/main/InstallApps)**
Bulk application installation and management automation.

---

### 🎛️ **[Intune Management](https://github.com/thekingsmakers/Intune/tree/main/Intune%20Management)**
Core utilities for Intune platform administration.

---

### 🛒 **[Microsoft Store Updates](https://github.com/thekingsmakers/Intune/tree/main/Microsoft%20Store%20Update%20backend)**
Store application update management and backend automation.

---

### 📊 **[Ms Store](https://github.com/thekingsmakers/Intune/tree/main/Ms%20Store)**
Portal availability checker and Microsoft admin portal launcher.

**Key Script: sites.ps1**
- Tests 19+ Microsoft admin portals
- Color-coded status output
- Quick access to all admin centers

---

### 🔄 **[SCCM](https://github.com/thekingsmakers/Intune/tree/main/SCCM)**
SCCM to Intune migration and co-management utilities.

---

### 🎯 **[Scripting](https://github.com/thekingsmakers/Intune/tree/main/Scripting)**
General PowerShell automation utilities and helper scripts.

---

### 🗑️ **[TKM-Uninstaller-V.1](https://github.com/thekingsmakers/Intune/tree/main/TKM-Uninstaller-V.1)**
Custom uninstallation tools for clean application removal.

---

### 💾 **[TKM-WinAppInstaller](https://github.com/thekingsmakers/Intune/tree/main/TKM-WinAppInstaller)**
Advanced Windows application installer with custom deployment logic.

---

### 📝 **[User Handling](https://github.com/thekingsmakers/Intune/tree/main/User%20handling)**
User provisioning, management, and lifecycle automation.

---

### 🪟 **[Windows 10 ESU Activation](https://github.com/thekingsmakers/Intune/tree/main/Windows%2010%20ESU%20Activation-Intune%20Remediation)**
Extended Security Update activation and remediation for Windows 10.

---

### ✔️ **[Intune Scripts Validator](https://github.com/thekingsmakers/Intune/tree/main/intune%20Scripts%20Validator)**
Script validation and compliance checking tools.

---

### 📋 **[Daily Used Snippets](https://github.com/thekingsmakers/Intune/blob/main/DailyUsedSnippets.md)**
Quick reference PowerShell snippets for Intune administration.

---

## 💻 Tech Stack

\`\`\`
Languages:      PowerShell ⭐⭐⭐⭐⭐ | C# ⭐⭐⭐ | Bash ⭐⭐
Platforms:      Microsoft Intune | Azure | Windows Server | SCCM
Tools:          Windows Admin Center | Graph API | Autopilot | Git
Expertise:      IT Administration | Enterprise Automation | Systems Integration
\`\`\`

---

## 📈 Repository Metrics

- **Total Stars:** $($Metrics.Stars)
- **Watchers:** $($Metrics.Watchers)
- **Forks:** $($Metrics.Forks)
- **Code Size:** $($Metrics.Size) KB
- **Open Issues:** $($Metrics.OpenIssues)
- **Primary Language:** PowerShell (96%)
- **Secondary Language:** C# (1.5%)
- **Other:** 2.5%
- **Features:** Discussions, Wiki, Issues, Pull Requests, GitHub Pages enabled
- **Last Updated:** $lastPushDate

---

## 🤝 Contributing

I welcome contributions! If you have:
- 🐛 Bug fixes or improvements
- ✨ New features or scripts
- 📚 Better documentation
- 💡 Alternative solutions

Please:
1. **Fork** the repository
2. **Create** a feature branch
3. **Submit** a pull request
4. **Open** an issue for discussions

---

## 📚 Additional Resources

- 📖 **[Main Repository](https://github.com/thekingsmakers/Intune)** – Explore all scripts
- 🔗 **[Daily Used Snippets](https://github.com/thekingsmakers/Intune/blob/main/DailyUsedSnippets.md)** – Quick reference
- 💬 **[Discussions](https://github.com/thekingsmakers/Intune/discussions)** – Questions & ideas
- 🐞 **[Issues](https://github.com/thekingsmakers/Intune/issues)** – Bug reports & features

---

## 🎯 What I Specialize In

| Area | Details |
|------|---------|
| **Device Management** | Intune enrollment, compliance, configuration, remediation |
| **Application Deployment** | Win32, Store, LOB apps, assignments |
| **Automation** | PowerShell scripting, scheduled tasks, remediation |
| **Cloud Integration** | Azure AD, Conditional Access, hybrid scenarios |
| **Enterprise Solutions** | SCCM co-management, Windows deployment |
| **Security** | Security baselines, compliance, conditional access |

---

## 💡 Current Focus

- 🔍 Expanding Intune automation capabilities
- 📊 Building advanced remediation scripts
- 🚀 Enhancing Windows deployment solutions
- 🔐 Strengthening security policies & compliance
- 📈 Creating community-driven tools

---

## 📬 Connect & Support

| Platform | Link |
|----------|------|
| **Twitter** | [@thekingsmakers](https://twitter.com/thekingsmakers) |
| **GitHub** | [@thekingsmakers](https://github.com/thekingsmakers) |
| **Discussions** | [Repository Discussions](https://github.com/thekingsmakers/Intune/discussions) |
| **Issues** | [Report Issues](https://github.com/thekingsmakers/Intune/issues) |

**Like my work?** Please ⭐ star the [Intune Admin Scripts](https://github.com/thekingsmakers/Intune) repo!

---

## 📜 License & Usage

**Intune Admin Scripts Repository:**
- Scripts provided for IT administrators with proper privileges
- Always test in your environment before production deployment
- Contributions welcome from the community

---

<div align="center">

**Thanks for visiting!** 🙌

*Building enterprise automation, one script at a time.*

![Profile Views](https://komarev.com/ghpvc/?username=thekingsmakers&style=flat-square)

**Generated:** $generatedDate

**[⬆ Back to Top](#)**

</div>
"@

    Write-Log "✓ README generated successfully" -Level Success
    return $readme
}

# ============================================================================
# FILE OPERATIONS FUNCTIONS
# ============================================================================

function Save-FileToRepository {
    param(
        [string]$FilePath,
        [string]$Content
    )
    
    Write-Progress-Custom -Activity "Saving File" -Status "Writing to $FilePath..."
    
    try {
        $Content | Out-File -FilePath $FilePath -Encoding UTF8 -Force
        Write-Log "✓ File saved: $FilePath" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to save file: $_" -Level Error
        return $false
    }
}

function Push-ToGitHub {
    param(
        [string]$CommitMessage,
        [string]$Branch
    )
    
    Write-Progress-Custom -Activity "Publishing Changes" -Status "Committing and pushing..."
    
    try {
        # Check git status
        $status = git status --porcelain 2>&1
        if (-not $status) {
            Write-Log "No changes to commit" -Level Info
            return $true
        }
        
        # Stage changes
        Write-Log "Staging changes..." -Level Verbose
        git add README.md
        
        # Commit
        Write-Log "Committing: $CommitMessage" -Level Verbose
        git commit -m $CommitMessage
        
        # Push
        Write-Log "Pushing to branch: $Branch" -Level Verbose
        git push -u origin $Branch
        
        Write-Log "✓ Changes pushed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to push changes: $_" -Level Error
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-Deployment {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     GitHub Profile README Auto-Deployment Script              ║" -ForegroundColor Cyan
    Write-Host "║              Powered by @thekingsmakers                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Starting deployment process..." -Level Info
    Write-Log "Owner: $Owner | Repo: $Repo | Branch: $Branch" -Level Verbose
    Write-Log "Log file: $logPath" -Level Verbose
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites validation failed" -Level Error
        exit 1
    }
    
    # Fetch metrics
    try {
        $metrics = Get-RepositoryMetrics -Owner $Owner -Repo $Repo
    }
    catch {
        Write-Log "Deployment failed: $_" -Level Error
        exit 1
    }
    
    # Generate README
    $readmeContent = New-ProfileREADME -Metrics $metrics
    
    # Save README
    $readmePath = Join-Path (Get-Location) 'README.md'
    if (-not (Save-FileToRepository -FilePath $readmePath -Content $readmeContent)) {
        Write-Log "Deployment failed" -Level Error
        exit 1
    }
    
    # Optionally push to GitHub
    if ($AutoCommit) {
        if (-not (Push-ToGitHub -CommitMessage $CommitMessage -Branch $Branch)) {
            Write-Log "Failed to push changes, but README was generated" -Level Warning
            exit 1
        }
    }
    
    # Summary
    $duration = (Get-Date) - $scriptStartTime
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                  ✓ Deployment Completed                        ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Log "Deployment completed successfully in $($duration.TotalSeconds)s" -Level Success
    Write-Log "README updated with latest metrics and descriptions" -Level Success
    Write-Host "📋 Log file: $logPath" -ForegroundColor Gray
    Write-Host ""
}

# Run deployment
Start-Deployment
