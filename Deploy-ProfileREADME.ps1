<#
.SYNOPSIS
    Deploy-ProfileREADME.ps1 - Automatically update GitHub profile README with live metrics

.DESCRIPTION
    This script generates and deploys an updated README.md with live GitHub repository metrics.
    It fetches real-time data from GitHub API and updates repository statistics automatically.

.PARAMETER Owner
    GitHub repository owner (e.g., 'thekingsmakers')

.PARAMETER Repo
    GitHub repository name (e.g., 'Intune')

.PARAMETER AutoCommit
    Automatically commit and push changes to repository

.PARAMETER Branch
    Target branch for updates (default: 'profile-update')

.PARAMETER CommitMessage
    Custom commit message (default: auto-generated)

.PARAMETER LogLevel
    Logging verbosity: Quiet, Normal, Verbose (default: Normal)

.EXAMPLE
    $env:GITHUB_TOKEN = 'ghp_your_token'
    .\Deploy-ProfileREADME.ps1 -Owner thekingsmakers -Repo Intune -AutoCommit

.EXAMPLE
    .\Deploy-ProfileREADME.ps1 -Owner thekingsmakers -Repo Intune -LogLevel Verbose

.NOTES
    Requires: PowerShell 7.0+, Git, GitHub CLI (gh), GitHub Personal Access Token
    Author: thekingsmakers
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,
    
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    
    [Parameter()]
    [switch]$AutoCommit,
    
    [Parameter()]
    [string]$Branch = 'profile-update',
    
    [Parameter()]
    [string]$CommitMessage,
    
    [Parameter()]
    [ValidateSet('Quiet', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'
)

#region Initialize
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

$ScriptStartTime = Get-Date
$ScriptVersion = '1.0.0'
$GitHubToken = $env:GITHUB_TOKEN

# Color definitions
$Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Cyan'
    Verbose = 'Gray'
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $Color = $Colors[$Level] ?? 'White'
    $Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    
    if ($LogLevel -eq 'Verbose' -or $Level -ne 'Verbose') {
        Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
    }
}

#endregion

#region Validation
Write-Log "Initializing Deploy-ProfileREADME v$ScriptVersion" -Level Info
Write-Log "Target: $Owner/$Repo (Branch: $Branch)" -Level Info

# Validate GitHub token
if ([string]::IsNullOrEmpty($GitHubToken)) {
    Write-Log "ERROR: GITHUB_TOKEN environment variable not set!" -Level Error
    Write-Log "Set token: `$env:GITHUB_TOKEN = 'your_token'" -Level Info
    exit 1
}

# Validate prerequisites
$Prerequisites = @('git', 'gh')
foreach ($Cmd in $Prerequisites) {
    if (!(Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Log "ERROR: '$Cmd' not found. Install and add to PATH." -Level Error
        exit 1
    }
}

Write-Log "All prerequisites validated" -Level Success

#endregion

#region GitHub API
function Get-GitHubRepoMetrics {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Token
    )
    
    Write-Log "Fetching repository metrics from GitHub API..." -Level Verbose
    
    $Headers = @{
        'Authorization' = "token $Token"
        'Accept'        = 'application/vnd.github.v3+json'
    }
    
    try {
        $Uri = "https://api.github.com/repos/$Owner/$Repo"
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
        
        return @{
            Stars              = $Response.stargazers_count
            Watchers           = $Response.watchers_count
            Forks              = $Response.forks_count
            OpenIssues         = $Response.open_issues_count
            CreatedAt          = $Response.created_at
            UpdatedAt          = $Response.updated_at
            PushedAt           = $Response.pushed_at
            Size               = [math]::Round($Response.size / 1024, 1)
            Description        = $Response.description
            Language           = $Response.language
            Topics             = $Response.topics -join ', '
        }
    }
    catch {
        Write-Log "ERROR fetching metrics: $_" -Level Error
        exit 1
    }
}

#endregion

