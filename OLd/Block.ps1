# ============================================
# ZERO TRUST ENDPOINT LOCKDOWN (ADVANCED)
# Fixed & Hardened Version
# Works inside & outside network
# Run as SYSTEM (Intune / GPO)
# ============================================

# -------------------------
# ADMIN / SYSTEM CHECK
# -------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "❌ Must be run as Administrator or SYSTEM. Exiting."
    exit 1
}

Write-Output "Starting Zero Trust Hardening..."

# -------------------------
# CONFIGURATION
# -------------------------

$Prefix = "ZT-Hard"

# ✅ Add your allowed IPs (direct IP allowlist on port 443)
$AllowedIPs = @(
    "172.29.191.196",
	"172.29.196.12",
	"172.29.196.4"
)

# ✅ FQDNs to resolve and allow on port 443
# NOTE: IPs are resolved at runtime. For dynamic CDN-backed FQDNs (e.g. Microsoft),
# use Azure Firewall / Defender for Endpoint for durable FQDN-based filtering.
$AllowedFQDNs = @(
    "login.microsoftonline.com",
    "device.login.microsoftonline.com",
    "enterpriseregistration.windows.net",
    "graph.microsoft.com",
    "management.azure.com",
    "endpoint.microsoft.com"
)

# ✅ DNS servers to lock DNS outbound to (recommended: your internal DNS or known safe resolvers)
$AllowedDNSServers = @(
    "8.8.8.8",
    "10.204.5.53",
    "10.205.5.53"
    # Add your internal DNS IPs here, e.g. "10.0.0.10"
)

# ✅ On-Prem Domain Controllers
$DomainControllers = @(
    "172.29.196.12",
    "172.29.196.4",
	"172.29.191.196"
)

# ✅ VPN executables to block (exact names)
$VPNApps = @(
    "openvpn.exe",
    "nordvpn.exe",
    "expressvpn.exe",
    "wireguard.exe",
    "protonvpn.exe"
)

# -------------------------
# ROLLBACK SNAPSHOT (Best-effort)
# -------------------------
try {
    # Export current firewall rules as backup before making changes
    $BackupPath = "$env:SystemRoot\Temp\FirewallBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').wfw"
    netsh advfirewall export $BackupPath | Out-Null
    Write-Output "✅ Firewall backup saved to: $BackupPath"
} catch {
    Write-Warning "⚠️ Could not backup firewall rules: $_"
}

# -------------------------
# CLEAN OLD RULES
# -------------------------
Write-Output "Removing old $Prefix rules..."
Get-NetFirewallRule -DisplayName "$Prefix-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Output "✅ Old rules removed."

# -------------------------
# FIREWALL DEFAULT BLOCK (Outbound)
# -------------------------
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block
Write-Output "✅ Default outbound action set to Block."

# -------------------------
# ALLOW DNS (Locked to specific DNS servers)
# -------------------------
if ($AllowedDNSServers.Count -gt 0) {
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

    Write-Output "✅ DNS rules created (locked to specified DNS servers)."
} else {
    # Fallback: allow DNS to any (less secure)
    New-NetFirewallRule -DisplayName "$Prefix-Allow-DNS-UDP" `
        -Direction Outbound -Protocol UDP -RemotePort 53 -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "$Prefix-Allow-DNS-TCP" `
        -Direction Outbound -Protocol TCP -RemotePort 53 -Action Allow | Out-Null
    Write-Warning "⚠️ DNS allowed to ANY server. Consider locking to specific DNS IPs."
}

# -------------------------
# ALLOW CUSTOM IPs (Port 443)
# -------------------------
foreach ($ip in $AllowedIPs) {
    New-NetFirewallRule -DisplayName "$Prefix-Allow-IP-$ip" `
        -Direction Outbound -RemoteAddress $ip `
        -Protocol TCP -RemotePort 443 -Action Allow | Out-Null
    Write-Output "  ✅ Allowed IP: $ip"
}

# -------------------------
# ALLOW FQDNs (Resolved to IPs at runtime)
# NOTE: Windows Firewall does NOT support -RemoteFqdn.
# FQDNs must be resolved to IPs first. IPs may change for CDN-backed services.
# -------------------------
Write-Output "Resolving FQDNs to IPs..."
$ResolvedFQDNIPs = @()

