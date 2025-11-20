
---

```markdown
# 🐦 PowerShell Snippets 

A curated list of handy PowerShell one-liners and scripts, formatted for quick sharing and easy copy.

---

## 📌 Snippet 1: Re-register All AppX Packages
**Description:**  
This command re-registers all built-in Windows apps for all users. Useful if apps like Start Menu or Calculator stop working.

```powershell
Get-AppXPackage -AllUsers | Foreach {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}
```

[Copy Snippet](#) <!-- Placeholder for copy option -->

---

## 📌 Snippet 2: List Installed Programs
**Description:**  
Quickly list all installed programs with their names and versions.

```powershell
Get-WmiObject -Class Win32_Product | Select-Object Name, Version
```

[Copy Snippet](#)

---

## 📌 Snippet 3: Restart Explorer
**Description:**  
Restart Windows Explorer without rebooting your system.

```powershell
Stop-Process -Name explorer -Force
Start-Process explorer.exe
```

[Copy Snippet](#)

---

## 📌 Snippet 4: Get IP Configuration
**Description:**  
Display detailed IP configuration for all network adapters.

```powershell
Get-NetIPConfiguration
```

[Copy Snippet](#)

---

## 📌 Snippet 5: Find Large Files
**Description:**  
Search for files larger than 100MB in `C:\`.

```powershell
Get-ChildItem -Path C:\ -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 100MB } |
    Sort-Object Length -Descending |
    Select-Object FullName, Length
```

[Copy Snippet](#)
```