#region README Generation
function New-ProfileREADME {
    param(
        [hashtable]$Metrics
    )
    
    Write-Log "Generating profile README with live metrics..." -Level Verbose
    
    $CreatedDate = [datetime]::Parse($Metrics.CreatedAt).ToString('MMMM dd, yyyy')
    $UpdatedDate = [datetime]::Parse($Metrics.UpdatedAt).ToString('MMMM dd, yyyy')
    $PushedDate  = [datetime]::Parse($Metrics.PushedAt).ToString('MMMM dd, yyyy')
    $GeneratedAt = (Get-Date).ToString('MMMM dd, yyyy HH:mm:ss')
    
    $README = @"
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
- PowerShell scripting & automation (96% of my work)
- Azure integration & cloud services
- Windows device management & deployment
- Conditional Access & security policies
- SCCM co-management scenarios

---

## 🚀 Featured Project: Intune Admin Scripts

![GitHub Stars](https://img.shields.io/github/stars/thekingsmakers/Intune?style=flat-square) ![GitHub Watchers](https://img.shields.io/github/watchers/thekingsmakers/Intune?style=flat-square) ![Last Updated](https://img.shields.io/github/last-commit/thekingsmakers/Intune?style=flat-square)

A comprehensive repository of **production-grade Microsoft Intune administration tools** and scripts. Enterprise-tested automation with **96% PowerShell**, **1.5% C#**, and **2.5% other**.

**Live Repository Stats (Updated: $GeneratedAt):**
- ⭐ **$($Metrics.Stars)** Stars | 👁️ **$($Metrics.Watchers)** Watchers | 🔀 **$($Metrics.Forks)** Forks
- 📅 Created: $CreatedDate | Updated: $UpdatedDate | Pushed: $PushedDate
- 💾 **$($Metrics.Size) KB** | 🔴 **$($Metrics.OpenIssues)** Open Issues
- 📁 **25+ Specialized Modules** | 📊 **96% PowerShell**

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

**Use Cases:** Deploy applications at scale, automate updates, manage groups, track compliance

---

### ☁️ **[Azure](https://github.com/thekingsmakers/Intune/tree/main/Azure)**
Azure integration and cloud management utilities for enterprise environments.

**Key Scripts:**
- **PendingDeviceFix.ps1** – Resolves "Pending" device state during Azure AD join
  - Clears AAD Broker Plugin cache
  - Syncs system time with web services
  - Resets authentication tokens
  - Fixes device registration issues

**Use Cases:** Fix stuck Azure AD joins, resolve pending states, troubleshoot cloud connectivity

---

### 🚀 **[AutoPilot](https://github.com/thekingsmakers/Intune/tree/main/AutoPilot)**
Windows Autopilot deployment and configuration automation suite.

**Key Scripts:**
- **Script1.ps1** – Copies PowerShell modules to Program Files
- **Script2.ps1** – Autopilot device hash registration with Teams notifications
- **Script3.ps1** – SCCM cleanup & Sysprep for Autopilot transition
- **Script4.ps1** – Enterprise SCCM cleanup (v1)
- **Script5.ps1** – Production-safe SCCM cleanup (v2)

**Use Cases:** Automate Autopilot uploads, migrate from SCCM, prepare devices for re-imaging

---

### 🎨 **[BGInfo Refresh](https://github.com/thekingsmakers/Intune/tree/main/Bginforefresh)**
Automated BGInfo wallpaper deployment with scheduled refresh via Intune.

**How It Works:**
1. Deploys to \`C:\ProgramData\BginfoRefresh\`
2. Creates scheduled task "BGInfo User Refresh"
3. Runs on: User Logon, Session Lock, Session Unlock
4. Displays system info on wallpaper automatically

**Use Cases:** Display device info on desktop, automated helpdesk reference, consistent branding

---

### 🔐 **[Conditional Access Policies](https://github.com/thekingsmakers/Intune/tree/main/Conditional%20Access%20Policies)**
Templates and enforcement scripts for Microsoft Entra Conditional Access policies.

**What's Inside:** Policy templates, risk-based controls, MFA enforcement, location-based policies, legacy auth blocking

**Use Cases:** Enforce MFA, block legacy authentication, require compliant devices, manage risky sign-ins

---

### 💻 **[Device Management](https://github.com/thekingsmakers/Intune/tree/main/Device%20Managemet)**
Enterprise device registration, monitoring, and remediation tools.

**What's Inside:** Enrollment automation, compliance checking, remediation scripts, inventory collection, health monitoring

**Use Cases:** Monitor compliance, deploy remediation, collect inventory, enroll at scale, track health

---

### 🖼️ **[Image Deploy](https://github.com/thekingsmakers/Intune/tree/main/ImageDeploy)**
Complete Windows image deployment solution with GUI configuration and C# components.

**Features:**
- Software package installation from USB
- Hostname configuration automation
- WiFi setup & connection management
- Windows product activation
- Optional Windows features installation
- Domain join automation

**Use Cases:** Deploy Windows 10/11, configure systems, bulk setup, zero-touch deployment

---

### 📦 **[InstallApps](https://github.com/thekingsmakers/Intune/tree/main/InstallApps)**
Bulk application installation and management automation scripts.

**What's Inside:** Silent installation scripts, batch orchestration, logging, error handling, version management

**Use Cases:** Deploy standard app sets, automate installations, verify deployments, clean up failures

---

### 🎛️ **[Intune Management](https://github.com/thekingsmakers/Intune/tree/main/Intune%20Management)**
Core utilities and administrative tools for Intune platform management.

**What's Inside:** Graph API scripts, policy management, device groups, enrollment profiles, reporting utilities

**Use Cases:** Automate policy management, bulk operations, generate reports, configure profiles

---

### 🛒 **[Microsoft Store Updates](https://github.com/thekingsmakers/Intune/tree/main/Microsoft%20Store%20Update%20backend)**
Microsoft Store application update management and backend automation.

**What's Inside:** Update policies, scheduling automation, version management, deployment scripts, inventory tools

**Use Cases:** Manage Store app updates, deploy apps, control timing, track versions

---

### 📊 **[Ms Store](https://github.com/thekingsmakers/Intune/tree/main/Ms%20Store)**
Microsoft Store portal launchers and management utilities.

**Key Scripts:**
- **sites.ps1** – Tests connectivity to 19+ Microsoft admin portals
  - Entra ID, Azure, Intune, Exchange, Teams, Defender, SharePoint, and more
  - Color-coded status output (Green=Up, Red=Down)
  - Quick portal access launcher

**Use Cases:** Verify portal availability, troubleshoot connectivity, quick access, monitor service health

---

### 🔄 **[SCCM](https://github.com/thekingsmakers/Intune/tree/main/SCCM)**
System Center Configuration Manager co-management and integration utilities.

**What's Inside:** Migration scripts, co-management config, client uninstall, cleanup utilities, enrollment acceleration

**Use Cases:** Migrate from SCCM to Intune, enable co-management, remove legacy clients, transition workloads

---

### 🎯 **[Scripting](https://github.com/thekingsmakers/Intune/tree/main/Scripting)**
General PowerShell automation utilities and helper scripts.

**What's Inside:** PowerShell functions, utility scripts, automation templates, integration helpers, troubleshooting utilities

**Use Cases:** Reusable components, quick utilities, common automation, IT administration helpers

---

### 🗑️ **[TKM-Uninstaller-V.1](https://github.com/thekingsmakers/Intune/tree/main/TKM-Uninstaller-V.1)**
Custom uninstallation tools for managing application removal.

**What's Inside:** Clean uninstall scripts, registry cleanup, file cleanup, verification, rollback capabilities

**Use Cases:** Remove applications cleanly, clean registry, verify completion

---

### 💾 **[TKM-WinAppInstaller](https://github.com/thekingsmakers/Intune/tree/main/TKM-WinAppInstaller)**
Advanced Windows application installer with custom deployment logic.

**What's Inside:** Packaging utilities, verification, rollback, custom logic, version management

**Use Cases:** Deploy complex apps, custom installation logic, application packaging

---

### 📝 **[User Handling](https://github.com/thekingsmakers/Intune/tree/main/User%20handling)**
User provisioning, management, and lifecycle automation scripts.

**What's Inside:** Onboarding automation, account creation, group management, license assignment, offboarding

**Use Cases:** Automate onboarding, manage groups, assign licenses, execute offboarding

---

### 🪟 **[Windows 10 ESU Activation](https://github.com/thekingsmakers/Intune/tree/main/Windows%2010%20ESU%20Activation-Intune%20Remediation)**
Extended Security Update activation and remediation scripts for Windows 10.

**What's Inside:** License key management, activation verification, eligibility checking, remediation, reporting

**Use Cases:** Activate ESU, verify status, remediate failures, track eligibility

---

### ✔️ **[Intune Scripts Validator](https://github.com/thekingsmakers/Intune/tree/main/intune%20Scripts%20Validator)**
Validation and compliance checking tools for Intune deployment scripts.

**What's Inside:** Syntax validation, compliance checking, best practices verification, error detection, optimization

**Use Cases:** Validate scripts, check compliance, verify security, test syntax

---

### 📋 **[Daily Used Snippets](https://github.com/thekingsmakers/Intune/blob/main/DailyUsedSnippets.md)**
Quick reference PowerShell snippets for common Intune administration tasks.

**What's Inside:** Copy-paste solutions, command patterns, one-liners, API examples, device queries

**Use Cases:** Quick reference, common automation, API integration, daily administration

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
- **Primary Language:** PowerShell (96%)
- **Secondary Language:** C# (1.5%)
- **Other:** 2.5%
- **Open Issues:** $($Metrics.OpenIssues)
- **Features:** Discussions, Wiki, Issues, Pull Requests, GitHub Pages enabled
- **Last Commit:** $PushedDate

---

## 🤝 Contributing

I welcome contributions to improve these scripts! If you have:
- 🐛 Bug fixes or improvements
- ✨ New features or scripts
- 📚 Better documentation
- 💡 Alternative solutions

Please feel free to:
1. **Fork** the repository
2. **Create** a feature branch
3. **Submit** a pull request
4. **Open** an issue for discussions

---

## 📚 Additional Resources

- 📖 **[Main Repository](https://github.com/thekingsmakers/Intune)** – Explore all scripts
- 🔗 **[Daily Used Snippets](https://github.com/thekingsmakers/Intune/blob/main/DailyUsedSnippets.md)** – Quick reference code
- 💬 **[Discussions](https://github.com/thekingsmakers/Intune/discussions)** – Ask questions & share ideas
- 🐞 **[Issues](https://github.com/thekingsmakers/Intune/issues)** – Report bugs or request features

---

## 🎯 What I Specialize In

| Area | Details |
|------|---------|
| **Device Management** | Intune enrollment, compliance policies, device configuration, remediation |
| **Application Deployment** | Win32 apps, Microsoft Store apps, LOB apps, app assignments |
| **Automation** | PowerShell scripting, scheduled tasks, proactive remediation |
| **Cloud Integration** | Azure AD, Conditional Access, hybrid scenarios |
| **Enterprise Solutions** | SCCM co-management, Windows deployment, bulk provisioning |
| **Security** | Device security baselines, compliance policies, conditional access |

---

## 💡 Current Focus

- 🔍 Expanding Intune automation capabilities
- 📊 Building advanced remediation scripts
- 🚀 Enhancing Windows deployment solutions
- 🔐 Strengthening security policies & compliance
- 📈 Creating community-driven automation tools

---

## 📬 Connect & Support

| Platform | Link |
|----------|------|
| **Twitter** | [@thekingsmakers](https://twitter.com/thekingsmakers) |
| **GitHub** | [@thekingsmakers](https://github.com/thekingsmakers) |
| **Discussions** | [Repository Discussions](https://github.com/thekingsmakers/Intune/discussions) |
| **Issues** | [Report & Track Issues](https://github.com/thekingsmakers/Intune/issues) |

**Like my work?** Please consider ⭐ starring the [Intune Admin Scripts](https://github.com/thekingsmakers/Intune) repo!

---

## 📜 License & Usage

**Intune Admin Scripts Repository:**
- Currently without formal license (contact me for terms)
- Scripts are provided for use by IT administrators with proper privileges
- Always test in your environment before production deployment
- Contributions welcome from the community

---

<div align="center">

**Thanks for visiting my GitHub profile!** 🙌

*Building enterprise automation, one script at a time.*

![Profile Views](https://komarev.com/ghpvc/?username=thekingsmakers&style=flat-square)

**Generated:** $GeneratedAt  
**[⬆ Back to Top](#)**

</div>
"@
    
    return $README
}

#endregion

#region Git Operations
function Update-GitRepository {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch,
        [string]$Content,
        [string]$CommitMsg
    )
    
    Write-Log "Updating repository..." -Level Info
    
    try {
        # Save README
        $READMEPath = Join-Path -Path $PSScriptRoot -ChildPath 'README.md'
        $Content | Out-File -FilePath $READMEPath -Encoding UTF8
        Write-Log "README.md saved to: $READMEPath" -Level Verbose
        
        if ($AutoCommit) {
            Write-Log "Staging changes..." -Level Verbose
            & git add README.md
            
            Write-Log "Committing changes..." -Level Verbose
            & git commit -m $CommitMsg
            
            Write-Log "Pushing to $Branch..." -Level Verbose
            & git push origin $Branch
            
            Write-Log "Repository updated successfully!" -Level Success
        } else {
            Write-Log "Changes saved locally (use -AutoCommit to push to repository)" -Level Info
        }
    }
    catch {
        Write-Log "ERROR updating repository: $_" -Level Error
        exit 1
    }
}

#endregion

#region Main Execution
try {
    # Get metrics
    $Metrics = Get-GitHubRepoMetrics -Owner $Owner -Repo $Repo -Token $GitHubToken
    Write-Log "Metrics retrieved successfully" -Level Success
    
    # Generate README
    $README = New-ProfileREADME -Metrics $Metrics
    Write-Log "README generated successfully" -Level Success
    
    # Prepare commit message
    if ([string]::IsNullOrEmpty($CommitMessage)) {
        $CommitMessage = "docs: update profile README with live metrics - $($Metrics.Stars) ⭐, $($Metrics.Watchers) 👁️"
    }
    
    # Update repository
    Update-GitRepository -Owner $Owner -Repo $Repo -Branch $Branch -Content $README -CommitMsg $CommitMessage
    
    # Summary
    $ExecutionTime = (Get-Date) - $ScriptStartTime
    Write-Log "Execution completed in $($ExecutionTime.TotalSeconds) seconds" -Level Success
    Write-Log "Repository metrics: ⭐$($Metrics.Stars) | 👁️$($Metrics.Watchers) | 🔀$($Metrics.Forks) | 📋$($Metrics.OpenIssues)" -Level Info
}
catch {
    Write-Log "Script execution failed: $_" -Level Error
    exit 1
}

#endregion