foreach ($fqdn in $AllowedFQDNs) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($fqdn) |
            Select-Object -ExpandProperty IPAddressToString

        if ($resolved.Count -gt 0) {
            $ResolvedFQDNIPs += $resolved
            New-NetFirewallRule -DisplayName "$Prefix-Allow-FQDN-$fqdn" `
                -Direction Outbound `
                -RemoteAddress $resolved `
                -Protocol TCP `
                -RemotePort 443 `
                -Action Allow | Out-Null
            Write-Output "  ✅ $fqdn → $($resolved -join ', ')"
        } else {
            Write-Warning "  ⚠️ No IPs resolved for $fqdn — skipped."
        }
    } catch {
        Write-Warning "  ⚠️ Failed to resolve $fqdn : $_"
    }
}

# -------------------------
# ALLOW AD / DOMAIN CONTROLLER SERVICES
# -------------------------
foreach ($dc in $DomainControllers) {

    # Kerberos
    New-NetFirewallRule -DisplayName "$Prefix-AD-Kerberos-TCP-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 88 -Action Allow | Out-Null

    New-NetFirewallRule -DisplayName "$Prefix-AD-Kerberos-UDP-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol UDP -RemotePort 88 -Action Allow | Out-Null

    # LDAP
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAP-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 389 -Action Allow | Out-Null

    # LDAP UDP (needed for DC locator)
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAP-UDP-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol UDP -RemotePort 389 -Action Allow | Out-Null

    # LDAPS (Secure LDAP)
    New-NetFirewallRule -DisplayName "$Prefix-AD-LDAPS-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 636 -Action Allow | Out-Null

    # SMB (Group Policy, SYSVOL)
    New-NetFirewallRule -DisplayName "$Prefix-AD-SMB-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 445 -Action Allow | Out-Null

    # RPC Endpoint Mapper
    New-NetFirewallRule -DisplayName "$Prefix-AD-RPC-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 135 -Action Allow | Out-Null

    # NetLogon / NTP
    New-NetFirewallRule -DisplayName "$Prefix-AD-NTP-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol UDP -RemotePort 123 -Action Allow | Out-Null

    # Global Catalog
    New-NetFirewallRule -DisplayName "$Prefix-AD-GC-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 3268 -Action Allow | Out-Null

    New-NetFirewallRule -DisplayName "$Prefix-AD-GCS-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 3269 -Action Allow | Out-Null

    # RPC Dynamic Ports (required for AD replication, GP, etc.)
    # Recommendation: restrict this range on the DC via netsh to a smaller range
    New-NetFirewallRule -DisplayName "$Prefix-AD-RPC-Dynamic-$dc" `
        -Direction Outbound -RemoteAddress $dc `
        -Protocol TCP -RemotePort 49152-65535 -Action Allow | Out-Null

    Write-Output "  ✅ AD rules created for DC: $dc"
}

# -------------------------
# BLOCK HTTP (Port 80) — No wildcard exceptions needed
# -------------------------
New-NetFirewallRule -DisplayName "$Prefix-Block-All-HTTP" `
    -Direction Outbound -Protocol TCP -RemotePort 80 -Action Block | Out-Null
Write-Output "✅ HTTP (port 80) blocked."

# NOTE: No explicit Block-All-HTTPS rule is needed.
# The DefaultOutboundAction Block already handles this.
# Adding a blanket block on port 443 would race/conflict with specific Allow rules above.

# -------------------------
# BLOCK POWERSHELL NETWORK ACCESS
# Fixed: Added SysWOW64 path + correct pwsh.exe path
# -------------------------
$PSPaths = @(
    "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe",
    "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe",
    "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell_ise.exe",
    "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe",
    "$env:ProgramFiles\PowerShell\7\pwsh.exe"
)

# Also scan for any other pwsh.exe on disk
$extraPwsh = Get-ChildItem -Path "$env:ProgramFiles\PowerShell" -Filter "pwsh.exe" -Recurse -ErrorAction SilentlyContinue
foreach ($e in $extraPwsh) {
    if ($PSPaths -notcontains $e.FullName) {
        $PSPaths += $e.FullName
    }
}

foreach ($ps in $PSPaths) {
    if (Test-Path $ps) {
        New-NetFirewallRule -DisplayName "$Prefix-Block-PS-$([IO.Path]::GetFileName($ps))-$(Split-Path $ps -Parent | Split-Path -Leaf)" `
            -Program $ps `
            -Direction Outbound `
            -Action Block `
            -Profile Any | Out-Null
        Write-Output "  ✅ Blocked network for: $ps"
    }
}

# -------------------------
# BLOCK VPN APPS
# Fixed: Search for actual executable paths instead of using wildcard in -Program
# -------------------------
Write-Output "Searching for VPN apps to block..."
$SearchRoots = @(
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    "$env:LocalAppData\Programs"
)

foreach ($app in $VPNApps) {
    $found = @()
    foreach ($root in $SearchRoots) {
        if (Test-Path $root) {
            $found += Get-ChildItem -Path $root -Recurse -Filter $app -ErrorAction SilentlyContinue
        }
    }

    if ($found.Count -gt 0) {
        foreach ($f in $found) {
            New-NetFirewallRule -DisplayName "$Prefix-Block-VPN-$($f.Name)-$(Get-Random -Maximum 9999)" `
                -Program $f.FullName `
                -Direction Outbound `
                -Action Block | Out-Null
            Write-Output "  ✅ Blocked VPN app: $($f.FullName)"
        }
    } else {
        Write-Output "  ℹ️ VPN app not found (not installed): $app"
    }
}

# -------------------------
# DISABLE PROXY CHANGES
# -------------------------

# Machine-level policy
$RegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name ProxySettingsPerUser   -Value 0 -Type DWord
Set-ItemProperty -Path $RegPath -Name Proxy                  -Value 0 -Type DWord
Set-ItemProperty -Path $RegPath -Name EnableAutoProxyResultCache -Value 0 -Type DWord

# Lock proxy UI per-user (applies to currently logged-on user only from SYSTEM context)
# For all users: deploy via GPO or use HKU iteration
$UserProxyPath = "HKCU:\Software\Policies\Microsoft\Internet Explorer\Control Panel"
New-Item -Path $UserProxyPath -Force | Out-Null
Set-ItemProperty -Path $UserProxyPath -Name Proxy -Value 1 -Type DWord

# Lock proxy settings for all existing user profiles via HKU hive
Write-Output "Applying proxy lock to all user profiles..."
$UserHives = Get-ChildItem "HKU:\" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "S-1-5-21" }
foreach ($hive in $UserHives) {
    $uPath = "HKU:\$($hive.PSChildName)\Software\Policies\Microsoft\Internet Explorer\Control Panel"
    try {
        New-Item -Path $uPath -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $uPath -Name Proxy -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Output "  ✅ Proxy locked for profile: $($hive.PSChildName)"
    } catch {
        Write-Warning "  ⚠️ Could not set proxy lock for profile $($hive.PSChildName): $_"
    }
}

Write-Output "✅ Proxy change restrictions applied."

# -------------------------
# DISABLE NEW NETWORK ADAPTERS
# -------------------------
$DevInstallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
New-Item -Path $DevInstallPath -Force | Out-Null
Set-ItemProperty -Path $DevInstallPath -Name DenyUnspecified     -Value 1 -Type DWord
Set-ItemProperty -Path $DevInstallPath -Name DenyRemovableDevices -Value 1 -Type DWord
Write-Output "✅ New NIC / USB network adapter installation blocked."

# -------------------------
# ENABLE FIREWALL LOGGING
# -------------------------
Set-NetFirewallProfile -Profile Domain,Private,Public `
    -LogAllowed True `
    -LogBlocked True `
    -LogMaxSizeKilobytes 32767 `
    -LogFileName "$env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
Write-Output "✅ Firewall logging enabled (32MB log, all allowed + blocked)."

# -------------------------
# SUMMARY REPORT
# -------------------------
$RuleCount = (Get-NetFirewallRule -DisplayName "$Prefix-*" -ErrorAction SilentlyContinue).Count
Write-Output ""
Write-Output "============================================"
Write-Output " ✅ Zero Trust Hardening Applied Successfully"
Write-Output "============================================"
Write-Output " Rules created  : $RuleCount"
Write-Output " Firewall backup: $BackupPath"
Write-Output " Log file       : $env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
Write-Output " REMINDER       : FQDN-based allow rules used IP resolution at script runtime."
Write-Output "                  For durable FQDN filtering, use Azure Firewall or Defender for Endpoint."
Write-Output "============================================"
