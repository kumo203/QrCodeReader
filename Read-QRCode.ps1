<#
.SYNOPSIS
    Reads a QR code from an image file or the clipboard and returns the decoded value.

.DESCRIPTION
    This script uses the ZXing.Net library to decode a QR code.
    It can read from an image file specified with the -Path parameter.
    If -Path is not provided, it will attempt to read an image from the clipboard (Windows only).

    If the required ZXing.dll library is not found in the script's directory, it will be
    downloaded automatically from NuGet.

.PARAMETER Path
    The file path to the image containing the QR code. If omitted, the script will try to use the clipboard.

.EXAMPLE
    PS C:\> .\Read-QRCode.ps1 -Path "C:\path\to\your\qrcode.png"

    This command will read the QR code from the specified image and output the decoded string.

.EXAMPLE
    PS C:\> .\Read-QRCode.ps1

    On Windows, this command will attempt to read a QR code from an image in the clipboard.
#>
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Path
)

# Script setup
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ZxingDllPath = Join-Path $ScriptDir "ZXing.dll"

# --- Dependency Management: ZXing.Net ---
if (-not (Test-Path $ZxingDllPath)) {
    Write-Host "ZXing.dll not found. Attempting to download it from NuGet..."

    $packageName = "ZXing.Net"
    $packageVersion = "0.16.9" # A recent, stable version
    $nugetUrl = "https://www.nuget.org/api/v2/package/$packageName/$packageVersion"
    $zipPath = Join-Path $ScriptDir "$packageName.$packageVersion.zip"
    $extractPath = Join-Path $ScriptDir "zxing_temp"

    try {
        # Download the NuGet package (.nupkg is just a .zip)
        Write-Host "Downloading $packageName v$packageVersion..."
        Invoke-WebRequest -Uri $nugetUrl -OutFile $zipPath

        # Extract the package
        Write-Host "Extracting package..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Find the correct DLL for PowerShell (.NET Framework)
        # We target net40 as it's broadly compatible with Windows PowerShell.
        $dllSourcePath = Join-Path $extractPath "lib\net40\ZXing.dll"

        if (Test-Path $dllSourcePath) {
            Write-Host "Copying ZXing.dll to script directory..."
            Copy-Item -Path $dllSourcePath -Destination $ZxingDllPath
        } else {
            throw "Could not find the required 'net40\ZXing.dll' in the extracted package."
        }
        Write-Host "Dependency setup complete."
    }
    catch {
        Write-Error "Failed to download or setup ZXing.Net library. Error: $($_.Exception.Message)"
        # Stop execution if the DLL couldn't be acquired
        return
    }
    finally {
        # Clean up the downloaded .zip and extracted folder
        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
        if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
    }
}

# --- QR Code Decoding Logic ---
function Decode-QRCodeFromBitmap {
    param (
        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$Bitmap
    )

    try {
        # Create a barcode reader instance
        $barcodeReader = New-Object ZXing.BarcodeReader

        # Decode the QR code from the bitmap
        $result = $barcodeReader.Decode($Bitmap)

        # Output the result
        if ($null -ne $result) {
            Write-Output $result.Text
        } else {
            Write-Warning "No QR code could be found or decoded in the image."
        }
    }
    catch {
        Write-Error "An error occurred during QR code decoding: $($_.Exception.Message)"
    }
    finally {
        # Clean up bitmap
        if ($Bitmap) { $Bitmap.Dispose() }
    }
}


# --- Main Script Body ---
try {
    # Load the ZXing.Net assembly
    Add-Type -Path $ZxingDllPath

    if ($PSBoundParameters.ContainsKey('Path')) {
        # --- File-based decoding ---
        $image = [System.Drawing.Image]::FromFile((Resolve-Path $Path))
        $bitmap = New-Object System.Drawing.Bitmap $image
        Decode-QRCodeFromBitmap -Bitmap $bitmap
    }
    else {
        # --- Clipboard-based decoding (Windows Only) ---
        if ($IsWindows) {
            Add-Type -AssemblyName System.Windows.Forms
            if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
                $clipboardImage = [System.Windows.Forms.Clipboard]::GetImage()
                $bitmap = New-Object System.Drawing.Bitmap $clipboardImage
                Decode-QRCodeFromBitmap -Bitmap $bitmap
            } else {
                Write-Warning "No image found on the clipboard."
            }
        } else {
            Write-Error "Clipboard operations are only supported on Windows. Please provide a file using the -Path parameter."
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
finally {
    # Dispose of the original image object if it was created from a file
    if ($image) { $image.Dispose() }
}
