param(
    [string]$Version = "0.61.2",
    [string]$ManagementUrl = "https://manager.kappa4.com",
    [string]$SetupKey = "EEBFBA5A-A1BF-43B5-8693-80877AACAEED",
    [string]$InstallDir = "$env:ProgramFiles\Netbird",
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# Determine architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }

# Download URLs
$netbirdMsiUrl = "https://github.com/netbirdio/netbird/releases/download/v$Version/netbird_installer_${Version}_windows_${arch}.msi"
$wintunUrl = "https://www.wintun.net/builds/wintun-0.14.1.zip"

# Temp directory for downloads
$tempDir = "$env:TEMP\netbird_install"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    Write-Host "NetBird Installer for Windows" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version: $Version" -ForegroundColor Green
    Write-Host "Architecture: $arch" -ForegroundColor Green
    Write-Host "Management URL: $ManagementUrl" -ForegroundColor Green
    Write-Host "Install Directory: $InstallDir" -ForegroundColor Green
    Write-Host ""

    # Download NetBird MSI installer
    Write-Host "Downloading NetBird MSI installer..." -ForegroundColor Yellow
    $msiPath = "$tempDir\netbird_installer.msi"
    try {
        Invoke-WebRequest -Uri $netbirdMsiUrl -OutFile $msiPath -UseBasicParsing
        Write-Host "NetBird MSI downloaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download NetBird MSI from $netbirdMsiUrl" -ForegroundColor Red
        throw
    }

    # Download WinTun
    Write-Host "Downloading WinTun..." -ForegroundColor Yellow
    $wintunZip = "$tempDir\wintun.zip"
    try {
        Invoke-WebRequest -Uri $wintunUrl -OutFile $wintunZip -UseBasicParsing
        Write-Host "WinTun downloaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download WinTun from $wintunUrl" -ForegroundColor Red
        throw
    }

    # Extract WinTun
    Write-Host "Extracting WinTun..." -ForegroundColor Yellow
    $wintunExtractPath = "$tempDir\wintun"
    Expand-Archive -Path $wintunZip -DestinationPath $wintunExtractPath -Force
    
    # Copy WinTun DLL to system directory
    $wintunDllSource = "$wintunExtractPath\wintun\bin\$arch\wintun.dll"
    $wintunDllDest = "$env:SystemRoot\System32\wintun.dll"
    
    if (Test-Path $wintunDllSource) {
        Copy-Item -Path $wintunDllSource -Destination $wintunDllDest -Force
        Write-Host "WinTun installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "WinTun DLL not found at expected location: $wintunDllSource" -ForegroundColor Red
        throw "WinTun DLL not found"
    }

    # Install NetBird MSI
    Write-Host "Installing NetBird..." -ForegroundColor Yellow
    
    $msiArgs = @(
        "/i"
        "`"$msiPath`""
        "INSTALLDIR=`"$InstallDir`""
        "/qn"  # Quiet mode, no UI
        "/norestart"
        "/L*v"
        "`"$tempDir\netbird_install.log`""
    )
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Host "MSI installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "Check log file at: $tempDir\netbird_install.log" -ForegroundColor Yellow
        throw "MSI installation failed"
    }
    
    Write-Host "NetBird installed successfully." -ForegroundColor Green

    # Configure NetBird
    Write-Host "Configuring NetBird..." -ForegroundColor Yellow
    $netbirdExe = "$InstallDir\netbird.exe"
    
    if (-not (Test-Path $netbirdExe)) {
        Write-Host "NetBird executable not found at: $netbirdExe" -ForegroundColor Red
        throw "NetBird executable not found"
    }

    # Stop service if running
    $service = Get-Service -Name "Netbird" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Host "Stopping NetBird service..." -ForegroundColor Yellow
        Stop-Service -Name "Netbird" -Force
        Start-Sleep -Seconds 2
    }

    # Set management URL
    Write-Host "Setting management URL..." -ForegroundColor Yellow
    & $netbirdExe service stop 2>&1 | Out-Null
    & $netbirdExe down 2>&1 | Out-Null
    
    $configArgs = @(
        "up"
        "--management-url"
        $ManagementUrl
        "--setup-key"
        $SetupKey
    )
    
    if ($Silent) {
        $configArgs += "--log-level", "error"
    }
    
    Write-Host "Connecting to NetBird..." -ForegroundColor Yellow
    $upProcess = Start-Process -FilePath $netbirdExe -ArgumentList $configArgs -Wait -PassThru -NoNewWindow
    
    if ($upProcess.ExitCode -eq 0) {
        Write-Host "NetBird connected successfully." -ForegroundColor Green
    }
    else {
        Write-Host "NetBird connection returned exit code: $($upProcess.ExitCode)" -ForegroundColor Yellow
        Write-Host "This may be normal if already connected. Check service status." -ForegroundColor Yellow
    }

    # Ensure service is running
    Write-Host "Starting NetBird service..." -ForegroundColor Yellow
    $service = Get-Service -Name "Netbird" -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -ne "Running") {
            Start-Service -Name "Netbird"
            Start-Sleep -Seconds 2
        }
        $service = Get-Service -Name "Netbird"
        Write-Host "NetBird service status: $($service.Status)" -ForegroundColor Green
    }
    else {
        Write-Host "NetBird service not found. You may need to configure it manually." -ForegroundColor Yellow
    }

    # Create uninstaller script
    Write-Host "Creating uninstaller script..." -ForegroundColor Yellow
    $uninstallerPath = "$InstallDir\uninstall.ps1"
    $uninstallerContent = @"
# NetBird Uninstaller Script
`$ErrorActionPreference = "Stop"

Write-Host "Uninstalling NetBird..." -ForegroundColor Yellow

# Stop and remove service
try {
    `$service = Get-Service -Name "Netbird" -ErrorAction SilentlyContinue
    if (`$service) {
        Write-Host "Stopping NetBird service..." -ForegroundColor Yellow
        Stop-Service -Name "Netbird" -Force
        
        # Run netbird down to disconnect
        `$netbirdExe = "$InstallDir\netbird.exe"
        if (Test-Path `$netbirdExe) {
            & `$netbirdExe service stop 2>&1 | Out-Null
            & `$netbirdExe down 2>&1 | Out-Null
        }
    }
}
catch {
    Write-Host "Error stopping service: `$_" -ForegroundColor Yellow
}

