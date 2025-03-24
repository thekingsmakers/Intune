# Define the list of specific public IPs to monitor
$specificPublicIPs = @(
    "10.12.13.150", "10.12.13.151", "10.12.13.152", 
    "10.12.13.153", "10.12.13.154", "10.12.13.155", 
    "10.12.13.156", "10.12.13.157", "10.12.13.158"
)

# Define the domains and ports to block/unblock
$domainsToBlock = @(
    "api-mtls.euwe1.uds.lenovo.com:443", 
    "api.euwe1.uds.lenovo.com:443", 
    "mqtt-mtls.euwe1.uds.lenovo.com:8883"
    
)

# Function to get the current public IP of the device
function Get-PublicIP {
    try {
        return (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
    } catch {
        Write-Host "Failed to retrieve public IP: $_"
        exit 1
    }
}

# Function to resolve a domain to its IP addresses
function Resolve-DomainIPs {
    param ([string]$domain)
    try {
        $dnsResults = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
        return $dnsResults.IPAddress
    } catch {
        Write-Host "Failed to resolve domain IPs: $_"
        exit 1
    }
}

# Function to manage firewall rules
function Manage-Firewall {
    param (
        [array]$ips, [string]$domain, [string]$port, [string]$action
    )
    foreach ($ip in $ips) {
        $ruleName = "Block_$($domain.Replace('.', '_'))_$port_$ip"
        if ($action -eq "Block") {
            if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $ip -Profile Any -LocalPort $port -Protocol TCP -ErrorAction Stop
                Write-Host "Blocked: $ip on port $port"
            } else {
                Write-Host "Already blocked: $ip on port $port"
            }
        } elseif ($action -eq "Unblock") {
            if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
                Write-Host "Unblocked: $ip on port $port"
            } else {
                Write-Host "No rule found for: $ip on port $port"
            }
        }
    }
}

# Main script logic
try {
    $currentPublicIP = Get-PublicIP
    Write-Host "Current public IP: $currentPublicIP"

    $isMatch = $specificPublicIPs -contains $currentPublicIP

    foreach ($domainEntry in $domainsToBlock) {
        $domain, $port = $domainEntry -split ":"
        $domainIPs = Resolve-DomainIPs -domain $domain
        
        if ($isMatch) {
            Write-Host "Device is connected to a specified public IP. Blocking domain $domain on port $port..."
            Manage-Firewall -ips $domainIPs -domain $domain -port $port -action "Block"
        } else {
            Write-Host "Device is not connected to a specified public IP. Unblocking domain $domain on port $port..."
            Manage-Firewall -ips $domainIPs -domain $domain -port $port -action "Unblock"
        }
    }

    Write-Host "Remediation completed successfully."
    exit 0
} catch {
    Write-Host "An error occurred: $_"
    exit 1
}
