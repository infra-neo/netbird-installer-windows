<#
.SYNOPSIS
    Netbird Windows Installer Script

.DESCRIPTION
    This script installs the Netbird client on Windows systems with support for
    automatic configuration and service installation.

.PARAMETER Help
    Show help information

.PARAMETER InstallApp
    Install Netbird binary (default: true)

.PARAMETER InstallUI
    Install Netbird UI binary (default: false)

.PARAMETER Version
    Target version to install (default: latest)

.PARAMETER NoService
    Don't install service (default: false)

.PARAMETER NoPreconfigure
    Don't preconfigure client (default: false)

.PARAMETER BaseUrl
    Base URL for downloads (for air-gapped systems)

.PARAMETER ManagementUrl
    Management URL (default: https://api.wiretrustee.com:33073)

.PARAMETER SetupKey
    Setup key for automatic configuration

.PARAMETER Quiet
    Don't show prompts (default: false)

.EXAMPLE
    .\install.ps1 -SetupKey "YOUR-KEY" -Quiet

.EXAMPLE
    .\install.ps1 -InstallUI -ManagementUrl "https://api.example.com:33073"

.NOTES
    Requires Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Show help information")]
    [switch]$Help,

    [Parameter(HelpMessage="Install Netbird binary")]
    [bool]$InstallApp = $true,

    [Parameter(HelpMessage="Install Netbird UI binary")]
    [bool]$InstallUI = $false,

    [Parameter(HelpMessage="Target version to install (default: latest)")]
    [string]$Version = "latest",

    [Parameter(HelpMessage="Don't install service")]
    [switch]$NoService,

    [Parameter(HelpMessage="Don't preconfigure client")]
    [switch]$NoPreconfigure,

    [Parameter(HelpMessage="Base URL for downloads")]
    [string]$BaseUrl = "",

    [Parameter(HelpMessage="Management URL")]
    [string]$ManagementUrl = "https://api.wiretrustee.com:33073",

    [Parameter(HelpMessage="Setup key for automatic configuration")]
    [string]$SetupKey = "",

    [Parameter(HelpMessage="Don't show prompts")]
    [switch]$Quiet
)

# Constants
$APP_MAIN_NAME = "netbird"
$APP_UI_NAME = "netbird-ui"
$REPO_USER = "netbirdio"
$REPO_MAIN = "netbird"

# Color codes
$ColorGreen = "Green"
$ColorYellow = "Yellow"
$ColorRed = "Red"
$ColorCyan = "Cyan"

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "This script must be run as Administrator" -ForegroundColor $ColorRed
    exit 1
}

# Pretty box functions
function Write-BoxCurrent {
    param([string]$Message)
    Write-Host "[ " -NoNewline
    Write-Host "CURRENT" -ForegroundColor $ColorYellow -NoNewline
    Write-Host "  ] $Message"
}

function Write-BoxComplete {
    param([string]$Message)
    Write-Host "[ " -NoNewline
    Write-Host "COMPLETE" -ForegroundColor $ColorGreen -NoNewline
    Write-Host " ] $Message"
}

function Write-BoxFailed {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Host "[ " -NoNewline
    Write-Host "FAILED" -ForegroundColor $ColorRed -NoNewline
    Write-Host "   ] $Message"
    exit $ExitCode
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host $Message -ForegroundColor $ColorRed
}

# Show help
function Show-Help {
    Write-Host @"
install.ps1 - Install Netbird on Windows

USAGE:
    .\install.ps1 [options]

OPTIONS:
    -Help                   Show this help message
    -InstallApp             Install Netbird Binary (default: true)
    -InstallUI              Install Netbird UI Binary (default: false)
    -Version <version>      Target Install version (defaults to latest)
    -NoService              Don't install service
    -NoPreconfigure         Don't Preconfigure Client
    -BaseUrl <url>          Base URL For downloads (For Air-Gapped Systems)
    -ManagementUrl <url>    Management URL (Defaults to Netbird SaaS)
    -SetupKey <key>         Setup Key
    -Quiet                  Don't present any prompts

EXAMPLES:
    .\install.ps1 -SetupKey "YOUR-KEY" -Quiet
    .\install.ps1 -InstallUI -Version "0.23.0"
    .\install.ps1 -ManagementUrl "https://api.example.com:33073" -SetupKey "KEY"
"@
}

if ($Help) {
    Show-Help
    exit 0
}