# Find and uninstall MSI
try {
    Write-Host "Removing NetBird application..." -ForegroundColor Yellow
    `$app = Get-WmiObject -Class Win32_Product | Where-Object { `$_.Name -like "*NetBird*" }
    if (`$app) {
        `$app.Uninstall() | Out-Null
        Write-Host "NetBird application removed." -ForegroundColor Green
    }
    else {
        Write-Host "NetBird application not found in installed programs." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error uninstalling application: `$_" -ForegroundColor Yellow
}

# Remove WinTun
try {
    `$wintunDll = "`$env:SystemRoot\System32\wintun.dll"
    if (Test-Path `$wintunDll) {
        Write-Host "Removing WinTun..." -ForegroundColor Yellow
        Remove-Item -Path `$wintunDll -Force
        Write-Host "WinTun removed." -ForegroundColor Green
    }
}
catch {
    Write-Host "Error removing WinTun: `$_" -ForegroundColor Yellow
}

# Remove installation directory
try {
    if (Test-Path "$InstallDir") {
        Write-Host "Removing installation directory..." -ForegroundColor Yellow
        Remove-Item -Path "$InstallDir" -Recurse -Force
        Write-Host "Installation directory removed." -ForegroundColor Green
    }
}
catch {
    Write-Host "Error removing installation directory: `$_" -ForegroundColor Yellow
    Write-Host "You may need to manually delete: $InstallDir" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "NetBird uninstallation complete." -ForegroundColor Green
"@

    New-Item -ItemType Directory -Force -Path $InstallDir -ErrorAction SilentlyContinue | Out-Null
    Set-Content -Path $uninstallerPath -Value $uninstallerContent -Force
    Write-Host "Uninstaller created at: $uninstallerPath" -ForegroundColor Green

    Write-Host ""
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NetBird has been installed and configured." -ForegroundColor Green
    Write-Host "Installation directory: $InstallDir" -ForegroundColor Cyan
    Write-Host "To uninstall, run: $uninstallerPath" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
finally {
    # Cleanup temp directory
    if (Test-Path $tempDir) {
        try {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "Could not clean up temp directory: $tempDir" -ForegroundColor Yellow
        }
    }
}
