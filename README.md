# PIM-Global-MST a portable Executable with Microsoft Teams approval workflow!

A standalone executable for Entra ID Privileged Identity Management (PIM) role activation with enforced MFA.

## Overview

This project creates a single-file executable (`PIM-Global-MST.exe`) that:
- Embeds the PowerShell script and MSAL.NET DLLs as resources
- Extracts everything to a temporary directory at runtime
- Launches PowerShell 7+ with the script
- Brings the console window to the foreground
- Cleans up temporary files when done

## Prerequisites

- **.NET 6 SDK** - Download from [Microsoft](https://dotnet.microsoft.com/download/dotnet/6.0)
- **PowerShell 7+** - The target machine must have PowerShell 7+ installed
- **Working.ps1** - Your PowerShell script (must be in the project root)
- **MSAL DLLs** - Must be in `MSAL\netstandard2.0\` directory:
  - `Microsoft.Identity.Client.dll`
  - `Microsoft.IdentityModel.Abstractions.dll`
- **PIM.ico** - Icon file for the executable (optional)

## Project Structure

```
PIM-Global/
├── Program.cs                 # Main C# launcher code
├── PIMGlobalLauncher.csproj   # Project file
├── PIM-Global-V2.ps1         # Your PowerShell script
├── PIM.ico                   # Application icon
├── MSAL/
│   └── netstandard2.0/
│       ├── Microsoft.Identity.Client.dll
│       └── Microsoft.Identity.Model.Abstractions.dll
├── build.bat                 # Build script
└── README.md                 # This file
```

## Building the Executable

### Build Commands
```cmd
dotnet clean
dotnet restore
dotnet publish -c Release -r win-x64 --self-contained true -o .\out
```

## Output

The build creates a single executable at:
```
.\out\PIM-Global-MST.exe
```

This EXE file:
- Contains all necessary resources embedded
- Is self-contained (includes .NET runtime)
- Can be distributed as a single file
- Requires PowerShell 7+ on the target machine

## How It Works

1. **Extraction**: The EXE extracts `PIM-Global-V2.ps1` and MSAL DLLs to a temporary directory
2. **PowerShell Detection**: Finds `pwsh.exe` in common installation paths or PATH
3. **Launch**: Starts PowerShell 7+ with the script
4. **Foreground**: Brings the console window to the front
5. **Cleanup**: Removes temporary files when PowerShell exits

## Troubleshooting

### PowerShell 7+ Not Found
The launcher checks these locations for `pwsh.exe`:
- `C:\Program Files\PowerShell\7\pwsh.exe`
- `C:\Program Files (x86)\PowerShell\7\pwsh.exe`
- PATH environment variable

### Missing Resources
Ensure these files exist before building:
- `PIM-Global-V2.ps1` in project root
- `MSAL\netstandard2.0\Microsoft.Identity.Client.dll`
- `MSAL\netstandard2.0\Microsoft.Identity.Model.Abstractions.dll`

### Build Errors
- Verify .NET 6 SDK is installed: `dotnet --version`
- Check that all required files are present
- Ensure no files are locked by other processes

## Distribution

The resulting `PIM-Global.exe` is a completely standalone executable that:
- Requires no installation
- Contains all necessary components
- Works on any Windows 10/11 x64 machine with PowerShell 7+
- Cleans up after itself

## Security Notes

- The EXE extracts files to the system temp directory
- Temporary files are automatically cleaned up
- No permanent files are left on the system
- The PowerShell script runs with the same permissions as the user 