# Get latest release version from GitHub
function Get-LatestRelease {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO_USER/$REPO_MAIN/releases/latest" -ErrorAction Stop
        return $response.tag_name -replace '^v', ''
    }
    catch {
        Write-Error-Message "Failed to fetch latest release version: $_"
        exit 1
    }
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        "x86" { return "386" }
        default {
            Write-Error-Message "Architecture $arch not supported"
            exit 2
        }
    }
}

# Determine if Netbird is already installed
function Test-NetbirdInstalled {
    $programFiles = if ([Environment]::Is64BitOperatingSystem) { 
        $env:ProgramFiles 
    } else { 
        ${env:ProgramFiles(x86)} 
    }
    $netbirdPath = Join-Path $programFiles "Netbird\netbird.exe"
    return Test-Path $netbirdPath
}

# Resolve version
if ($Version -eq "latest") {
    $Version = Get-LatestRelease
}

# Set base URL if not provided
if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "https://github.com/$REPO_USER/$REPO_MAIN/releases/download"
}

# Detect system properties
$OS_TYPE = Get-Architecture
$ALREADY_INSTALLED = Test-NetbirdInstalled
$INSTALL_SERVICE = -not $NoService
$PRECONFIGURE = -not $NoPreconfigure

# Show install summary
function Show-InstallSummary {
    Write-Host "------------------------------------------------"
    Write-Host "| Install Summary"
    Write-Host "------------------------------------------------"
    Write-Host "| Target Operating System:       " -NoNewline
    Write-Host "Windows" -ForegroundColor $ColorGreen
    Write-Host "| Target Arch:                   " -NoNewline
    Write-Host $OS_TYPE -ForegroundColor $ColorGreen
    Write-Host "| Target Version:                " -NoNewline
    Write-Host "v$Version" -ForegroundColor $ColorGreen
    Write-Host "| Install Netbird Binary:        " -NoNewline
    Write-Host $(if ($InstallApp) { "Yes" } else { "No" }) -ForegroundColor $(if ($InstallApp) { $ColorGreen } else { $ColorRed })
    Write-Host "| Install UI Binary:             " -NoNewline
    Write-Host $(if ($InstallUI) { "Yes" } else { "No" }) -ForegroundColor $(if ($InstallUI) { $ColorGreen } else { $ColorRed })
    Write-Host "| Install Service:               " -NoNewline
    Write-Host $(if ($INSTALL_SERVICE) { "Yes" } else { "No" }) -ForegroundColor $(if ($INSTALL_SERVICE) { $ColorGreen } else { $ColorRed })
    Write-Host "| Pre-Configure Client:          " -NoNewline
    Write-Host $(if ($PRECONFIGURE) { "Yes" } else { "No" }) -ForegroundColor $(if ($PRECONFIGURE) { $ColorGreen } else { $ColorRed })
    Write-Host "| Base URL:                      " -NoNewline
    Write-Host $BaseUrl -ForegroundColor $ColorGreen
    Write-Host "| Management URL:                " -NoNewline
    Write-Host $ManagementUrl -ForegroundColor $ColorGreen
    Write-Host "| Setup Key:                     " -NoNewline
    if ([string]::IsNullOrEmpty($SetupKey)) {
        Write-Host "(not provided)" -ForegroundColor $ColorGreen
    } else {
        # Mask the setup key for security - show first 4 chars max, then asterisks
        $visibleChars = [Math]::Min(4, $SetupKey.Length)
        if ($SetupKey.Length -le 4) {
            $maskedKey = "****"
        } else {
            $maskedKey = $SetupKey.Substring(0, $visibleChars) + "****"
        }
        Write-Host $maskedKey -ForegroundColor $ColorGreen
    }
    Write-Host "|"
    Write-Host "| Native Binary Installed        " -NoNewline
    Write-Host $(if ($ALREADY_INSTALLED) { "Yes" } else { "No" }) -ForegroundColor $(if ($ALREADY_INSTALLED) { $ColorGreen } else { $ColorRed })
    Write-Host "------------------------------------------------"
}

# Check if user wants to continue
function Test-ContinueInstall {
    if (-not $Quiet) {
        Write-Host ""
        $response = Read-Host "Are you sure you want to continue? [Y/n]"
        if ($response -and $response -notmatch '^[Yy]') {
            Write-Host "Cool, See you soon!"
            exit 0
        }
    }
}

