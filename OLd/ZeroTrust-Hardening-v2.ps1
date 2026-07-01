# ============================================
# ZERO TRUST ENDPOINT LOCKDOWN v2
# Fixed: Blocking now actually works
# Run as SYSTEM (Intune / GPO)
# ============================================

# -------------------------
# ADMIN / SYSTEM CHECK
# -------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Must be run as Administrator or SYSTEM. Exiting."
    exit 1
}

Write-Output "Starting Zero Trust Hardening v2..."

# -------------------------
# CONFIGURATION
# -------------------------

$Prefix = "ZT-Hard"

# ✅ Your internal servers (DCs, file servers, etc.)
# These get AD-specific ports only — NOT a blanket allow
$DomainControllers = @(
    "172.29.196.12",
    "172.29.196.4",
    "172.29.191.196"
)

# ✅ FQDNs resolved to IPs at runtime and allowed on port 443 only
$AllowedFQDNs = @(
    "login.microsoftonline.com",
    "device.login.microsoftonline.com",
    "enterpriseregistration.windows.net",
    "graph.microsoft.com",
    "management.azure.com",
    "endpoint.microsoft.com"
)

# ✅ DNS locked to these servers only (port 53 UDP/TCP)
$AllowedDNSServers = @(
    "8.8.8.8",
    "10.204.5.53",
    "10.205.5.53"
)

# ✅ VPN executables to block
$VPNApps = @(
    "openvpn.exe",
    "nordvpn.exe",
    "expressvpn.exe",
    "wireguard.exe",
    "protonvpn.exe"
)

# -------------------------
# STEP 0 — FIREWALL BACKUP
# -------------------------
try {
    $BackupPath = "$env:SystemRoot\Temp\FirewallBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').wfw"
    netsh advfirewall export $BackupPath | Out-Null
    Write-Output "Firewall backup saved to: $BackupPath"
} catch {
    Write-Warning "Could not backup firewall rules: $_"
    $BackupPath = "(backup failed)"
}

# -------------------------
# STEP 1 — MOUNT HKU DRIVE EARLY
# Required for per-user registry changes under SYSTEM context
# -------------------------
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    Write-Output "HKU registry drive mounted."
}

# -------------------------
# STEP 2 — COLLECT PS PATHS BEFORE BLOCKING PS NETWORK
# Must be done BEFORE the PS block rules are created,
# because Get-ChildItem needs network-free access (this is local disk, so fine)
# but FQDN resolution must also happen before PS is blocked.
# -------------------------

# Collect PowerShell paths
$PSPaths = @(
    "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe",
    "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe",
    "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell_ise.exe",
    "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe",
    "$env:ProgramFiles\PowerShell\7\pwsh.exe"
)
$extraPwsh = Get-ChildItem -Path "$env:ProgramFiles\PowerShell" -Filter "pwsh.exe" -Recurse -ErrorAction SilentlyContinue
foreach ($e in $extraPwsh) {
    if ($PSPaths -notcontains $e.FullName) { $PSPaths += $e.FullName }
}

# Collect VPN paths
$SearchRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LocalAppData\Programs")
$VPNPaths = @()
foreach ($app in $VPNApps) {
    foreach ($root in $SearchRoots) {
        if (Test-Path $root) {
            $VPNPaths += Get-ChildItem -Path $root -Recurse -Filter $app -ErrorAction SilentlyContinue
        }
    }
}

# Resolve FQDNs to IPs BEFORE PS network is blocked
Write-Output "Resolving FQDNs to IPs..."
$FQDNRules = @{}
foreach ($fqdn in $AllowedFQDNs) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($fqdn) | Select-Object -ExpandProperty IPAddressToString
        if ($resolved.Count -gt 0) {
            $FQDNRules[$fqdn] = $resolved
            Write-Output "  $fqdn -> $($resolved -join ', ')"
        } else {
            Write-Warning "  No IPs resolved for $fqdn - skipped"
        }
    } catch {
        Write-Warning "  Failed to resolve ${fqdn}: $_"
    }
}

# -------------------------
# STEP 3 — REMOVE OLD RULES
# -------------------------
Write-Output "Removing old $Prefix rules..."
Get-NetFirewallRule -DisplayName "$Prefix-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Output "Old rules removed."

# -------------------------
# STEP 4 — DEFAULT BLOCK ALL OUTBOUND
# This is the foundation. Everything below pokes specific holes.
# -------------------------
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block
Write-Output "Default outbound: BLOCK."

