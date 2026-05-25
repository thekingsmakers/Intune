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

A comprehensive repository of **production-grade Microsoft Intune administration tools** and scripts. Over **23KB** of enterprise-tested automation, with **96% PowerShell**, **1.5% C#**, and **2.5% other**.

**Repository Stats:**
- ⭐ **4** Stars
- 👁️ **4** Watchers  
- 📅 Created: September 11, 2023
- 🔄 Last updated: May 6, 2026
- 📁 **25+ Specialized Modules**

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

**Use Cases:**
- Deploy third-party applications at scale
- Automate app updates across organizations
- Manage application groups & assignments
- Track application compliance

---

### ☁️ **[Azure](https://github.com/thekingsmakers/Intune/tree/main/Azure)**
Azure integration and cloud management utilities for enterprise environments.

**Key Scripts:**
- **PendingDeviceFix.ps1** – Resolves "Pending" device state during Azure AD join
  - Clears AAD Broker Plugin cache
  - Syncs system time with web services
  - Resets authentication tokens
  - Fixes device registration issues
  - Includes uptime checks & restart recommendations

**What's Inside:**
- Azure AD device sync utilities
- Cloud cache management
- Device registration troubleshooting
- Hybrid Azure AD join fixes
- Token cache cleanup
- Time synchronization utilities

**Use Cases:**
- Fix stuck Azure AD joins
- Resolve device pending state issues
- Troubleshoot cloud connectivity
- Reset device authentication state

---

### 🚀 **[AutoPilot](https://github.com/thekingsmakers/Intune/tree/main/AutoPilot)**
Windows Autopilot deployment and configuration automation suite.

**Key Scripts:**

| Script | Purpose |
|--------|---------|
| **Script1.ps1** | Copies PowerShell modules & PackageManagement to Program Files for deployment readiness |
| **Script2.ps1** | Autopilot device registration - uploads hardware hashes to Intune with Teams notifications |
| **Script3.ps1** | SCCM cleanup - uninstalls ConfigMgr client & runs Sysprep for Autopilot transition |
| **Script4.ps1** | Enterprise SCCM cleanup (fixed version) - comprehensive service, WMI, registry cleanup |
| **Script5.ps1** | Production-safe SCCM cleanup - graceful uninstall with detailed logging |

**What's Inside:**
- Autopilot device hash collection & upload
- SCCM to Intune migration scripts
- Sysprep automation for re-imaging
- WMI namespace removal
- Registry cleanup utilities
- Service management & disabling
- Time synchronization for enrollment
- Teams notification integration

**Use Cases:**
- Automate Autopilot device hash uploads
- Migrate devices from SCCM to Intune
- Prepare devices for re-imaging
- Clean legacy client configurations
- Enable Teams notifications for deployment events

---

### 🎨 **[BGInfo Refresh](https://github.com/thekingsmakers/Intune/tree/main/Bginforefresh)**
Automated BGInfo wallpaper deployment with scheduled refresh via Intune.

**Components:**
- **Bginfo64.exe** – 64-bit Sysinternals BGInfo executable
- **hostname.bgi** – System info display configuration template
- **bginforefresh.ps1** – Core execution script with EULA acceptance
- **Install-Bginfo.ps1** – Intune deployment wrapper
- **Uninstall-Bginfo.ps1** – Clean removal script

**How It Works:**
1. Deploys to `C:\ProgramData\BginfoRefresh`
2. Creates scheduled task "BGInfo User Refresh"
3. Runs on: User Logon, Session Lock, Session Unlock
4. Displays system info: hostname, IP, OS, memory, CPU
5. Updates wallpaper automatically without user interaction

**Use Cases:**
- Display device information on desktop wallpaper
- Automated system info visibility for helpdesk
- Deploy consistent branding across organization
- Track device details at a glance

---

### 🔐 **[Conditional Access Policies](https://github.com/thekingsmakers/Intune/tree/main/Conditional%20Access%20Policies)**
Templates and enforcement scripts for Microsoft Entra Conditional Access policies.

**What's Inside:**
- Policy templates for common scenarios
- Risk-based access controls
- Device compliance enforcement
- Multi-factor authentication requirements
- Location-based policies
- Application-specific restrictions
- Legacy authentication blocking
- Session management policies

**Use Cases:**
- Enforce MFA for sensitive applications
- Block legacy authentication
- Require compliant devices
- Enforce location-based access
- Manage high-risk sign-in events