# Download binaries
function Get-Binaries {
    param(
        [string]$TempDir
    )

    $APP_FILENAME = "${APP_MAIN_NAME}_${Version}_windows_${OS_TYPE}"
    $UI_FILENAME = "${APP_UI_NAME}_${Version}_windows_${OS_TYPE}"
    
    $APP_URL = "$BaseUrl/v$Version/$APP_FILENAME.tar.gz"
    $UI_URL = "$BaseUrl/v$Version/$UI_FILENAME.tar.gz"

    if ($InstallApp) {
        Write-BoxCurrent "Downloading $APP_MAIN_NAME"
        $appArchive = Join-Path $TempDir "$APP_FILENAME.tar.gz"
        try {
            Invoke-WebRequest -Uri $APP_URL -OutFile $appArchive -ErrorAction Stop
            Write-BoxComplete "Downloaded $APP_MAIN_NAME"
        }
        catch {
            Write-BoxFailed "Failed to download $APP_MAIN_NAME : $_" 1
        }
    }

    if ($InstallUI) {
        Write-BoxCurrent "Downloading $APP_UI_NAME"
        $uiArchive = Join-Path $TempDir "$UI_FILENAME.tar.gz"
        try {
            Invoke-WebRequest -Uri $UI_URL -OutFile $uiArchive -ErrorAction Stop
            Write-BoxComplete "Downloaded $APP_UI_NAME"
        }
        catch {
            Write-BoxFailed "Failed to download $APP_UI_NAME : $_" 1
        }
    }
}

# Extract binaries
function Expand-Binaries {
    param(
        [string]$TempDir
    )

    $APP_FILENAME = "${APP_MAIN_NAME}_${Version}_windows_${OS_TYPE}"
    $UI_FILENAME = "${APP_UI_NAME}_${Version}_windows_${OS_TYPE}"

    if ($InstallApp) {
        Write-BoxCurrent "Extracting $APP_MAIN_NAME"
        $appArchive = Join-Path $TempDir "$APP_FILENAME.tar.gz"
        try {
            # Use tar command (available in Windows 10 1803+ and Windows Server 2019+)
            $tarOutput = & tar -xzf $appArchive -C $TempDir 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "tar extraction failed: $tarOutput"
            }
            Write-BoxComplete "Extracted $APP_MAIN_NAME"
        }
        catch {
            Write-BoxFailed "Failed to extract $APP_MAIN_NAME : $_" 1
        }
    }

    if ($InstallUI) {
        Write-BoxCurrent "Extracting $APP_UI_NAME"
        $uiArchive = Join-Path $TempDir "$UI_FILENAME.tar.gz"
        try {
            # Use tar command (available in Windows 10 1803+ and Windows Server 2019+)
            $tarOutput = & tar -xzf $uiArchive -C $TempDir 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "tar extraction failed: $tarOutput"
            }
            Write-BoxComplete "Extracted $APP_UI_NAME"
        }
        catch {
            Write-BoxFailed "Failed to extract $APP_UI_NAME : $_" 1
        }
    }
}

# Install binaries to Program Files
function Install-Binaries {
    param(
        [string]$TempDir
    )

    # Determine Program Files directory based on architecture
    $programFiles = if ([Environment]::Is64BitOperatingSystem -and $OS_TYPE -ne "386") { 
        $env:ProgramFiles 
    } else { 
        ${env:ProgramFiles(x86)} 
    }
    
    $installDir = Join-Path $programFiles "Netbird"

    # Create install directory if it doesn't exist
    if (-not (Test-Path $installDir)) {
        Write-BoxCurrent "Creating directory $installDir"
        try {
            New-Item -ItemType Directory -Path $installDir -Force -ErrorAction Stop | Out-Null
            Write-BoxComplete "Directory created successfully"
        }
        catch {
            Write-BoxFailed "Failed to create directory: $_" 1
        }
    }

    if ($InstallApp) {
        Write-BoxCurrent "Copying $APP_MAIN_NAME.exe to $installDir"
        $sourcePath = Join-Path $TempDir "$APP_MAIN_NAME.exe"
        $destPath = Join-Path $installDir "$APP_MAIN_NAME.exe"
        
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
            Write-BoxComplete "Binary copied successfully"
        }
        catch {
            Write-BoxFailed "Failed to copy binary: $_" 1
        }
    }

    if ($InstallUI) {
        Write-BoxCurrent "Copying $APP_UI_NAME.exe to $installDir"
        $sourcePath = Join-Path $TempDir "$APP_UI_NAME.exe"
        $destPath = Join-Path $installDir "$APP_UI_NAME.exe"
        
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
            Write-BoxComplete "UI binary copied successfully"
        }
        catch {
            Write-BoxFailed "Failed to copy UI binary: $_" 1
        }
    }

    # Add to PATH if not already there
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$installDir*") {
        Write-BoxCurrent "Adding $installDir to system PATH"
        try {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", "Machine")
            Write-BoxComplete "Added to system PATH"
        }
        catch {
            Write-BoxFailed "Failed to add to PATH: $_" 1
        }
    }

    return $installDir
}

