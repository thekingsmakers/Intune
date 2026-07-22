# Windows Image Export Tool

A simple PowerShell GUI for exporting a single Windows image from a **WIM** or **ESD** file into a new **install.wim**.

The tool uses the built-in Windows **DISM** engine and provides an easy graphical interface for selecting the source image, choosing an image index, and exporting it with maximum compression.

## Features

- Supports both **.wim** and **.esd** source images
- Displays all available Windows image indexes
- Select the image index from a graphical list
- Browse for an output folder
- Exports the selected image as **install.wim**
- Uses:
  - `/Compress:Max`
  - `/CheckIntegrity`
- Warns before overwriting an existing `install.wim`
- No third-party dependencies

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later
- Administrator privileges
- DISM (included with Windows)

---

## Usage

1. Run the script as **Administrator**.
2. Click **Browse**.
3. Select a Windows image:
   - `install.wim`
   - `install.esd`
4. Wait for the image indexes to load.
5. Select the desired Windows edition.
6. Choose an output folder.
7. Click **Export install.wim**.
8. Wait for the export to complete.

The exported file will be created as:

```
install.wim
```

inside the selected output folder.

---

## Supported Source Formats

- `.wim`
- `.esd`

Examples:

```
sources\install.wim
```

```
sources\install.esd
```

---

## Export Command

The tool uses the equivalent DISM command:

```cmd
dism /Export-Image ^
 /SourceImageFile:"install.esd" ^
 /SourceIndex:6 ^
 /DestinationImageFile:"install.wim" ^
 /Compress:Max ^
 /CheckIntegrity
```

---

## Example Workflow

```
Select Source Image
        │
        ▼
Read Image Indexes
        │
        ▼
Choose Windows Edition
        │
        ▼
Select Output Folder
        │
        ▼
Export install.wim
```

---

## Notes

- Only one image index is exported at a time.
- The output file is always named **install.wim**.
- Existing `install.wim` files can be overwritten after confirmation.
- The export time depends on the size of the selected image and the speed of your storage device.

---

## License

This project is provided as-is without warranty. Use at your own risk.