---

### 💻 **[Device Management](https://github.com/thekingsmakers/Intune/tree/main/Device%20Managemet)**
Enterprise device registration, monitoring, and remediation tools.

**What's Inside:**
- Device enrollment automation
- Compliance checking utilities
- Remediation script deployment
- Hardware inventory collection
- Device health monitoring
- Configuration profile application
- Status reporting & alerts
- Bulk device management operations

**Use Cases:**
- Monitor device compliance status
- Deploy compliance remediation
- Collect hardware inventory
- Enroll devices at scale
- Track device health metrics

---

### 🖼️ **[Image Deploy](https://github.com/thekingsmakers/Intune/tree/main/ImageDeploy)**
Complete Windows image deployment solution with GUI configuration and C# components.

**Project Structure:**
- **SetupGUI** – C# Windows Forms interface for configuration
- **Deploy.ps1** – Main deployment orchestrator with menu system
- **deploy-config.xml** – Deployment configuration file
- **Deployment Scripts** – Individual deployment operations

**Features:**
- Software package installation from USB
- Hostname configuration automation
- WiFi setup & connection management
- Windows product activation
- Optional Windows features installation (Hyper-V, WSL, Telnet)
- Domain join automation with credentials
- Detailed deployment logging
- Error recovery & rollback mechanisms
- Post-deployment testing

**Use Cases:**
- Deploy Windows 10/11 to multiple devices
- Configure systems during provisioning
- Bulk device setup automation
- Zero-touch deployment preparation
- Domain integration at deployment

---

### 📦 **[InstallApps](https://github.com/thekingsmakers/Intune/tree/main/InstallApps)**
Bulk application installation and management automation scripts.

**What's Inside:**
- Silent installation scripts for common apps
- Batch installation orchestration
- Installation logging & reporting
- Error handling & retry mechanisms
- Version management utilities
- Uninstallation cleanup procedures
- Dependency installation
- Installation verification scripts

**Use Cases:**
- Deploy standard application sets
- Automate application installations
- Verify successful deployments
- Clean up failed installations
- Track installation history

---

### 🎛️ **[Intune Management](https://github.com/thekingsmakers/Intune/tree/main/Intune%20Management)**
Core utilities and administrative tools for Intune platform management.

**What's Inside:**
- Graph API integration scripts
- Bulk policy management
- Device group management
- Enrollment profile configuration
- Reporting & analytics utilities
- Compliance policy automation
- Device action automation (sync, retire, wipe)
- Configuration profile deployment

**Use Cases:**
- Automate Intune policy management
- Bulk device operations
- Generate compliance reports
- Configure enrollment profiles
- Manage device groups at scale

---

### 🛒 **[Microsoft Store Updates](https://github.com/thekingsmakers/Intune/tree/main/Microsoft%20Store%20Update%20backend)**
Microsoft Store application update management and backend automation.

**What's Inside:**
- Store app update policies
- Update scheduling automation
- App versioning management
- Update deployment scripts
- Store app inventory tools
- Update rollout controls
- Delivery optimization settings

**Use Cases:**
- Manage Microsoft Store app updates
- Deploy Store apps via Intune
- Control update timing
- Track app versions
- Ensure app compatibility

---

### 📊 **[Ms Store](https://github.com/thekingsmakers/Intune/tree/main/Ms%20Store)**
Microsoft Store portal launchers and management utilities.

**Key Scripts:**
- **sites.ps1** – Portal availability checker
  - Tests connectivity to 19+ Microsoft admin portals
  - Entra ID, Azure, Intune, Exchange, Teams, Defender, etc.
  - Color-coded status output (Green/Red)
  - Timeout handling
  - Quick portal access launcher

**Portals Monitored:**
- Microsoft Entra ID
- Azure Portal
- Microsoft Intune Admin Center
- Exchange Admin Center
- Microsoft 365 Admin Center
- Microsoft Defender XDR
- Teams Admin Center
- SharePoint Admin
- Power Platform Admin
- And 11+ more!

**Use Cases:**
- Verify portal availability
- Troubleshoot connectivity issues
- Quick access to admin portals
- Monitor Microsoft service health

---

### 🔄 **[SCCM](https://github.com/thekingsmakers/Intune/tree/main/SCCM)**
System Center Configuration Manager co-management and integration utilities.

