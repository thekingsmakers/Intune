# Integrator.ps1
# PowerShell script to automate MDT Extension integration into Task Sequence

Write-Host "MDT Extension Integrator script started."

# --- Configuration ---
$TaskSequenceName = "YourTaskSequenceName" # Replace with your actual Task Sequence Name
$DeploymentSharePath = "YourDeploymentSharePath" # Replace with your actual Deployment Share Path

$DeviceNamerScriptName = "DeviceNamer.ps1"
$DomainJoinScriptName = "DomainJoin.ps1"
$SoftwareInstallerScriptName = "SoftwareInstaller.ps1"
$ReportGeneratorScriptName = "ReportGenerator.ps1"
$WindowsActivationScriptName = "WindowsActivation.ps1"
$SetupScriptName = "setup.ps1"

$ExtensionFolderPath = "MDT-Extension" # Assumes MDT-Extension folder is placed in the Scripts directory of the Deployment Share

# --- Script Logic ---

# Construct script paths relative to the MDT Scripts directory
$SetupScriptPath = ".\$ExtensionFolderPath\$SetupScriptName"
$DeviceNamerScriptPath = ".\$ExtensionFolderPath\DeviceNamer\$DeviceNamerScriptName"
$DomainJoinScriptPath = ".\$ExtensionFolderPath\DomainJoin\$DomainJoinScriptName"
$SoftwareInstallerScriptPath = ".\$ExtensionFolderPath\SoftwareInstaller\$SoftwareInstallerScriptName"
$ReportGeneratorScriptPath = ".\$ExtensionFolderPath\ReportGenerator\$ReportGeneratorScriptName"
$WindowsActivationScriptPath = ".\$ExtensionFolderPath\WindowsActivation\$WindowsActivationScriptName"

Write-Host "Script paths are configured as:"
Write-Host "Setup Script: $($SetupScriptPath)"
Write-Host "Device Namer Script: $($DeviceNamerScriptPath)"
Write-Host "Windows Activation Script: $($WindowsActivationScriptPath)"
Write-Host "Domain Join Script: $($DomainJoinScriptPath)"
Write-Host "Software Installer Script: $($SoftwareInstallerScriptPath)"
Write-Host "Report Generator Script: $($ReportGeneratorScriptPath)"
Write-Host "---"

Write-Host "Please perform the following steps in your MDT Deployment Workbench:"
Write-Host ""
Write-Host "1. Open your Deployment Share in Deployment Workbench."
Write-Host "2. Navigate to 'Task Sequences' and select your Task Sequence: '$TaskSequenceName'."
Write-Host "3. Click 'Edit' to open the Task Sequence Editor."
Write-Host ""
Write-Host "4. Add 'Run PowerShell Script' steps for each extension component:"
Write-Host ""

Write-Host "   a) Optional: Run Setup Script (for initial configuration):"
Write-Host "      - Step Name: Run Setup Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location:  Can be run manually from 'Scripts' folder in DeploymentShare to configure config.xml"
Write-Host "      - Script name: $($SetupScriptPath)"
Write-Host "      - Note: This script is for manual configuration and is not typically part of the Task Sequence."
Write-Host ""

Write-Host "   b) For Device Namer:"
Write-Host "      - Step Name: Run Device Namer Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location: 'Preinstall' phase, typically at the beginning of the Task Sequence"
Write-Host "      - Script name: $($DeviceNamerScriptPath)"
Write-Host ""

Write-Host "   c) For Windows Activation:"
Write-Host "      - Step Name: Run Windows Activation Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location: 'State Restore' phase, after 'Install Operating System' and before 'Domain Join'"
Write-Host "      - Script name: $($WindowsActivationScriptPath)"
Write-Host "      - Parameters: No parameters needed, configuration is read from config.xml"
Write-Host ""

Write-Host "   d) For Domain Join:"
Write-Host "      - Step Name: Run Domain Join Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location: 'State Restore' phase, in 'Custom Tasks' or a new group after 'Install Operating System'"
Write-Host "      - Script name: $($DomainJoinScriptPath)"
Write-Host ""

Write-Host "   e) For Software Installer:"
Write-Host "      - Step Name: Run Software Installer Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location: 'State Restore' phase, after 'Run Domain Join Script' (if applicable) and OS configuration steps"
Write-Host "      - Script name: $($SoftwareInstallerScriptPath)"
Write-Host ""

Write-Host "   f) For Report Generator:"
Write-Host "      - Step Name: Run Report Generator Script"
Write-Host "      - Type: Run PowerShell Script"
Write-Host "      - Location: 'Summary' phase or end of 'State Restore' phase (last step in Task Sequence)"
Write-Host "      - Script name: $($ReportGeneratorScriptPath)"
Write-Host ""

Write-Host "5. Ensure 'Execution policy' for each 'Run PowerShell Script' step is set to 'Bypass' or 'Unrestricted' if needed."
Write-Host ""
Write-Host "6. Click 'Apply' and 'OK' to save the Task Sequence changes."
Write-Host ""
Write-Host "Integration steps outlined above. Please manually add these steps to your MDT Task Sequence using the Deployment Workbench."
Write-Host "Remember to run setup.ps1 manually to configure the MDT Extension before running the Task Sequence."

Write-Host "MDT Extension Integrator script finished."