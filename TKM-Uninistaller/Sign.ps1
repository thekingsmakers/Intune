<#
    TKM-Uninstaller Signing Helper
    Creates a self-signed certificate and signs TKM-Uninstaller.ps1
#>

param(
    [switch]$CreateCert,
    [switch]$Sign,
    [switch]$Verify,
    [switch]$Export,
    [string]$CertName = "TKM Uninstaller",
    [string]$ScriptPath = ".\TKM-Uninstaller.ps1"
)

$CertStore = "Cert:\CurrentUser\My"
$TimestampServer = "http://timestamp.digicert.com"

function New-TKMCertificate {
    Write-Host "Creating self-signed code signing certificate..." -ForegroundColor Green
    
    try {
        $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$CertName" -CertStoreLocation $CertStore -KeyExportPolicy Exportable -KeyLength 2048 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -HashAlgorithm SHA256 -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
        
        Write-Host "Certificate created successfully!" -ForegroundColor Green
        Write-Host "Thumbprint: $($cert.Thumbprint)" -ForegroundColor Yellow
        Write-Host "Subject: $($cert.Subject)" -ForegroundColor Yellow
        
        return $cert
    } catch {
        Write-Error "Failed to create certificate: $_"
        return $null
    }
}

function Get-TKMCertificate {
    $cert = Get-ChildItem $CertStore -CodeSigningCert | Where-Object { $_.Subject -like "*$CertName*" } | Select-Object -First 1
    
    if (-not $cert) {
        Write-Warning "No certificate found for '$CertName'. Use -CreateCert to create one."
        return $null
    }
    
    return $cert
}

function Set-TKMSignature {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script file not found: $ScriptPath"
        return $false
    }
    
    Write-Host "Signing $ScriptPath..." -ForegroundColor Green
    
    try {
        $signature = Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $Certificate -TimestampServer $TimestampServer
        
        switch ($signature.Status) {
            "Valid" { 
                Write-Host "Script signed successfully!" -ForegroundColor Green
                Write-Host "Signature Status: $($signature.Status)" -ForegroundColor Yellow
                Write-Host "Signer Certificate: $($signature.SignerCertificate.Subject)" -ForegroundColor Yellow
                return $true
            }
            "NotSigned" { 
                Write-Error "Script was not signed"
                return $false
            }
            default { 
                Write-Warning "Signature Status: $($signature.Status)"
                Write-Host "Signer Certificate: $($signature.SignerCertificate.Subject)" -ForegroundColor Yellow
                return $true
            }
        }
    } catch {
        Write-Error "Failed to sign script: $_"
        return $false
    }
}

function Test-TKMSignature {
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script file not found: $ScriptPath"
        return
    }
    
    Write-Host "Verifying signature of $ScriptPath..." -ForegroundColor Green
    
    $signature = Get-AuthenticodeSignature -FilePath $ScriptPath
    
    Write-Host "Signature Status: $($signature.Status)" -ForegroundColor Yellow
    Write-Host "Signer Certificate: $($signature.SignerCertificate.Subject)" -ForegroundColor Yellow
    Write-Host "Timestamp: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor Yellow
    
    if ($signature.Status -eq "Valid") {
        Write-Host "Signature is valid!" -ForegroundColor Green
    } else {
        Write-Host "Signature is not valid" -ForegroundColor Red
    }
}

function Export-TKMCertificate {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    
    $desktop = [Environment]::GetFolderPath("Desktop")
    $cerFile = Join-Path $desktop "TKM-Uninstaller.cer"
    $pfxFile = Join-Path $desktop "TKM-Uninstaller.pfx"
    
    Write-Host "Exporting certificate..." -ForegroundColor Green
    
    try {
        # Export public certificate (.cer)
        Export-Certificate -Cert $Certificate -FilePath $cerFile -Force
        Write-Host "Public certificate exported to: $cerFile" -ForegroundColor Yellow
        
        # Export private key (.pfx) with password
        $password = Read-Host -AsSecureString "Enter password for PFX file"
        Export-PfxCertificate -Cert $Certificate -FilePath $pfxFile -Password $password -Force
        Write-Host "Private certificate exported to: $pfxFile" -ForegroundColor Yellow
        
        Write-Host "`nTo trust this certificate on other machines:" -ForegroundColor Cyan
        Write-Host "1. Copy $cerFile to target machine" -ForegroundColor White
        Write-Host "2. Run as Administrator:" -ForegroundColor White
        Write-Host "   Import-Certificate -FilePath `"$cerFile`" -CertStoreLocation Cert:\LocalMachine\TrustedPublisher" -ForegroundColor Gray
        Write-Host "   Import-Certificate -FilePath `"$cerFile`" -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
        
    } catch {
        Write-Error "Failed to export certificate: $_"
    }
}

# Main execution
if ($CreateCert) {
    $cert = New-TKMCertificate
    if ($cert) {
        Write-Host "`nCertificate created. Use -Sign to sign the script." -ForegroundColor Cyan
    }
}

if ($Sign) {
    $cert = Get-TKMCertificate
    if (-not $cert -and $CreateCert) {
        $cert = New-TKMCertificate
    }
    
    if ($cert) {
        Set-TKMSignature -Certificate $cert
    }
}

if ($Verify) {
    Test-TKMSignature
}

if ($Export) {
    $cert = Get-TKMCertificate
    if ($cert) {
        Export-TKMCertificate -Certificate $cert
    }
}

# Default action if no parameters specified
if (-not ($CreateCert -or $Sign -or $Verify -or $Export)) {
    Write-Host "TKM-Uninstaller Signing Helper" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\Sign.ps1 -CreateCert    # Create new self-signed certificate" -ForegroundColor White
    Write-Host "  .\Sign.ps1 -Sign          # Sign TKM-Uninstaller.ps1" -ForegroundColor White
    Write-Host "  .\Sign.ps1 -Verify        # Verify script signature" -ForegroundColor White
    Write-Host "  .\Sign.ps1 -Export        # Export certificate for distribution" -ForegroundColor White
    Write-Host ""
    Write-Host "Combined:" -ForegroundColor Yellow
    Write-Host "  .\Sign.ps1 -CreateCert -Sign -Export  # Create, sign, and export" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -CertName 'Name'          # Certificate name (default: 'TKM Uninstaller')" -ForegroundColor White
    Write-Host "  -ScriptPath 'Path'        # Script to sign (default: '.\TKM-Uninstaller.ps1')" -ForegroundColor White
}
