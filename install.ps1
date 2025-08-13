# PIM-Global-MST Quick Installer
# This script downloads and runs the PIM-Global-MST tool

Write-Host "🔐 PIM-Global-MST Quick Installer" -ForegroundColor Cyan
Write-Host "Downloading and running PIM-Global-MST..." -ForegroundColor Yellow

# Create temporary directory
$tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "PIM-Global-MST-" + [System.Guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Download the main script
    $scriptPath = Join-Path $tempDir "PIM-Global-Teams-v2.ps1"
    Write-Host "📥 Downloading script..." -ForegroundColor Green
    
    # Try multiple download methods
    $downloadSuccess = $false
    $urls = @(
        "https://github.com/markorr321/PIM-Global-MST/raw/main/PIM-Global-Teams-v2.ps1",
        "https://raw.githubusercontent.com/markorr321/PIM-Global-MST/main/PIM-Global-Teams-v2.ps1"
    )
    
    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
            if (Test-Path $scriptPath) {
                $downloadSuccess = $true
                Write-Host "✅ Download successful from: $url" -ForegroundColor Green
                break
            }
        }
        catch {
            Write-Host "❌ Failed to download from: $url" -ForegroundColor Red
        }
    }
    
    if (-not $downloadSuccess) {
        throw "Could not download script from any URL"
    }
    
    # Run the script
    Write-Host "🚀 Launching PIM-Global-MST..." -ForegroundColor Cyan
    & $scriptPath
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Alternative: Clone the repository manually:" -ForegroundColor Yellow
    Write-Host "   git clone https://github.com/markorr321/PIM-Global-MST.git" -ForegroundColor White
    Write-Host "   cd PIM-Global-MST" -ForegroundColor White
    Write-Host "   .\PIM-Global-Teams-v2.ps1" -ForegroundColor White
}
finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}




