# ============================================
# ZERO TRUST DIAGNOSTIC SCRIPT
# Run as SYSTEM/Admin — shows exactly why
# traffic is not being blocked
# ============================================

Write-Output "=========================================="
Write-Output " ZERO TRUST FIREWALL DIAGNOSTIC REPORT"
Write-Output " $(Get-Date)"
Write-Output "=========================================="

# ------------------------------------------
# 1. CHECK DEFAULT OUTBOUND ACTION
# ------------------------------------------
Write-Output ""
Write-Output "--- [1] DEFAULT OUTBOUND ACTION PER PROFILE ---"
$profiles = Get-NetFirewallProfile -Profile Domain,Private,Public
foreach ($p in $profiles) {
    $status = if ($p.DefaultOutboundAction -eq "Block") { "BLOCK (correct)" } else { "*** ALLOW *** <-- THIS IS YOUR PROBLEM" }
    Write-Output "  $($p.Name): $status"
    Write-Output "    Enabled: $($p.Enabled)"
}

# ------------------------------------------
# 2. WHICH PROFILE IS ACTIVE RIGHT NOW
# ------------------------------------------
Write-Output ""
Write-Output "--- [2] CURRENTLY ACTIVE NETWORK PROFILE ---"
try {
    $activeProfiles = Get-NetConnectionProfile -ErrorAction Stop
    foreach ($ap in $activeProfiles) {
        Write-Output "  Interface : $($ap.InterfaceAlias)"
        Write-Output "  Profile   : $($ap.NetworkCategory)"
        Write-Output "  Name      : $($ap.Name)"
    }
} catch {
    Write-Warning "  Could not get active profile: $_"
}

# ------------------------------------------
# 3. IS WINDOWS FIREWALL EVEN ENABLED?
# ------------------------------------------
Write-Output ""
Write-Output "--- [3] FIREWALL SERVICE & STATE ---"
$svc = Get-Service -Name mpssvc -ErrorAction SilentlyContinue
Write-Output "  Windows Firewall Service (mpssvc): $($svc.Status)"

$fwState = netsh advfirewall show allprofiles state
Write-Output "  Raw netsh state:"
$fwState | ForEach-Object { Write-Output "    $_" }

# ------------------------------------------
# 4. ANY 3RD PARTY FIREWALL / SECURITY SOFTWARE?
# ------------------------------------------
Write-Output ""
Write-Output "--- [4] SECURITY PRODUCTS (may override Windows Firewall) ---"
$secProds = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
foreach ($s in $secProds) {
    Write-Output "  AV: $($s.displayName) | State: $($s.productState)"
}
$fwProds = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName FirewallProduct -ErrorAction SilentlyContinue
foreach ($f in $fwProds) {
    Write-Output "  FW: $($f.displayName) | State: $($f.productState)"
}
if (-not $secProds -and -not $fwProds) {
    Write-Output "  None detected via SecurityCenter2"
}

# ------------------------------------------
# 5. COUNT ZT RULES ACTUALLY IN PLACE
# ------------------------------------------
Write-Output ""
Write-Output "--- [5] ZT-HARD RULES IN WINDOWS FIREWALL ---"
$ztRules = Get-NetFirewallRule -DisplayName "ZT-Hard-*" -ErrorAction SilentlyContinue
Write-Output "  Total ZT-Hard rules found: $($ztRules.Count)"
if ($ztRules.Count -eq 0) {
    Write-Output "  *** NO ZT RULES FOUND — script may not have run, or ran on a different profile ***"
} else {
    Write-Output "  Allow rules : $(($ztRules | Where-Object Action -eq 'Allow').Count)"
    Write-Output "  Block rules : $(($ztRules | Where-Object Action -eq 'Block').Count)"
    Write-Output "  Enabled     : $(($ztRules | Where-Object Enabled -eq 'True').Count)"
    Write-Output "  Disabled    : $(($ztRules | Where-Object Enabled -eq 'False').Count)"
}