# -------------------------
# STEP 5 — ALLOW LOOPBACK (required for many Windows services)
# -------------------------
New-NetFirewallRule -DisplayName "$Prefix-Allow-Loopback" `
    -Direction Outbound `
    -RemoteAddress 127.0.0.1 `
    -Action Allow | Out-Null

# -------------------------
# STEP 6 — ALLOW DNS (locked to specific DNS servers, port 53 only)
# -------------------------
New-NetFirewallRule -DisplayName "$Prefix-Allow-DNS-UDP" `
    -Direction Outbound -Protocol UDP `
    -RemotePort 53 `
    -RemoteAddress $AllowedDNSServers `
    -Action Allow | Out-Null

New-NetFirewallRule -DisplayName "$Prefix-Allow-DNS-TCP" `
    -Direction Outbound -Protocol TCP `
    -RemotePort 53 `
    -RemoteAddress $AllowedDNSServers `
    -Action Allow | Out-Null

Write-Output "DNS allowed to: $($AllowedDNSServers -join ', ')"

# -------------------------
# STEP 7 — ALLOW FQDN IPs (port 443 only, resolved above)
# -------------------------
foreach ($fqdn in $FQDNRules.Keys) {
    $ips = $FQDNRules[$fqdn]
    New-NetFirewallRule -DisplayName "$Prefix-Allow-FQDN-$fqdn" `
        -Direction Outbound `
        -RemoteAddress $ips `
        -Protocol TCP `
        -RemotePort 443 `
        -Action Allow | Out-Null
    Write-Output "  Allowed FQDN $fqdn (port 443 only)"
}

