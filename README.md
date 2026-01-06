# Netbird Installer for Windows / Instalador de Netbird para Windows

🇬🇧 **English** | 🇪🇸 **Español**

---

## 🇬🇧 English

This PowerShell script installs the [Netbird](https://netbird.io) Client on Windows systems with the same simplicity and functionality as the Linux/macOS installer.

### Requirements

- Windows 10 (version 1809+), Windows 11, or Windows Server 2019+
- PowerShell 5.1 or higher (included by default in modern Windows)
- Administrator privileges
- Internet connection (unless using `-BaseUrl` for air-gapped systems)

### Quick Start

Download and run the installer with one command:

```powershell
# Basic installation (will prompt for confirmation)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1
.\install.ps1

# Automated installation with setup key
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1
.\install.ps1 -SetupKey "YOUR-SETUP-KEY" -Quiet

# Install with UI and custom management URL
.\install.ps1 -InstallUI -ManagementUrl "https://api.example.com:33073" -SetupKey "YOUR-KEY" -Quiet
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Help` | Switch | - | Show help information |
| `-InstallApp` | Boolean | `true` | Install Netbird binary |
| `-InstallUI` | Boolean | `false` | Install Netbird UI binary |
| `-Version` | String | `latest` | Target version to install (e.g., "0.23.0") |
| `-NoService` | Switch | `false` | Don't install Windows service |
| `-NoPreconfigure` | Switch | `false` | Don't preconfigure Netbird client |
| `-BaseUrl` | String | GitHub releases | Base URL for downloads (for air-gapped systems) |
| `-ManagementUrl` | String | `https://api.wiretrustee.com:33073` | Management server URL |
| `-SetupKey` | String | (empty) | Setup key for automatic enrollment |
| `-Quiet` | Switch | `false` | Skip confirmation prompts |

### Usage Examples

#### Basic Installation
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1

# Run with default settings (will ask for confirmation)
.\install.ps1
```

#### Automated Installation with Setup Key
```powershell
.\install.ps1 -SetupKey "77C9F991-DC68-46FA-B06C-E02FC102697F" -Quiet
```

#### Install with UI
```powershell
.\install.ps1 -InstallUI -SetupKey "YOUR-KEY" -Quiet
```

#### Install Specific Version
```powershell
.\install.ps1 -Version "0.23.0" -SetupKey "YOUR-KEY" -Quiet
```

#### Custom Management Server
```powershell
.\install.ps1 -ManagementUrl "https://netbird.example.com:33073" -SetupKey "YOUR-KEY" -Quiet
```

#### Install Without Service (Portable Mode)
```powershell
.\install.ps1 -NoService -NoPreconfigure
```

#### Air-Gapped Installation
```powershell
.\install.ps1 -BaseUrl "https://internal-mirror.example.com/netbird/releases/download" -Version "0.23.0"
```

#### Using the Batch Launcher
For users who prefer double-click execution:
1. Download both `install.ps1` and `install.bat`
2. Right-click `install.bat` and select "Run as administrator"
3. The batch file will launch PowerShell with appropriate permissions

### Installation Details

The script performs the following actions:

1. **Privilege Check**: Verifies administrator privileges
2. **Architecture Detection**: Automatically detects Windows architecture (amd64, arm64, or 386)
3. **Version Resolution**: Fetches latest version from GitHub if not specified
4. **Download**: Downloads Netbird binaries from GitHub releases
5. **Extraction**: Extracts ZIP archives to temporary directory
6. **Installation**: Copies binaries to:
   - `C:\Program Files\Netbird\` (64-bit systems)
   - `C:\Program Files (x86)\Netbird\` (32-bit systems)
7. **PATH Update**: Adds installation directory to system PATH
8. **Service Installation**: Installs and starts Windows service (unless `-NoService` is used)
9. **Configuration**: Runs `netbird up` with provided management URL and setup key (unless `-NoPreconfigure` is used)
10. **Cleanup**: Removes temporary files

### Manual Installation

If you prefer to install manually:

1. Download the latest Netbird release for Windows from:
   ```
   https://github.com/netbirdio/netbird/releases
   ```

2. Extract the ZIP file

3. Copy `netbird.exe` to `C:\Program Files\Netbird\`

4. Add `C:\Program Files\Netbird\` to your system PATH:
   ```powershell
   $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
   [Environment]::SetEnvironmentVariable("Path", "$path;C:\Program Files\Netbird", "Machine")
   ```

5. Install the Windows service:
   ```powershell
   cd "C:\Program Files\Netbird"
   .\netbird.exe service install
   .\netbird.exe service start
   ```

6. Configure Netbird (optional):
   ```powershell
   .\netbird.exe up --management-url https://api.wiretrustee.com:33073 --setup-key YOUR-KEY
   ```

### Troubleshooting

#### "Execution Policy" Error
If you see an error about execution policy, run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run the script with bypass:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

#### "Access Denied" Error
Make sure you're running PowerShell or Command Prompt as Administrator:
- Right-click on PowerShell/CMD
- Select "Run as administrator"

#### Service Installation Failed
If service installation fails:
1. Check if a service is already installed:
   ```powershell
   Get-Service -Name "Netbird" -ErrorAction SilentlyContinue
   ```

2. Manually uninstall the existing service:
   ```powershell
   & "C:\Program Files\Netbird\netbird.exe" service uninstall
   ```

3. Run the installer again

#### Download Failed
If download fails:
- Check your internet connection
- Verify the version exists: https://github.com/netbirdio/netbird/releases
- Try specifying a different version with `-Version`

#### Cannot Find netbird.exe After Install
Make sure to:
1. Close and reopen your PowerShell/CMD window (to refresh PATH)
2. Or use the full path: `C:\Program Files\Netbird\netbird.exe`

### Uninstallation

To uninstall Netbird:

```powershell
# Stop and uninstall service
& "C:\Program Files\Netbird\netbird.exe" service stop
& "C:\Program Files\Netbird\netbird.exe" service uninstall

# Remove installation directory
Remove-Item -Path "C:\Program Files\Netbird" -Recurse -Force

# Remove from PATH (manual step required)
# Open System Properties > Environment Variables > Path and remove the Netbird directory
```

---

## 🇪🇸 Español

Este script de PowerShell instala el Cliente [Netbird](https://netbird.io) en sistemas Windows con la misma simplicidad y funcionalidad que el instalador de Linux/macOS.

### Requisitos

- Windows 10 (versión 1809+), Windows 11 o Windows Server 2019+
- PowerShell 5.1 o superior (incluido por defecto en Windows moderno)
- Privilegios de administrador
- Conexión a Internet (a menos que use `-BaseUrl` para sistemas aislados)

### Inicio Rápido

Descargue y ejecute el instalador con un comando:

```powershell
# Instalación básica (pedirá confirmación)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1
.\install.ps1

# Instalación automatizada con clave de configuración
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1
.\install.ps1 -SetupKey "SU-CLAVE-DE-CONFIGURACION" -Quiet

# Instalar con UI y URL de gestión personalizada
.\install.ps1 -InstallUI -ManagementUrl "https://api.ejemplo.com:33073" -SetupKey "SU-CLAVE" -Quiet
```

### Parámetros

| Parámetro | Tipo | Predeterminado | Descripción |
|-----------|------|----------------|-------------|
| `-Help` | Switch | - | Mostrar información de ayuda |
| `-InstallApp` | Boolean | `true` | Instalar binario de Netbird |
| `-InstallUI` | Boolean | `false` | Instalar binario de UI de Netbird |
| `-Version` | String | `latest` | Versión objetivo a instalar (ej., "0.23.0") |
| `-NoService` | Switch | `false` | No instalar servicio de Windows |
| `-NoPreconfigure` | Switch | `false` | No preconfigurar el cliente Netbird |
| `-BaseUrl` | String | Lanzamientos GitHub | URL base para descargas (para sistemas aislados) |
| `-ManagementUrl` | String | `https://api.wiretrustee.com:33073` | URL del servidor de gestión |
| `-SetupKey` | String | (vacío) | Clave de configuración para inscripción automática |
| `-Quiet` | Switch | `false` | Omitir solicitudes de confirmación |

### Ejemplos de Uso

#### Instalación Básica
```powershell
# Descargar el script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/infra-neo/netbird-installer-windows/main/install.ps1" -OutFile install.ps1

# Ejecutar con configuración predeterminada (pedirá confirmación)
.\install.ps1
```

#### Instalación Automatizada con Clave de Configuración
```powershell
.\install.ps1 -SetupKey "77C9F991-DC68-46FA-B06C-E02FC102697F" -Quiet
```

#### Instalar con UI
```powershell
.\install.ps1 -InstallUI -SetupKey "SU-CLAVE" -Quiet
```

#### Instalar Versión Específica
```powershell
.\install.ps1 -Version "0.23.0" -SetupKey "SU-CLAVE" -Quiet
```

#### Servidor de Gestión Personalizado
```powershell
.\install.ps1 -ManagementUrl "https://netbird.ejemplo.com:33073" -SetupKey "SU-CLAVE" -Quiet
```

#### Instalar Sin Servicio (Modo Portátil)
```powershell
.\install.ps1 -NoService -NoPreconfigure
```

#### Instalación en Sistema Aislado
```powershell
.\install.ps1 -BaseUrl "https://espejo-interno.ejemplo.com/netbird/releases/download" -Version "0.23.0"
```

### Solución de Problemas

#### Error de "Política de Ejecución"
Si ve un error sobre la política de ejecución, ejecute PowerShell como Administrador y ejecute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

O ejecute el script con bypass:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

#### Error de "Acceso Denegado"
Asegúrese de ejecutar PowerShell o el Símbolo del sistema como Administrador:
- Haga clic derecho en PowerShell/CMD
- Seleccione "Ejecutar como administrador"

#### Falló la Instalación del Servicio
Si falla la instalación del servicio:
1. Verifique si ya hay un servicio instalado:
   ```powershell
   Get-Service -Name "Netbird" -ErrorAction SilentlyContinue
   ```

2. Desinstale manualmente el servicio existente:
   ```powershell
   & "C:\Program Files\Netbird\netbird.exe" service uninstall
   ```

3. Ejecute el instalador nuevamente

### Desinstalación

Para desinstalar Netbird:

```powershell
# Detener y desinstalar el servicio
& "C:\Program Files\Netbird\netbird.exe" service stop
& "C:\Program Files\Netbird\netbird.exe" service uninstall

# Eliminar el directorio de instalación
Remove-Item -Path "C:\Program Files\Netbird" -Recurse -Force

# Eliminar del PATH (requiere paso manual)
# Abra Propiedades del Sistema > Variables de Entorno > Path y elimine el directorio de Netbird
```

---

## License / Licencia

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

Este proyecto está licenciado bajo la Licencia BSD 3-Clause - vea el archivo [LICENSE](LICENSE) para más detalles.

---

## Credits / Créditos

Based on the original [physk/netbird-installer](https://github.com/physk/netbird-installer) for Linux/macOS.

Basado en el [physk/netbird-installer](https://github.com/physk/netbird-installer) original para Linux/macOS.

## Contributing / Contribuir

Contributions are welcome! Please feel free to submit a Pull Request.

¡Las contribuciones son bienvenidas! No dude en enviar un Pull Request.

## Support / Soporte

For issues related to this installer, please open an issue on GitHub:
https://github.com/infra-neo/netbird-installer-windows/issues

For Netbird-specific issues, please visit:
https://github.com/netbirdio/netbird/issues

---

Para problemas relacionados con este instalador, abra un issue en GitHub:
https://github.com/infra-neo/netbird-installer-windows/issues

Para problemas específicos de Netbird, visite:
https://github.com/netbirdio/netbird/issues
