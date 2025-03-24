$SEP = Get-Package -Name 'Symantec Endpoint Protection' -ErrorAction SilentlyContinue
$SEPinstalled = $SEP.Name
$SEPversion = $SEP.Version
$hash = @{ Name = $SEPinstalled; Version = $SEPversion }
return $hash | ConvertTo-Json -Compress