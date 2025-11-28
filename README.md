# QrCodeReader

PowerShell QR-Code Reader module.

## What this module provides

- `Read-QRCode` — reads a QR code from an image file or (on Windows) from the clipboard and returns the decoded text.

## Installation / usage

1. Install by the follwoing command.

```powershell
Install-Module -Name QrCodeReader
```

2. Call the function:

```powershell
# From a file
Read-QRCode -Path 'C:\path\to\qrcode.png'

# From clipboard (Windows only)
Read-QRCode
```
## Notes

- PowerShell Core on non-Windows platforms may need additional steps for image support (System.Drawing.Common) and clipboard access isn't available the same way.
