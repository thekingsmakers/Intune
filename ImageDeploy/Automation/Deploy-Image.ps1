param(
    [string]$ConfigPath = "$PSScriptRoot\Config.xml"
)

Begin {
    $logPath = "$PSScriptRoot\Deployment.log"
    Start-Transcript -Path $logPath -Append
}

Process {
    try {
        # Load configuration
        [xml]$config = Get-Content $ConfigPath

        # 1. Software Deployment
        foreach ($package in $config.DeploymentConfig.Software.Package) {
            $ext = [System.IO.Path]::GetExtension($package)
            switch ($ext) {
                ".msi" {
                    Start-Process "msiexec.exe" -ArgumentList "/i `"$package`" /qn" -Wait
                }
                ".exe" {
                    Start-Process $package -ArgumentList "/S" -Wait
                }
                default {
                    Write-Warning "Unsupported package format: $package"
                }
            }
        }

        # 2. Set Hostname
        $hostname = $config.DeploymentConfig.Hostname
        Rename-Computer -NewName $hostname -Force

        # 3. Configure WiFi
        $ssid = $config.DeploymentConfig.Network.SSID
        $password = $config.DeploymentConfig.Network.Password
        $profileXml = @"
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>${ssid}</name>
    <SSIDConfig>
        <SSID>
            <hex>$(-join ($ssid.ToCharArray() | ForEach-Object { [byte]$_ | ForEach-Object { $_.ToString('X2') } }))</hex>
            <name>${ssid}</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>${password}</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

        $profileXml | Out-File "$env:TEMP\wifi_profile.xml"
        netsh wlan add profile filename="$env:TEMP\wifi_profile.xml"
        netsh wlan connect name="$ssid"

        # 4. Windows Activation
        $productKey = $config.DeploymentConfig.WindowsActivation.ProductKey
        if ($productKey -match "[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}") {
            cscript //b C:\Windows\System32\slmgr.vbs /ipk $productKey
            cscript //b C:\Windows\System32\slmgr.vbs /ato
        }

        # 5. Install Windows Features
        foreach ($feature in $config.DeploymentConfig.Features.Feature) {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
        }

        # 6. Domain Join
        if ($config.DeploymentConfig.Domain.JoinDomain -eq "true") {
            $domain = $config.DeploymentConfig.Domain.DomainName
            $username = $config.DeploymentConfig.Domain.DomainUser
            $password = ConvertTo-SecureString $config.DeploymentConfig.Domain.DomainPassword -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential($username, $password)
            
            Add-Computer -DomainName $domain -Credential $cred -Restart -Force
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

End {
    Stop-Transcript
    if ($config.DeploymentConfig.Domain.JoinDomain -ne "true") {
        Restart-Computer -Force
    }
}