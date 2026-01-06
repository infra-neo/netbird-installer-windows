$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    NetBird Windows Installer Script
.DESCRIPTION
    Downloads and installs NetBird Windows client with specified configuration.
    Supports both GUI and headless installation modes.
.PARAMETER Version
    NetBird version to install (default: latest)
.PARAMETER ManagementUrl
    Management server URL
.PARAMETER SetupKey
    Setup key for automatic registration
.PARAMETER InstallPath
    Installation directory path
.PARAMETER Silent
    Run installation in silent mode without GUI
.PARAMETER NoStart
    Skip starting the NetBird service after installation
.PARAMETER LogPath
    Path to installation log file
.EXAMPLE
    .\install.ps1 -Version "0.61.2" -ManagementUrl "https://manager.kappa4.com"
.EXAMPLE
    .\install.ps1 -SetupKey "YOUR-KEY" -Silent
.NOTES
    Requires Administrator privileges
    Compatible with Windows 10/11 and Windows Server 2016+
#>

# PRECONFIGURED FOR KAPPA4 INFRASTRUCTURE
# This installer is preconfigured with default values for kappa4.com deployment.
# All defaults can be overridden using command-line parameters.
# Setup key is intentionally embedded for simplified deployment.

param(
    [Parameter(HelpMessage="NetBird version to install")]
    [string]$Version = "0.61.2",
    
    [Parameter(HelpMessage="Installation directory path")]
    [string]$InstallPath = "$env:ProgramFiles\NetBird",
    
    [Parameter(HelpMessage="Run installation in silent mode")]
    [switch]$Silent,
    
    [Parameter(HelpMessage="Management server URL")]
    [string]$ManagementUrl = "https://manager.kappa4.com",
    
    [Parameter(HelpMessage="Setup key for automatic registration")]
    [string]$SetupKey = "EEBFBA5A-A1BF-43B5-8693-80877AACAEED",
    
    [Parameter(HelpMessage="Skip starting NetBird service after installation")]
    [switch]$NoStart,
    
    [Parameter(HelpMessage="Path to installation log file")]
    [string]$LogPath = "$env:TEMP\netbird-install.log"
)

# Function to write log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to download file
function Get-FileFromUrl {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Log "Downloading from: $Url"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Log "Download completed: $OutputPath"
    }
    catch {
        Write-Log "Download failed: $_" "ERROR"
        throw
    }
}

# Main installation logic
try {
    Write-Log "Starting NetBird installation"
    Write-Log "Version: $Version"
    Write-Log "Install Path: $InstallPath"
    Write-Log "Management URL: $ManagementUrl"
    Write-Log "Silent Mode: $Silent"
    
    # Check for Administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "This script requires Administrator privileges" "ERROR"
        throw "Please run as Administrator"
    }
    
    # Determine download URL based on version
    if ($Version -eq "latest") {
        $downloadUrl = "https://github.com/netbirdio/netbird/releases/latest/download/netbird-installer.exe"
    }
    else {
        $downloadUrl = "https://github.com/netbirdio/netbird/releases/download/v$Version/netbird-installer.exe"
    }
    
    # Create temporary download path
    $installerPath = Join-Path $env:TEMP "netbird-installer-$Version.exe"
    
    # Download installer
    Write-Log "Downloading NetBird installer..."
    Get-FileFromUrl -Url $downloadUrl -OutputPath $installerPath
    
    # Verify download
    if (-not (Test-Path $installerPath)) {
        Write-Log "Installer download verification failed" "ERROR"
        throw "Downloaded installer not found"
    }
    
    # Prepare installation arguments
    $installArgs = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
    $installArgs += "/DIR=`"$InstallPath`""
    $installArgs += "/LOG=`"$LogPath`""
    
    if ($ManagementUrl) {
        $installArgs += "/MANAGEMENT_URL=`"$ManagementUrl`""
    }
    
    if ($SetupKey) {
        $installArgs += "/SETUP_KEY=`"$SetupKey`""
    }
    
    # Execute installer
    Write-Log "Running NetBird installer..."
    Write-Log "Arguments: $($installArgs -join ' ')"
    
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Log "Installation failed with exit code: $($process.ExitCode)" "ERROR"
        throw "Installation failed"
    }
    
    Write-Log "Installation completed successfully"
    
    # Start NetBird service unless NoStart is specified
    if (-not $NoStart) {
        Write-Log "Starting NetBird service..."
        try {
            Start-Service -Name "NetBird" -ErrorAction Stop
            Write-Log "NetBird service started successfully"
        }
        catch {
            Write-Log "Failed to start NetBird service: $_" "WARN"
        }
    }
    
    # Cleanup installer
    Write-Log "Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    
    Write-Log "NetBird installation process completed"
    Write-Log "Installation log available at: $LogPath"
    
    # Display status
    if (-not $Silent) {
        Write-Host "`nNetBird has been successfully installed!" -ForegroundColor Green
        Write-Host "Installation Path: $InstallPath"
        Write-Host "Management URL: $ManagementUrl"
        if ($SetupKey) {
            Write-Host "Setup Key: Configured"
        }
        Write-Host "`nFor more information, visit: https://netbird.io/docs"
    }
}
catch {
    Write-Log "Installation failed: $_" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    
    if (-not $Silent) {
        Write-Host "`nInstallation failed: $_" -ForegroundColor Red
        Write-Host "Check log file for details: $LogPath"
    }
    
    exit 1
}