# -------------------------
# STEP 8 — ALLOW AD / DOMAIN CONTROLLER PORTS
# IMPORTANT: Only exact ports needed — no blanket allows
# Removed port 443 from DCs — add separately to $AllowedFQDNs or $AllowedIPs if needed
# -------------------------
foreach ($dc in $DomainControllers) {

    # Kerberos (authentication)
    New-NetFirewallRule -DisplayName "$Prefix-AD-Kerberos-TCP-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 88 -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "$Prefix-AD-Kerberos-UDP-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol UDP -RemotePort 88 -Action Allow | Out-Null

    # LDAP (directory queries)
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAP-TCP-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 389 -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAP-UDP-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol UDP -RemotePort 389 -Action Allow | Out-Null

    # LDAPS (secure LDAP)
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAPS-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 636 -Action Allow | Out-Null

    # SMB (Group Policy, SYSVOL)
    New-NetFirewallRule -DisplayName "$Prefix-AD-SMB-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 445 -Action Allow | Out-Null

    # RPC Endpoint Mapper (needed to negotiate dynamic ports)
    New-NetFirewallRule -DisplayName "$Prefix-AD-RPC-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 135 -Action Allow | Out-Null

    # NTP (time sync — critical for Kerberos)
    New-NetFirewallRule -DisplayName "$Prefix-AD-NTP-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol UDP -RemotePort 123 -Action Allow | Out-Null

    # Global Catalog
    New-NetFirewallRule -DisplayName "$Prefix-AD-GC-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 3268 -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "$Prefix-AD-GCS-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 3269 -Action Allow | Out-Null

    # RPC Dynamic Ports — SCOPED TO DCs ONLY (not a blanket allow)
    # To tighten this further: set a fixed RPC port range on your DCs via:
    # netsh int ipv4 set dynamicport tcp start=60000 num=1000
    # Then change 49152-65535 below to 60000-60999
    New-NetFirewallRule -DisplayName "$Prefix-AD-RPC-Dyn-$dc" `
        -Direction Outbound -RemoteAddress $dc -Protocol TCP -RemotePort 49152-65535 -Action Allow | Out-Null

    Write-Output "  AD rules created for DC: $dc"
}

# -------------------------
# STEP 9 — BLOCK HTTP EXPLICITLY (belt + suspenders)
# -------------------------
New-NetFirewallRule -DisplayName "$Prefix-Block-HTTP" `
    -Direction Outbound -Protocol TCP -RemotePort 80 -Action Block | Out-Null
Write-Output "HTTP (port 80) explicitly blocked."

# -------------------------
# STEP 10 — BLOCK POWERSHELL NETWORK ACCESS
# Done AFTER all rules are created so the script itself can finish
# -------------------------
foreach ($ps in $PSPaths) {
    if (Test-Path $ps) {
        $label = "$([IO.Path]::GetFileName($ps))-$(Split-Path $ps -Parent | Split-Path -Leaf)"
        New-NetFirewallRule -DisplayName "$Prefix-Block-PS-$label" `
            -Program $ps `
            -Direction Outbound `
            -Action Block `
            -Profile Any | Out-Null
        Write-Output "  PS network blocked: $ps"
    }
}

# -------------------------
# STEP 11 — BLOCK VPN APPS (exact paths, found above)
# -------------------------
if ($VPNPaths.Count -gt 0) {
    foreach ($f in $VPNPaths) {
        New-NetFirewallRule -DisplayName "$Prefix-Block-VPN-$($f.BaseName)" `
            -Program $f.FullName `
            -Direction Outbound `
            -Action Block | Out-Null
        Write-Output "  VPN blocked: $($f.FullName)"
    }
} else {
    Write-Output "No VPN apps found on disk."
}

# -------------------------
# STEP 12 — DISABLE PROXY CHANGES
# -------------------------

# Machine-level — no per-user proxy overrides
$RegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name ProxySettingsPerUser        -Value 0 -Type DWord
Set-ItemProperty -Path $RegPath -Name Proxy                       -Value 0 -Type DWord
Set-ItemProperty -Path $RegPath -Name EnableAutoProxyResultCache  -Value 0 -Type DWord

# Lock proxy UI for CURRENT user
$UserProxyPath = "HKCU:\Software\Policies\Microsoft\Internet Explorer\Control Panel"
New-Item -Path $UserProxyPath -Force | Out-Null
Set-ItemProperty -Path $UserProxyPath -Name Proxy -Value 1 -Type DWord

# Lock proxy UI for ALL loaded user profiles (HKU drive mounted in Step 1)
Write-Output "Applying proxy lock to all user profiles..."
try {
    $UserHives = Get-ChildItem "HKU:\" -ErrorAction Stop | Where-Object { $_.PSChildName -match "^S-1-5-21-" }
    foreach ($hive in $UserHives) {
        $uPath = "HKU:\$($hive.PSChildName)\Software\Policies\Microsoft\Internet Explorer\Control Panel"
        try {
            New-Item -Path $uPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $uPath -Name Proxy -Value 1 -Type DWord -ErrorAction Stop
            Write-Output "  Proxy locked for: $($hive.PSChildName)"
        } catch {
            Write-Warning "  Could not lock proxy for $($hive.PSChildName): $_"
        }
    }
} catch {
    Write-Warning "  Could not enumerate HKU hives: $_"
}

Write-Output "Proxy restrictions applied."

# -------------------------
# STEP 13 — BLOCK NEW NETWORK ADAPTER INSTALLS
# -------------------------
$DevInstallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
New-Item -Path $DevInstallPath -Force | Out-Null
Set-ItemProperty -Path $DevInstallPath -Name DenyUnspecified      -Value 1 -Type DWord
Set-ItemProperty -Path $DevInstallPath -Name DenyRemovableDevices -Value 1 -Type DWord
Write-Output "New NIC / USB adapter installation blocked."

# -------------------------
# STEP 14 — ENABLE FIREWALL LOGGING
# -------------------------
Set-NetFirewallProfile -Profile Domain,Private,Public `
    -LogAllowed True `
    -LogBlocked True `
    -LogMaxSizeKilobytes 32767 `
    -LogFileName "$env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
Write-Output "Firewall logging enabled."

# -------------------------
# SUMMARY
# -------------------------
$RuleCount = (Get-NetFirewallRule -DisplayName "$Prefix-*" -ErrorAction SilentlyContinue).Count

Write-Output ""
Write-Output "============================================"
Write-Output " Zero Trust Hardening v2 Complete"
Write-Output "============================================"
Write-Output " Rules created  : $RuleCount"
Write-Output " Firewall backup: $BackupPath"
Write-Output " Log file       : $env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
Write-Output ""
Write-Output " To verify blocking is working:"
Write-Output "   Test-NetConnection google.com -Port 443   # should FAIL"
Write-Output "   Test-NetConnection 8.8.8.8 -Port 53       # should PASS (DNS)"
Write-Output "   Test-NetConnection login.microsoftonline.com -Port 443  # should PASS"
Write-Output ""
Write-Output " To restore firewall if something breaks:"
Write-Output "   netsh advfirewall import '$BackupPath'"
Write-Output "============================================"