**What's Inside:**
- SCCM to Intune migration scripts
- Co-management configuration
- Client uninstallation procedures
- SCCM agent cleanup
- Intune enrollment acceleration
- Hybrid device management
- Legacy client removal
- Workload transition automation

**Use Cases:**
- Migrate from SCCM to Intune
- Enable co-management scenarios
- Remove legacy SCCM clients
- Transition workloads to cloud

---

### 🎯 **[Scripting](https://github.com/thekingsmakers/Intune/tree/main/Scripting)**
General PowerShell automation utilities and helper scripts.

**What's Inside:**
- Common PowerShell functions
- Utility scripts for administrators
- Automation templates
- Integration helpers
- Data processing utilities
- Batch operation scripts
- Configuration helpers
- Troubleshooting utilities

**Use Cases:**
- Reusable automation components
- Quick PowerShell utilities
- Common IT tasks automation
- System administration helpers

---

### 🗑️ **[TKM-Uninstaller-V.1](https://github.com/thekingsmakers/Intune/tree/main/TKM-Uninstaller-V.1)**
Custom uninstallation tools for managing application removal.

**What's Inside:**
- Clean uninstallation scripts
- Registry cleanup procedures
- File system cleanup
- Application removal verification
- Rollback capabilities
- Logging & audit trails
- Dependent cleanup procedures

**Use Cases:**
- Remove applications cleanly
- Clean registry entries
- Verify removal completion
- Clean dependencies

---

### 💾 **[TKM-WinAppInstaller](https://github.com/thekingsmakers/Intune/tree/main/TKM-WinAppInstaller)**
Advanced Windows application installer with custom deployment logic.

**What's Inside:**
- Application packaging utilities
- Installation verification
- Rollback mechanisms
- Custom deployment logic
- Version management
- Logging & reporting
- Error handling
- Installation orchestration

**Use Cases:**
- Deploy complex applications
- Custom installation logic
- Application packaging
- Multi-step installations

---

### 📝 **[User Handling](https://github.com/thekingsmakers/Intune/tree/main/User%20handling)**
User provisioning, management, and lifecycle automation scripts.

**What's Inside:**
- User onboarding automation
- Account creation scripts
- Group membership management
- License assignment automation
- Mailbox provisioning
- Drive mapping automation
- Offboarding procedures
- User lifecycle workflows

**Use Cases:**
- Automate user onboarding
- Manage group memberships
- Assign licenses at scale
- Execute offboarding workflows
- User account lifecycle automation

---

### 🪟 **[Windows 10 ESU Activation](https://github.com/thekingsmakers/Intune/tree/main/Windows%2010%20ESU%20Activation-Intune%20Remediation)**
Extended Security Update activation and remediation scripts for Windows 10.

**Key Scripts:**
- ESU activation automation
- License key deployment
- Activation status verification
- ESU eligibility checking
- Remediation procedures
- Compliance reporting

**What's Inside:**
- ESU license key management
- Activation verification scripts
- Device eligibility checking
- Remediation automation
- Compliance status reporting
- Support lifecycle tracking

**Use Cases:**
- Activate ESU on Windows 10 devices
- Verify ESU status
- Remediate activation failures
- Track support eligibility
- Ensure continued protection

---

### ✔️ **[Intune Scripts Validator](https://github.com/thekingsmakers/Intune/tree/main/intune%20Scripts%20Validator)**
Validation and compliance checking tools for Intune deployment scripts.

**What's Inside:**
- Script syntax validation
- Compliance checking
- Best practices verification
- PowerShell syntax validation
- Error detection
- Performance optimization recommendations
- Security best practices checking

**Use Cases:**
- Validate scripts before deployment
- Check compliance requirements
- Verify security best practices
- Test syntax correctness
- Optimize script performance

---

### 📋 **[Daily Used Snippets](https://github.com/thekingsmakers/Intune/blob/main/DailyUsedSnippets.md)**
Quick reference PowerShell snippets for common Intune administration tasks.

**What's Inside:**
- Quick copy-paste solutions
- Common command patterns
- One-liners for admin tasks
- API integration examples
- Device query templates
- Policy management snippets
- Troubleshooting commands

**Use Cases:**
- Quick PowerShell reference
- Common task automation
- API integration examples
- Day-to-day administration

---

## 💻 Tech Stack
- Powershell
- Batch scripts
- Python
- Javascript 
- HTML
- Css