# Helper function for service commands with error handling
function Invoke-ServiceCommand {
    param(
        [string]$NetbirdExe,
        [string]$Command,
        [string]$CurrentMessage,
        [string]$SuccessMessage,
        [string]$FallbackMessage
    )
    
    Write-BoxCurrent $CurrentMessage
    try {
        & $NetbirdExe service $Command 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-BoxComplete $SuccessMessage
        } else {
            Write-BoxComplete $FallbackMessage
        }
    }
    catch {
        Write-BoxComplete $FallbackMessage
    }
}

# Install Windows service
function Install-Service {
    param(
        [string]$InstallDir
    )

    if (-not $INSTALL_SERVICE) {
        return
    }

    $netbirdExe = Join-Path $InstallDir "$APP_MAIN_NAME.exe"

    if ($ALREADY_INSTALLED) {
        # Stop existing service
        Invoke-ServiceCommand -NetbirdExe $netbirdExe -Command "stop" `
            -CurrentMessage "Stopping existing service" `
            -SuccessMessage "Service stopped successfully" `
            -FallbackMessage "Service stopped (was not running)"

        # Uninstall existing service
        Invoke-ServiceCommand -NetbirdExe $netbirdExe -Command "uninstall" `
            -CurrentMessage "Uninstalling existing service" `
            -SuccessMessage "Service uninstalled successfully" `
            -FallbackMessage "Service uninstalled (was not installed)"
    }

    # Install service
    Write-BoxCurrent "Installing Windows service"
    try {
        & $netbirdExe service install 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-BoxComplete "Service installed successfully"
        }
        else {
            Write-BoxFailed "Failed to install service (exit code: $LASTEXITCODE)" 1
        }
    }
    catch {
        Write-BoxFailed "Failed to install service: $_" 1
    }

    # Start service
    Write-BoxCurrent "Starting Windows service"
    try {
        & $netbirdExe service start 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-BoxComplete "Service started successfully"
        }
        else {
            Write-BoxFailed "Failed to start service (exit code: $LASTEXITCODE)" 1
        }
    }
    catch {
        Write-BoxFailed "Failed to start service: $_" 1
    }
}

# Preconfigure Netbird
function Set-NetbirdConfiguration {
    param(
        [string]$InstallDir
    )

    if (-not $PRECONFIGURE) {
        return
    }

    $netbirdExe = Join-Path $InstallDir "$APP_MAIN_NAME.exe"
    $configArgs = @("up")

    if ($ManagementUrl -ne "https://api.wiretrustee.com:33073") {
        $configArgs += "--management-url"
        $configArgs += $ManagementUrl
    }

    if (-not [string]::IsNullOrEmpty($SetupKey)) {
        $configArgs += "--setup-key"
        $configArgs += $SetupKey
    }

    # Note: The setup key may be visible in process lists during execution.
    # This is a limitation of command-line tools and matches the behavior
    # of the original bash installer.
    Write-BoxCurrent "Configuring Netbird client"
    try {
        # Redirect output to avoid credential exposure in console
        & $netbirdExe $configArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-BoxComplete "Configuration completed successfully"
        }
        else {
            Write-BoxFailed "Configuration failed (exit code: $LASTEXITCODE)" 1
        }
    }
    catch {
        Write-BoxFailed "Failed to configure Netbird: $_" 1
    }
}

# Main installation function
function Install-Netbird {
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "netbird-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Download binaries
        Get-Binaries -TempDir $tempDir

        # Extract binaries
        Expand-Binaries -TempDir $tempDir

        # Install binaries
        $installDir = Install-Binaries -TempDir $tempDir

        # Install service
        Install-Service -InstallDir $installDir

        # Preconfigure
        Set-NetbirdConfiguration -InstallDir $installDir

        Write-Host ""
        Write-Host "Installation completed successfully!" -ForegroundColor $ColorGreen
    }
    finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
Show-InstallSummary
Test-ContinueInstall
Install-Netbird
