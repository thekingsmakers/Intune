# Settings
$batchSize = 20
$maxRetries = 3
$delayMs = 500
$logFile = "owners_log.txt"

# Get all devices
$devices = Get-MgDevice -All -Property id,displayName,deviceId

$total = $devices.Count
$counter = 0

# Helper: log
function Write-Log {
    param($msg)
    $msg | Out-File $logFile -Append
}

# Helper: build batch body
function New-BatchBody {
    param($items)

    $requests = @()
    foreach ($item in $items) {
        $requests += @{
            id = $item.id
            method = "GET"
            url = "/devices/$($item.id)/registeredOwners"
        }
    }

    return @{ requests = $requests }
}

# Store results
$results = @()

# Process in batches
for ($i = 0; $i -lt $total; $i += $batchSize) {

    $batch = $devices[$i..([Math]::Min($i+$batchSize-1,$total-1))]

    $body = New-BatchBody $batch

    $retry = 0
    $success = $false

    while (-not $success -and $retry -lt $maxRetries) {
        try {
            $response = Invoke-MgGraphRequest -Method POST `
                -Uri "https://graph.microsoft.com/v1.0/`$batch" `
                -Body ($body | ConvertTo-Json -Depth 10)

            foreach ($r in $response.responses) {

                $dev = $batch | Where-Object { $_.id -eq $r.id }

                $owners = @()

                if ($r.body.value) {
                    foreach ($o in $r.body.value) {
                        if ($o.'@odata.type' -eq '#microsoft.graph.user') {
                            $owners += $o.userPrincipalName
                        }
                    }
                }

                $results += [pscustomobject]@{
                    DeviceName = $dev.displayName
                    DeviceId   = $dev.deviceId
                    Owners     = ($owners -join ",")
                }
            }

            $success = $true
            Write-Log "Batch $i success"

        } catch {
            $retry++
            Write-Log "Batch $i failed (retry $retry): $_"
            Start-Sleep -Milliseconds ($delayMs * $retry)
        }
    }

    $counter += $batch.Count
    Write-Progress -Activity "Processing devices" `
        -Status "$counter / $total" `
        -PercentComplete (($counter / $total) * 100)

    Start-Sleep -Milliseconds 200
}

# Export
$results | Export-Csv "DeviceOwners.csv" -NoTypeInformation -Encoding UTF8
