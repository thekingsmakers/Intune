<#
Collect TSS logs with Intune Remediation
The script does the following:
 ____________________________________________________________________________________________________________________________________
1. Downloads the TSS tool:  https://aka.ms/getTSS
2. Creates a TempZ folder in C:\ and copy the TSS folder and unzip it
3. Runs PowerShell as administrator and navigates to Temp folder with cd C:\Tempz\TSS
4. Then runs the script with this command: .\TSS.ps1 -CollectLog DND_SetupReport -AcceptEula
5. Waits until the script completes, you will find the result in: C:\MS_DATA
_______________________________________________________________________________________________________________________________________
Created By Omar Osman Mahat 
Date: 17/12/2024
#>
 
 ### Define variables
$downloadUrl = "https://aka.ms/getTSS"
$tempFolder = "C:\TempZ"
$tssZipPath = "$tempFolder\TSS.zip"
$tssFolder = "$tempFolder\TSS"
$resultFolder = "C:\MS_DATA"

### Step 1: Create TempZ folder
if (-Not (Test-Path -Path $tempFolder)) {
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    Write-Host "Created folder: $tempFolder"
} else {
    Write-Host "$tempFolder already exists."
}

### Step 2: Download the TSS tool
Write-Host "Downloading TSS tool from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $tssZipPath -UseBasicParsing
Write-Host "TSS tool downloaded to $tssZipPath"

### Step 3: Extract the TSS tool
if (-Not (Test-Path -Path $tssZipPath)) {
    Write-Error "TSS.zip not found at $tssZipPath. Download may have failed."
    exit
}

Write-Host "Extracting TSS tool..."
Expand-Archive -Path $tssZipPath -DestinationPath $tssFolder -Force
Write-Host "TSS tool extracted to $tssFolder"

### Step 4: Run the TSS script
$scriptPath = "$tssFolder\TSS.ps1"
if (Test-Path $scriptPath) {
    Write-Host "Running TSS script..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"cd $tssFolder; .\TSS.ps1 -CollectLog DND_SetupReport -AcceptEula`"" -Verb RunAs -Wait
    Write-Host "TSS script completed. Logs available at $resultFolder"
} else {
    Write-Error "TSS script not found at $scriptPath"
    exit
}
