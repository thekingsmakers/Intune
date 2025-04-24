## update Weekly TOR Exit Node Blocklist Using Conditional Access Policy

#Purpose
To ensure the security and integrity of our network by regularly updating the blocklist of TOR exit nodes 
using a conditional access policy.

#Scope
This procedure applies to all IT personnel responsible for maintaining network security.
Procedure
• Obtain the TOR Exit List:
• Navigate to TOR Bulk Exit List using your web browser. 
  https://check.torproject.org/torbulkexitlist
• Download the TOR exit list from the provided link.
  https://check.torproject.org/torbulkexitlist
• Save the List in a File:
• Save the downloaded TOR exit list as TorIPS.txt on your computer.
• Run the PowerShell Command:
• Open PowerShell on your computer.
• Navigate to the directory where TorIPS.txt is saved.
```powershell
Get-Content .\TorIPS.txt | ForEach-Object { $_ + "/32" } | Set-Content newfile.txt
```
• Execute the following PowerShell command to format the IP addresses:
Get-Content .\TorIPS.txt | ForEach-Object { $_ + "/32" } | Set-Content newfile.txt
1. Upload the newfile.txt to Named Locations in Conditional Access Policy:
o Access the Azure portal and navigate to "Azure Active Directory."
o Go to "Security" and then "Conditional Access."
o Select "Named Locations" and choose the location where you want to update the 
blocklist.
o Upload the newfile.txt file to the chosen Named Location.
2. Verify and Save:
o Verify that the IP addresses have been successfully added to the Named Location.
o Save the changes.
3. Schedule Weekly Updates:
o Schedule a recurring task to perform the above steps on a weekly basis to ensure the 
blocklist is always up-to-date.

