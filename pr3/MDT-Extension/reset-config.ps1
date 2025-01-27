# Create default XML configuration
$xmlContent = @"
<?xml version='1.0' encoding='UTF-8'?>
<Configuration>
    <DeviceNaming>
        <Prefix></Prefix>
    </DeviceNaming>
    <DomainJoin>
        <Enabled>false</Enabled>
        <DomainName></DomainName>
        <DomainIP></DomainIP>
        <OUPath></OUPath>
        <Credentials>
            <Username></Username>
            <Password></Password>
        </Credentials>
    </DomainJoin>
    <WindowsActivation>
        <ProductKey></ProductKey>
    </WindowsActivation>
    <SoftwareInstallation>
        <Packages>
        </Packages>
    </SoftwareInstallation>
</Configuration>
"@

# Create directory if it doesn't exist
$configDir = "MDT-Extension\Configuration"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
}

# Save the configuration
$configPath = Join-Path $configDir "config.xml"
$xmlContent | Out-File -FilePath $configPath -Encoding UTF8 -Force