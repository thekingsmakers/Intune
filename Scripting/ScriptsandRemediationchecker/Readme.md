# Intune Remediation Runner (by @thekingsmakers)

A modern PowerShell GUI tool (packaged as an EXE) designed to simplify **Intune detection and remediation script execution**.  
It provides a user-friendly interface, script validation, branding, and informative logging.
<img width="1147" height="662" alt="image" src="https://github.com/user-attachments/assets/192a3ad5-0a44-413e-850f-4597fd4c6c2c" />

---

## ✨ Features
- **Modern GUI** – Clean design, easy navigation, Windows-like styling.
- **Script Uploads** – Browse and upload both detection and remediation scripts.
- **Automatic Logic** – 
  - Detection script runs first.  
  - If remediation is required, the remediation script runs automatically.  
  - If not required, it is skipped with clear feedback.
- **Script Validation** – Follows [Microsoft documentation](https://learn.microsoft.com/mem/intune/fundamentals/intune-management-extension) best practices:
  - Ensures scripts are valid PowerShell before execution.
  - Supports signed scripts if your environment enforces execution policies.
- **Logging & Output** – 
  - Logs all activity with timestamps.
  - Provides real-time feedback in the GUI.
  - Export results to **CSV** or **JSON** for auditing.
- **Branding** – Includes `@thekingsmakers` branding and footer.

---

## 📥 Installation
1. Copy the EXE file to your workstation.
2. No installation required – the EXE is portable.
3. Double-click the EXE to launch the tool.

---

## 🚀 Usage
1. **Launch the Tool**  
   Double-click the EXE. The GUI will open.

2. **Upload Scripts**  
   - Click **Browse** under *Detection Script* and select your `.ps1` detection script.  
   - Click **Browse** under *Remediation Script* and select your `.ps1` remediation script.  

3. **Run**  
   - The tool automatically executes the detection script.  
   - If remediation is needed, the remediation script runs immediately after.  
   - If no remediation is needed, the GUI will inform you.  

4. **Review Logs**  
   - Logs are displayed in the bottom panel.  
   - Export logs to CSV or JSON for reporting.

---

## ⚠️ Notes
- Ensure the scripts you upload are **trusted and validated**.  
- If your organization enforces **script signing**, upload signed scripts only.  
- Run the EXE with **administrative privileges** for full functionality (required for most remediation tasks).

---

## 🛠 Example Use Cases
- Validate and remediate **daily issue** with Intune.  
- Check and repair **device health check remediation**.  
- Automate repetitive detection & remediation workflows.

---

## 🧑‍💻 Author
**Developed & branded by @thekingsmakers (2025)**  
All rights reserved.