# ------------------------------------------
# 6. ANY CONFLICTING ALLOW-ALL RULES?
# ------------------------------------------
Write-Output ""
Write-Output "--- [6] SUSPICIOUS BROAD ALLOW RULES (non-ZT) ---"
$allRules = Get-NetFirewallRule -Direction Outbound -Action Allow -Enabled True -ErrorAction SilentlyContinue
$broadRules = foreach ($r in $allRules) {
    $portFilter = $r | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
    $addrFilter = $r | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue
    $appFilter  = $r | Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue

    $isAnyPort    = ($portFilter.RemotePort -eq "Any")
    $isAnyAddr    = ($addrFilter.RemoteAddress -eq "Any")
    $isAnyApp     = ($appFilter.Program -eq "Any" -or $appFilter.Program -eq "*")

    if ($isAnyPort -and $isAnyAddr -and $isAnyApp) {
        [PSCustomObject]@{
            Name    = $r.DisplayName
            Profile = $r.Profile
            Action  = $r.Action
        }
    }
}
if ($broadRules) {
    Write-Output "  *** FOUND BROAD ALLOW-ALL RULES — these will bypass your block ***"
    $broadRules | ForEach-Object { Write-Output "    - $($_.Name) | Profile: $($_.Profile)" }
} else {
    Write-Output "  No obvious allow-all outbound rules found."
}

# ------------------------------------------
# 7. CHECK FOR GROUP POLICY OVERRIDES
# ------------------------------------------
Write-Output ""
Write-Output "--- [7] GROUP POLICY FIREWALL OVERRIDES ---"
$gpFirewall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ErrorAction SilentlyContinue
if ($gpFirewall) {
    Write-Output "  GPO DomainProfile found:"
    Write-Output "    EnableFirewall         : $($gpFirewall.EnableFirewall)"
    Write-Output "    DefaultOutboundAction  : $($gpFirewall.DefaultOutboundAction)"
    Write-Output "    AllowLocalPolicyMerge  : $($gpFirewall.AllowLocalPolicyMerge)"
    if ($gpFirewall.AllowLocalPolicyMerge -eq 0) {
        Write-Output "  *** GPO is BLOCKING local rules from merging — your script rules may be IGNORED ***"
    }
} else {
    Write-Output "  No GPO firewall policy found for DomainProfile."
}

$gpFWPublic = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" -ErrorAction SilentlyContinue
if ($gpFWPublic) {
    Write-Output "  GPO PublicProfile DefaultOutboundAction: $($gpFWPublic.DefaultOutboundAction)"
    Write-Output "  GPO PublicProfile AllowLocalPolicyMerge: $($gpFWPublic.AllowLocalPolicyMerge)"
}

# ------------------------------------------
# 8. INTUNE / MDM FIREWALL POLICY CHECK
# ------------------------------------------
Write-Output ""
Write-Output "--- [8] MDM/INTUNE FIREWALL POLICY ---"
$mdmFW = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Firewall" -ErrorAction SilentlyContinue
if ($mdmFW) {
    Write-Output "  MDM Firewall policy present:"
    $mdmFW | Format-List | Out-String | ForEach-Object { Write-Output "    $_" }
} else {
    Write-Output "  No MDM Firewall policy detected."
}

# ------------------------------------------
# 9. LIVE CONNECTIVITY TEST
# ------------------------------------------
Write-Output ""
Write-Output "--- [9] LIVE CONNECTIVITY TESTS ---"
$tests = @(
    @{ Host="google.com";                  Port=443; Expected="BLOCKED" },
    @{ Host="8.8.8.8";                     Port=53;  Expected="ALLOWED" },
    @{ Host="login.microsoftonline.com";   Port=443; Expected="ALLOWED" },
    @{ Host="1.1.1.1";                     Port=443; Expected="BLOCKED" },
    @{ Host="example.com";                 Port=80;  Expected="BLOCKED" }
)

foreach ($t in $tests) {
    try {
        $result = Test-NetConnection -ComputerName $t.Host -Port $t.Port -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction Stop
        $actual = if ($result) { "ALLOWED" } else { "BLOCKED" }
    } catch {
        $actual = "BLOCKED"
    }
    $match = if ($actual -eq $t.Expected) { "OK" } else { "*** MISMATCH ***" }
    Write-Output "  $($t.Host):$($t.Port) => $actual (expected $($t.Expected)) $match"
}

# ------------------------------------------
# 10. EFFECTIVE POLICY (what netsh actually sees)
# ------------------------------------------
Write-Output ""
Write-Output "--- [10] EFFECTIVE OUTBOUND POLICY (netsh) ---"
netsh advfirewall show allprofiles | Select-String -Pattern "Outbound|State|Firewall" | ForEach-Object {
    Write-Output "  $($_.Line.Trim())"
}

Write-Output ""
Write-Output "=========================================="
Write-Output " END OF DIAGNOSTIC REPORT"
Write-Output "=========================================="
