try {
    $intuneKey = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $enrollments = Get-ChildItem -Path $intuneKey -ErrorAction Stop

    $enrollmentID = foreach ($enrollment in $enrollments) {
        $props = Get-ItemProperty -Path $enrollment.PSPath -ErrorAction SilentlyContinue
        if ($props.ProviderID -eq "MS DM Server") {
            $enrollment.PSChildName
            break
        }
    }

    if (-not $enrollmentID) {
        Write-Output "Device is not enrolled in Intune. Cannot remediate."
        exit 1
    }

    # Trigger sync via scheduled tasks
    $taskPath = "\Microsoft\Windows\EnterpriseMgmt\$enrollmentID\"
    $syncTasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop |
        Where-Object { $_.TaskName -like "PushLaunch*" -or $_.TaskName -eq "Schedule #3 created by enrollment client" }

    $tasksTriggered = 0
    foreach ($task in $syncTasks) {
        Start-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue
        $tasksTriggered++
    }

    # Trigger sync via IME service restart
    Restart-Service -Name IntuneManagementExtension -Force -ErrorAction SilentlyContinue

    # Trigger sync via MDM WMI bridge
    $session = New-CimSession -ErrorAction SilentlyContinue
    if ($session) {
        $namespaceName = "root\cimv2\mdm\dmmap"
        $className = "MDM_DeviceAction_Provider01"

        try {
            Invoke-CimMethod -Namespace $namespaceName -ClassName $className `
                -MethodName "SyncML" -CimSession $session -ErrorAction Stop
        }
        catch {
            # SyncML method may not be available on all builds; continue
        }
        Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
    }

    Write-Output "Remediation complete. Triggered $tasksTriggered sync task(s) and restarted IME service."
    exit 0
}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}


# SIG # Begin signature block
# MIIQqAYJKoZIhvcNAQcCoIIQmTCCEJUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6cjKI9efJOCt8iAAnNEidi8y
# 2cyggg4UMIIGLzCCBBegAwIBAgITTgAAAAcCvNZR4FPQtwAAAAAABzANBgkqhkiG
# 9w0BAQ0FADAWMRQwEgYDVQQDEwtFRFUgUk9PVCBDQTAeFw0yMjExMDMwODQ4MzNa
# Fw0zMjExMDMwODU4MzNaMEYxEjAQBgoJkiaJk/IsZAEZFgJxYTEWMBQGCgmSJomT
# 8ixkARkWBnNlY2VkdTEYMBYGA1UEAxMPRURVIElTU1VJTkcgQ0ExMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEArgRAZJTH7AYuWo06gSd9fduraDqA0Bce
# TMYiaxUyzMMiT7uledTSenY/uyZjZV64CxL2FCQtJdGSw/ao3+HNCMKxoVovch9J
# 7nb4jwpJ0ZQmFPqasJlyxfw7HVAwPtN1rWH+X4iBmd7rtlWtTRaesiKOKsl2T6vB
# 2kFL4sZDoOdO5Rpd3x1MEjxXw5nNULHIAEzyrStSvE1B9Q9iuOVSFU32lLvT4+p3
# xwiPZRXYuzWqN8RXwOJDIoo2YFJv2lsnmIJ8hRMJez5YH5Bsz30lMtQRGI+VSCt3
# iLaPvRs9BaD10YRplNVF7WlmYupL54B5DdkZEwW65SCvD+n0KxGrTimAd1AWXAOZ
# au8YO4j7X9oZkfRcStKU3tvl7CMHRJugHIQdB+Cx/Dg6+FkLcz+OOGrXTslqlFmH
# FGI/k/Wf8OzZcAKFNK8ZODH/YJc0JNzvPlWljsmq/42yQVSNeANEgCDlhq0VgAMI
# UcxFHHsHCRaiYAC+KRZihC5vjHcACeQJedEs7UvEwbaG5+hyyjyFPMCf8XpFyeO5
# /qIPgBzKo6wUtLQPOPJlNehVCasQptiPWd/+/uIlTJZyYvOogJNgfITamuoKvSMt
# QPY2GjeAUY0v+kfqporov3VthpS+K1OmKNqgf0g0enBoLl3rObxI/tOtuqLoC80Z
# meA/0D+vOJkCAwEAAaOCAUQwggFAMBAGCSsGAQQBgjcVAQQDAgECMCMGCSsGAQQB
# gjcVAgQWBBQSkr6SvH/HlXVGp8M6P2a4oaVyZzAdBgNVHQ4EFgQU+mlLPOuT9CW0
# XJnxGSFX1akDp6UwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQD
# AgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUHRCUNY5PkcXUNdz02x0w
# 6SM81FEwOQYDVR0fBDIwMDAuoCygKoYoaHR0cDovL3BraS5lZHUuZ292LnFhL3Br
# aS9FRFUtUk9PVENBLmNybDBTBggrBgEFBQcBAQRHMEUwQwYIKwYBBQUHMAKGN2h0
# dHA6Ly9wa2kuZWR1Lmdvdi5xYS9wa2kvRURVLVJPT1RDQUVEVSUyMFJPT1QlMjBD
# QS5jcnQwDQYJKoZIhvcNAQENBQADggIBAFfaSDREhYWHEiep5rDcDpRKBAZtjWon
# mEl8i+p5dmjmL+5J9BarI76b2z3Up2GFcZeTXnb7Q9ExC22KyQ1zO2h3tEad5Hv6
# efA0V68XEb0/KX2XZHuRqoVslK6dQXX3RSKV5DaKHsSC7mgQkhAfL1voCRJsx4ce
# dYrgUHnk4OureKHOn3x4ppqtljmbbt4lroL9gAI6EwjB9cAcqLyazbGtKW/ykHKn
# /1VCN0VbUKwix0d0PvQLXwuIRL1zTCJZXpUgiG19kUOtJUh6Ul9wil1KM0BeDpOR
# q0X08L/pKp2jSiDZ2eZ4hgrPvr+Eqp3TquAawlZSk8YC7+CrzMmWfhorK8+7+LHP
# PpHAdGsZIlnIz+/gdsuIS0UC5InmxLSPXbT3F0te4Y/0t84f4LgUPwiT9/SwXq5t
# gTR4bbs8bI9Ct1mOUoBcEf6s6jew7NuAuR6weLNaV4LSnZMF1y39cvbc0OidPJts
# 41W6710nloJ+u1uYC8GQcJCwxQOwFq/zH0ROTk2o54Qq7TiAfa1isi9m0DIPL2iW
# oSPLl0HwNtqCWIJ7Ry80CrXoKwQwPwObqUk69XJiojwd2x9WvgG+nwVO17sQlXto
# tgwmGRcpuIz83/O8OsIu2g0rCp1vPS3bdb7z/Y/zFLMjOoPn3JidiSzJ0I6QcjJg
# yZdLPU741V9uMIIH3TCCBcWgAwIBAgITKQAB4Ipwsty+ThrPJwACAAHgijANBgkq
# hkiG9w0BAQ0FADBGMRIwEAYKCZImiZPyLGQBGRYCcWExFjAUBgoJkiaJk/IsZAEZ
# FgZzZWNlZHUxGDAWBgNVBAMTD0VEVSBJU1NVSU5HIENBMTAeFw0yNTA5MDcwODI3
# MjlaFw0zMDA5MDYwODI3MjlaMIGKMRIwEAYKCZImiZPyLGQBGRYCcWExFjAUBgoJ
# kiaJk/IsZAEZFgZzZWNlZHUxDDAKBgNVBAsTA1BBVzEOMAwGA1UECxMFQWRtaW4x
# DzANBgNVBAsTBlRpZXIgMDEUMBIGA1UECxMLVDAtQWNjb3VudHMxFzAVBgNVBAMT
# Dk1PRS1Db2RlU2lnbmVyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# zOdBiPu6Z2IirpWIPlCAkf1n/09d2PLP95A5B9wnAL6kq97ye2REG4b0/x0mFrx7
# 52sDpTG+k5C+p2Xn3CgQiMDl8maON6AWtEIyayPuigZUrUxq5O1+iOeV5ikfX15C
# r7bpHw6R7Dr0DNHxXvoEIdj5aW/wIS2/oq9ZOOFfZ2FI9Y3at5PRkZGin7eU9laB
# y0ROtvLQ6P6hO9Y+vKj2ZyDrytv+dtG4V+cCCpOHTbJ/MBrdhHr1cGr0xYUqXg/5
# LHvz6eTXTwJ0+zWoleEkP4Lc5bG3iwWhH0qDy5ah2SZmn6fCkyRUruPGYrSUMnKn
# g7VL3aQneTdusMH+/cRCGQIDAQABo4IDfTCCA3kwPAYJKwYBBAGCNxUHBC8wLQYl
# KwYBBAGCNxUI6O9FhMmsd4T1lQ6CpdAphu+FT2KGmvlZhvy+YwIBZAIBCzATBgNV
# HSUEDDAKBggrBgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwGwYJKwYBBAGCNxUKBA4w
# DDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUeghrjGk9M01i7paK1zkyps8EzB4wHwYD
# VR0jBBgwFoAU+mlLPOuT9CW0XJnxGSFX1akDp6UwggEBBgNVHR8EgfkwgfYwgfOg
# gfCgge2Ggb5sZGFwOi8vL0NOPUVEVSUyMElTU1VJTkclMjBDQTEsQ049RENQUEtJ
# SVNTVUUwMSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vy
# dmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1zZWNlZHUsREM9cWE/Y2VydGlmaWNh
# dGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlv
# blBvaW50hipodHRwOi8vcGtpLmVkdS5nb3YucWEvcGtpL0VEVS1JU1NVSU5HMS5j
# cmwwggEpBggrBgEFBQcBAQSCARswggEXMIGwBggrBgEFBQcwAoaBo2xkYXA6Ly8v
# Q049RURVJTIwSVNTVUlORyUyMENBMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIw
# U2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1zZWNlZHUs
# REM9cWE/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRp
# b25BdXRob3JpdHkwOQYIKwYBBQUHMAKGLWh0dHA6Ly9wa2kuZWR1Lmdvdi5xYS9w
# a2kvRURVLUlTU1VJTkcxKDIpLmNydDAnBggrBgEFBQcwAYYbaHR0cDovL29jc3Au
# ZWR1Lmdvdi5xYS9vY3NwMDMGA1UdEQQsMCqgKAYKKwYBBAGCNxQCA6AaDBhNT0Ut
# Q29kZVNpZ25lckBzZWNlZHUucWEwUAYJKwYBBAGCNxkCBEMwQaA/BgorBgEEAYI3
# GQIBoDEEL1MtMS01LTIxLTk1NTgyMDY0Ny04MjQzNTk0MjAtMzAyNjQ2NzkyMS0z
# OTM5MTEzMA0GCSqGSIb3DQEBDQUAA4ICAQBU4Pc2JsqF6qT7+J52lfKjs1GPsI3i
# bgSNf5tdQbpJx+PjC51sMXn3lm+7RIAHdf3PTh1NQRdL6rTxnJKCTnGCQwPIVE+w
# S/0OUrs33NMq7crx1FF+DRC6F9ivFQRZjNkrfeBxmb1mxLUCjXOa3GCNvKjvAv4r
# DltiHn2mQejAiizpw7q+YTsvJfqODz6gapoAjbxkboVoeMjlWIj/BZtPR2m5Z5Is
# uSqMllAbm3XDeoqY7dDmMD840lz4gTc72u4tXbfQgYxAO042l2+TAB/qNOaaNCPu
# sOlszW3qNO4XLBohYuQeWi/qclCpedMCxY5leRpLiT/NuxiQlSsdSAAIrq1JXlMO
# bQuTscc6S6iDFlEH6ggheg2jbudvytt95qhvfUQ11+S0dm/ML1UdaNol0I1elX2g
# Gl2u+VRLVIPz+RX11Y3oSScch5lDofA/X7EIEWZJPZ9SrcfT3FtSZm4FDhjrI8Y0
# 9OfN2TzQljxpJxtEL95t7cB6Nc4QhR2AMrG9qC9ikk4Msk/lMrI4fftlDh3zZP12
# 6lQVeyST2ffRpeiqCLmF7xq+jAsA4iUq2+VoRV43wFzP+Z4X9stdNZvbv+sJSxL8
# rFLYapdmt2KaClGHwlNhbIlhXVHp3yj53yQXfsEMMd2MOBOgIH5V0HjSy1rHlm7E
# nGk25Vhe4/bluzGCAf4wggH6AgEBMF0wRjESMBAGCgmSJomT8ixkARkWAnFhMRYw
# FAYKCZImiZPyLGQBGRYGc2VjZWR1MRgwFgYDVQQDEw9FRFUgSVNTVUlORyBDQTEC
# EykAAeCKcLLcvk4azycAAgAB4IowCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFDrSIY+cmnaPwgzH
# Nzy8nixNnwmmMA0GCSqGSIb3DQEBAQUABIIBAFf0iVg8JEToJjeUSFEbxC7ng1rS
# K9sHnXbWW2rMxYdzapGxjF6zCgms1IVXGrWGNAbZpG7pAMPZLeazeIhGWTd+QBUB
# HtP18gMAvgzstTV3nSe5rv794ykVtCoBkxxxmAFBqONOyc6ks5+rVXVCCPQE9wgO
# gqWaBBNqQY7D3ZzuA0LWy0lsMacRQ9H4Y/xe/vntHp6tVlD/mNFGp0e6mesJ7Elf
# W80RvK7Zj5ZI64ODL/kVn78h3xboeZ2WDVjGneo3rPSl6jMR+gDNS3C0hpAEnlrN
# etfHoeGlz24wjQwXSjpMa8xX6UejDwhLTTotLWHt5u7NrP3Xg671OhwFXJY=
# SIG # End signature block
