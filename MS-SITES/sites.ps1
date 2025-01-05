$websites = @(
    @{ Name = "Microsoft Entra ID"; URL = "https://aka.ms/MSEntraPortal" },
    @{ Name = "Azure Portal"; URL = "https://portal.azure.com" },
    @{ Name = "Microsoft Intune Admin Center"; URL = "https://intune.microsoft.com/" },
    @{ Name = "Exchange Admin Center"; URL = "https://admin.exchange.microsoft.com" },
    @{ Name = "Microsoft 365 Admin Center"; URL = "https://admin.microsoft.com/AdminPortal/Home" },
    @{ Name = "Microsoft 365 Apps Admin Center"; URL = "https://config.office.com" },
    @{ Name = "Microsoft Defender XDR"; URL = "https://security.microsoft.com" },
    @{ Name = "Microsoft 365 Network Connectivity Test"; URL = "https://connectivity.office.com" },
    @{ Name = "Microsoft 365 Status"; URL = "https://portal.office.com/adminportal/home#/servicehealth" },
    @{ Name = "Microsoft Purview Compliance Portal"; URL = "https://compliance.microsoft.com/homepage" },
    @{ Name = "Microsoft Security Intelligence"; URL = "https://microsoft.com/wdsi" },
    @{ Name = "Microsoft Sentinel"; URL = "https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/WorkspaceSelectorBlade" },
    @{ Name = "MFA Admin Portal"; URL = "https://account.activedirectory.windowsazure.com/usermanagement/multifactorverification.aspx" },
    @{ Name = "Power BI Admin Portal"; URL = "https://app.powerbi.com/admin-portal/tenantSettings?experience=power-bi" },
    @{ Name = "SharePoint Online Admin Center"; URL = "https://admin.microsoft.com/sharepoint" },
    @{ Name = "Teams Admin Center"; URL = "https://admin.teams.microsoft.com" },
    @{ Name = "Teams Call Quality Dashboard"; URL = "https://cqd.teams.microsoft.com/" },
    @{ Name = "Viva Engage Admin Center"; URL = "https://www.yammer.com/office365/admin" },
    @{ Name = "Power Platform Admin Center"; URL = "https://admin.powerplatform.microsoft.com/" }
)

foreach ($site in $websites) {
    try {
        $response = Invoke-WebRequest -Uri $site.URL -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "$($site.Name) is up and running." -ForegroundColor Green
        }
    } catch {
        Write-Host "$($site.Name) is down or unreachable." -ForegroundColor Red
    }
}
