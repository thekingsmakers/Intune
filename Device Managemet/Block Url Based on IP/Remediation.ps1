# Define the list of specific public IPs to monitor
$specificPublicIPs = @(")  # Replace with your list of IPs

# Define the domain to block/unblock
$domainToBlock = "api.euwe1.uds.lenovo.com"

# Function to get the current public IP of the device
function Get-PublicIP {
    try {
        return (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
    } catch {
        Write-Host "Failed to retrieve public IP: $_"
        exit 1  # Exit code 1 indicates failure
    }
}

# Function to resolve a domain to its IP addresses using Resolve-DnsName
function Resolve-DomainIPs {
    param (
        [string]$domain
    )
    try {
        # Use Resolve-DnsName to get IP addresses for the domain
        $dnsResults = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
        $ips = $dnsResults.IPAddress
        
        # Ensure we have an array even if only one IP is returned
        if ($ips -isnot [array]) {
            $ips = @($ips)
        }
        
        Write-Host "Resolved $($ips.Count) IP(s) for domain $domain"
        return $ips
    } catch {
        Write-Host "Failed to resolve domain IPs: $_"
        exit 1  # Exit code 1 indicates failure
    }
}

# Function to block all ports for a list of IPs
function Block-AllPorts {
    param (
        [array]$ips,
        [string]$domain
    )
    try {
        Write-Host "Attempting to block $($ips.Count) IP(s)..."
        foreach ($ip in $ips) {
            $ruleName = "Block_$($domain.Replace('.', '_'))_$ip"
            if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
                Write-Host "Creating new rule for IP: $ip"
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $ip -Profile Any -ErrorAction Stop
                Write-Host "Firewall rule created to block IP: $ip on all ports"
                
                # Verify the rule was created
                $createdRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                if ($createdRule) {
                    Write-Host "Verified rule exists: $($createdRule.DisplayName)"
                } else {
                    Write-Host "Warning: Unable to verify rule creation for IP: $ip"
                }
            } else {
                Write-Host "Firewall rule already exists for IP: $ip on all ports"
            }
        }
        
        # List all related rules for verification
        $allRules = Get-NetFirewallRule -DisplayName "Block_$($domain.Replace('.', '_'))*" -ErrorAction SilentlyContinue
        Write-Host "Current rules for $domain ($($allRules.Count) total):"
        foreach ($rule in $allRules) {
            Write-Host "  - $($rule.DisplayName)"
        }
    } catch {
        Write-Host "An error occurred while blocking IPs: $_"
        exit 1  # Exit code 1 indicates failure
    }
}

# Function to unblock all ports for a list of IPs
function Unblock-AllPorts {
    param (
        [array]$ips,
        [string]$domain
    )
    try {
        Write-Host "Attempting to unblock $($ips.Count) IP(s)..."
        foreach ($ip in $ips) {
            $ruleName = "Block_$($domain.Replace('.', '_'))_$ip"
            if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
                Write-Host "Removing rule for IP: $ip"
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
                Write-Host "Firewall rule removed to unblock IP: $ip on all ports"
                
                # Verify the rule was removed
                $removedRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                if (-not $removedRule) {
                    Write-Host "Verified rule removed: $ruleName"
                } else {
                    Write-Host "Warning: Unable to verify rule removal for IP: $ip"
                }
            } else {
                Write-Host "No firewall rule exists for IP: $ip on all ports"
            }
        }
        
        # Check if any rules remain
        $remainingRules = Get-NetFirewallRule -DisplayName "Block_$($domain.Replace('.', '_'))*" -ErrorAction SilentlyContinue
        Write-Host "Remaining rules for $domain ($($remainingRules.Count) total):"
        foreach ($rule in $remainingRules) {
            Write-Host "  - $($rule.DisplayName)"
        }
    } catch {
        Write-Host "An error occurred while unblocking IPs: $_"
        exit 1  # Exit code 1 indicates failure
    }
}

# Main script logic
try {
    # Get the current public IP of the device
    $currentPublicIP = Get-PublicIP
    Write-Host "Current public IP: $currentPublicIP"

    # Check if the current public IP matches any of the specified public IPs
    $isMatch = $specificPublicIPs -contains $currentPublicIP

    if ($isMatch) {
        Write-Host "Device is connected to one of the specified public IPs."
        Write-Host "Resolving $domainToBlock to get all IP addresses..."
        $domainIPs = Resolve-DomainIPs -domain $domainToBlock
        if ($domainIPs.Count -eq 0) {
            Write-Host "No IP addresses resolved for $domainToBlock"
            exit 1
        }
        Write-Host "Resolved IPs for $($domainToBlock): $($domainIPs -join ', ')"

        Write-Host "Blocking all ports for resolved IPs..."
        Block-AllPorts -ips $domainIPs -domain $domainToBlock
    } else {
        Write-Host "Device is not connected to any of the specified public IPs."
        Write-Host "Resolving $domainToBlock to get all IP addresses..."
        $domainIPs = Resolve-DomainIPs -domain $domainToBlock
        if ($domainIPs.Count -eq 0) {
            Write-Host "No IP addresses resolved for $domainToBlock"
            exit 1
        }
        Write-Host "Resolved IPs for $($domainToBlock): $($domainIPs -join ', ')"

        Write-Host "Unblocking all ports for resolved IPs..."
        Unblock-AllPorts -ips $domainIPs -domain $domainToBlock
    }

    Write-Host "Remediation completed successfully."
    exit 0  # Exit code 0 indicates success
} catch {
    Write-Host "An error occurred during remediation: $_"
    exit 1  # Exit code 1 indicates failure
}
