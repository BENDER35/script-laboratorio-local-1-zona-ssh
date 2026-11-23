<#
.SYNOPSIS
  Laboratorio didáctico SSH: conexión y catálogo educativo de vulnerabilidades.
.DESCRIPTION
  Uso exclusivo para aprendizaje en red local y equipos propios/autorizados.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProfileFile = Join-Path $ScriptDir "ssh_profiles.csv"

function Write-Banner {
    Clear-Host
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "   script laboratorio local 1, zona SSH" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-WarningMessage {
    Write-Host "ADVERTENCIA LEGAL/ÉTICA: " -ForegroundColor Yellow -NoNewline
    Write-Host "Solo para aprendizaje en tu red local y equipos propios/autorizados."
    Write-Host "No uses este script para acceder a sistemas ajenos sin permiso."
    Write-Host ""
}

function Pause { Write-Host ""; Read-Host "Presiona Enter para continuar" | Out-Null }

function Test-CommandExists([string]$Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Read-Required([string]$Prompt) {
    while ($true) {
        $v = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
        Write-Host "Este campo es obligatorio." -ForegroundColor Red
    }
}

function Read-Default([string]$Prompt, [string]$Default) {
    $v = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v.Trim()
}

function Test-ValidPort([string]$Port) {
    $n = 0
    if (-not [int]::TryParse($Port, [ref]$n)) { return $false }
    return $n -ge 1 -and $n -le 65535
}
function Test-ValidHost([string]$H) { return $H -match '^[A-Za-z0-9._:-]+$' }
function Test-ValidUser([string]$U) { return $U -match '^[A-Za-z0-9._@\\-]+$' }

function Ensure-ProfileFile {
    if (-not (Test-Path -LiteralPath $ProfileFile)) {
        "name,os,host,user,port,auth,key_path" | Set-Content -LiteralPath $ProfileFile -Encoding UTF8
    }
}

function Get-Profiles {
    Ensure-ProfileFile
    $rows = Import-Csv -LiteralPath $ProfileFile
    return @($rows)
}

function Save-Profile {
    Ensure-ProfileFile
    Write-Banner
    Write-Host "Guardar perfil de laboratorio" -ForegroundColor Cyan
    $name = (Read-Required "Nombre del perfil (sin comas)").Replace(',', ' ')
    $osOpt = Read-Default "Sistema remoto 1) Linux 2) Windows" "1"
    $os = if ($osOpt -eq "2") { "Windows" } else { "Linux" }
    $hostName = Read-Required "IP/hostname"
    $user = Read-Required "Usuario"
    $port = Read-Default "Puerto" "22"
    $authOpt = Read-Default "Autenticación 1) Contraseña 2) Clave" "1"
    $auth = "password"; $keyPath = ""
    if ($authOpt -eq "2") { $auth = "key"; $keyPath = Read-Required "Ruta clave privada" }

    if (-not (Test-ValidHost $hostName) -or -not (Test-ValidUser $user) -or -not (Test-ValidPort $port)) {
        Write-Host "Datos inválidos. Perfil no guardado." -ForegroundColor Red; Pause; return
    }

    $profiles = @(Get-Profiles | Where-Object { $_.name -ne $name })
    $profiles += [pscustomobject]@{ name=$name; os=$os; host=$hostName; user=$user; port=$port; auth=$auth; key_path=$keyPath }
    $profiles | Export-Csv -LiteralPath $ProfileFile -NoTypeInformation -Encoding UTF8
    Write-Host "Perfil guardado." -ForegroundColor Green
    Pause
}

function Show-Profiles {
    $profiles = @(Get-Profiles)
    if ($profiles.Count -eq 0) { Write-Host "  (No hay perfiles guardados)"; return @() }
    $i = 0
    foreach ($p in $profiles) {
        $i++
        Write-Host ("  {0,2}) {1,-20} {2,-7} {3}@{4}:{5} ({6})" -f $i, $p.name, $p.os, $p.user, $p.host, $p.port, $p.auth)
    }
    return $profiles
}

function Connect-SSH([string]$TargetOs, [string]$HostName, [string]$User, [string]$Port, [string]$Auth, [string]$KeyPath) {
    if (-not (Test-ValidHost $HostName) -or -not (Test-ValidUser $User) -or -not (Test-ValidPort $Port)) {
        Write-Host "Datos de conexión inválidos." -ForegroundColor Red; Pause; return
    }
    $sshArgs = @("-p", $Port, "-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=3")
    if ($Auth -eq "key") {
        $kp = [Environment]::ExpandEnvironmentVariables($KeyPath)
        if ($kp.StartsWith("~")) { $kp = Join-Path $HOME $kp.Substring(1).TrimStart('\','/') }
        if (-not (Test-Path -LiteralPath $kp -PathType Leaf)) {
            Write-Host "Clave no encontrada: $kp" -ForegroundColor Red; Pause; return
        }
        $sshArgs += @("-i", $kp)
        $KeyPath = $kp
    }
    $verbose = Read-Host "¿Modo verbose? (s/N)"
    if ($verbose -match '^(s|si)$') { $sshArgs += "-v" }
    $target = "$User@$HostName"
    $sshArgs += $target

    Write-Host ""
    Write-Host "Resumen:" -ForegroundColor Cyan
    Write-Host "  OS=$TargetOs  Destino=$target  Puerto=$Port  Auth=$Auth"
    $display = ($sshArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    Write-Host "Comando: ssh $display" -ForegroundColor Green
    $confirm = Read-Default "¿Conectar? (S/n)" "S"
    if ($confirm -match '^(n|no)$') { Write-Host "Cancelado."; Pause; return }
    Write-Host "Conectando... (exit o Ctrl+D para salir)" -ForegroundColor Green
    & ssh @sshArgs
    if ($LASTEXITCODE -ne 0) { Write-Host "SSH terminó con código $LASTEXITCODE." -ForegroundColor Yellow }
    Pause
}

function Manual-Connect {
    Write-Banner; Write-WarningMessage
    $osOpt = Read-Default "Sistema remoto 1) Linux 2) Windows" "1"
    $os = if ($osOpt -eq "2") { "Windows" } else { "Linux" }
    $hostName = Read-Required "IP o hostname"
    $user = Read-Required "Usuario remoto"
    $port = Read-Default "Puerto SSH" "22"
    $authOpt = Read-Default "Autenticación 1) Contraseña 2) Clave privada" "1"
    $auth = "password"; $keyPath = ""
    if ($authOpt -eq "2") { $auth = "key"; $keyPath = Read-Required "Ruta clave privada" }
    Connect-SSH -TargetOs $os -HostName $hostName -User $user -Port $port -Auth $auth -KeyPath $keyPath
}

function Profile-Menu {
    while ($true) {
        Write-Banner
        Write-Host "Perfiles de hosts (laboratorio)" -ForegroundColor Cyan
        Write-Host "  1) Guardar/actualizar perfil"
        Write-Host "  2) Conectar usando perfil"
        Write-Host "  3) Eliminar perfil"
        Write-Host "  4) Ver perfiles"
        Write-Host "  0) Volver"
        $opt = Read-Host "Opción"
        switch ($opt) {
            "1" { Save-Profile }
            "2" {
                Write-Banner
                $profiles = @(Show-Profiles)
                if ($profiles.Count -eq 0) { Pause; continue }
                $sel = Read-Host "Selecciona perfil (número)"
                $n = 0; if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $profiles.Count) { Write-Host "Selección inválida." -ForegroundColor Red; Pause; continue }
                $p = $profiles[$n-1]
                Connect-SSH -TargetOs $p.os -HostName $p.host -User $p.user -Port $p.port -Auth $p.auth -KeyPath $p.key_path
            }
            "3" {
                Write-Banner
                $profiles = @(Show-Profiles)
                if ($profiles.Count -eq 0) { Pause; continue }
                $sel = Read-Host "Número a eliminar"
                $n = 0; if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $profiles.Count) { Write-Host "Selección inválida." -ForegroundColor Red; Pause; continue }
                $target = $profiles[$n-1].name
                @(Get-Profiles | Where-Object { $_.name -ne $target }) | Export-Csv -LiteralPath $ProfileFile -NoTypeInformation -Encoding UTF8
                Write-Host "Perfil '$target' eliminado." -ForegroundColor Green; Pause
            }
            "4" { Write-Banner; Show-Profiles | Out-Null; Pause }
            "0" { return }
            default { Write-Host "Opción inválida." -ForegroundColor Yellow; Start-Sleep -Milliseconds 800 }
        }
    }
}

# Catálogo educativo curado. No es exhaustivo; verificar NVD/MSRC/OpenSSH advisories.
$Vulns = @(
    [pscustomobject]@{ Id="CVE-2024-6387"; Sev="8.1 Alta"; Affects="OpenSSH sshd 8.5p1-9.7p1 en glibc Linux"; Systems="Linux"; Summary="RegreSSHion: posible RCE no autenticada por race condition en SIGALRM. Explotación difícil."; Mitigation="Actualizar OpenSSH; LoginGraceTime 0 como mitigación temporal (riesgo DoS); limitar acceso por firewall."; Ref="OpenSSH advisory / NVD" }
    [pscustomobject]@{ Id="CVE-2025-26465"; Sev="6.8 Media"; Affects="OpenSSH client 6.8p1-9.9p1 con VerifyHostKeyDNS"; Systems="Linux/Windows/macOS (cliente)"; Summary="MitM posible si VerifyHostKeyDNS está habilitado en escenarios específicos."; Mitigation="Actualizar a 9.9p2+; deshabilitar VerifyHostKeyDNS salvo necesidad."; Ref="OpenSSH 9.9p2 / NVD" }
    [pscustomobject]@{ Id="CVE-2025-26466"; Sev="5.9 Media"; Affects="OpenSSH 9.5p1-9.9p1"; Systems="Linux/Windows/macOS"; Summary="DoS pre-auth por consumo de memoria/CPU durante handshake."; Mitigation="Actualizar OpenSSH; MaxStartups/PerSourceMaxStartups; rate limiting."; Ref="OpenSSH 9.9p2 / NVD" }
    [pscustomobject]@{ Id="CVE-2025-32728"; Sev="4.3 Media"; Affects="OpenSSH sshd hasta 10.x (DisableForwarding no efectivo en algunas rutas)"; Systems="Linux/Unix"; Summary="DisableForwarding no siempre deshabilitaba agent forwarding como se documentaba."; Mitigation="Actualizar OpenSSH; revisar configuración y aplicar parches."; Ref="OpenSSH advisory / NVD" }
    [pscustomobject]@{ Id="CVE-2023-48795"; Sev="5.9 Media"; Affects="Protocolo SSH e implementaciones (OpenSSH, PuTTY, etc.)"; Systems="Linux/Windows/otros"; Summary="Terrapin: MitM puede truncar mensajes iniciales y degradar extensiones/algoritmos."; Mitigation="Actualizar cliente/servidor; usar algoritmos ETM/parches Terrapin."; Ref="terrapin-attack.com / NVD" }
    [pscustomobject]@{ Id="CVE-2023-51385"; Sev="6.5 Media"; Affects="OpenSSH client con expansión en ProxyCommand"; Systems="Linux/Windows/macOS (cliente)"; Summary="Inyección de comando vía hostname malicioso en configuraciones con expansión insegura."; Mitigation="Actualizar; evitar hostnames no confiables en configs con tokens."; Ref="OpenSSH 9.6p1 / NVD" }
    [pscustomobject]@{ Id="CVE-2023-38408"; Sev="9.8 Crítica"; Affects="OpenSSH ssh-agent con agent forwarding"; Systems="Linux/macOS/Windows"; Summary="Posible RCE mediante carga de librería en agent forwarding bajo condiciones específicas."; Mitigation="Actualizar OpenSSH; evitar agent forwarding; preferir ProxyJump."; Ref="NVD / OpenSSH" }
    [pscustomobject]@{ Id="CVE-2021-41617"; Sev="7.0 Alta"; Affects="OpenSSH 6.2-8.7 con AuthorizedKeysCommand/PrincipalsCommand"; Systems="Linux/Unix"; Summary="Inicialización incorrecta de grupos suplementarios puede llevar a escalación."; Mitigation="Actualizar a 8.8p1+; revisar comandos autorizados."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2020-15778"; Sev="7.8 Alta"; Affects="OpenSSH scp"; Systems="Linux/Windows/macOS"; Summary="scp permite inyección de comando vía nombres remotos maliciosos."; Mitigation="Usar sftp/rsync; evitar copiar desde fuentes no confiables."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2019-6111"; Sev="5.9 Media"; Affects="scp (OpenSSH)"; Systems="Linux/Windows/macOS"; Summary="Servidor malicioso puede sobrescribir archivos arbitrarios en cliente scp."; Mitigation="Usar sftp; actualizar OpenSSH."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2018-15473"; Sev="5.3 Media"; Affects="OpenSSH hasta 7.7"; Systems="Linux/Unix"; Summary="Enumeración de usuarios por diferencias de respuesta."; Mitigation="Actualizar; usar claves; rate limiting/fail2ban."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2016-10012"; Sev="7.8 Alta"; Affects="OpenSSH antes de 7.4"; Systems="Linux/Unix"; Summary="Problema en shared memory manager pre-auth puede causar corrupción/DoS."; Mitigation="Actualizar OpenSSH; restringir acceso."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2016-0777"; Sev="4.0 Media"; Affects="OpenSSH client (roaming)"; Systems="Linux/macOS/Windows cliente"; Summary="Fuga de información de clave privada al conectar a servidor malicioso."; Mitigation="Actualizar; deshabilitar roaming en clientes antiguos."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2015-5600"; Sev="8.5 Alta"; Affects="OpenSSH hasta 6.9"; Systems="Linux/Unix"; Summary="Bypass de MaxAuthTries en keyboard-interactive facilita brute force."; Mitigation="Actualizar; usar claves; fail2ban."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2008-0166"; Sev="7.8 Alta"; Affects="OpenSSL en Debian/Ubuntu (claves SSH generadas en periodo afectado)"; Systems="Linux Debian/Ubuntu"; Summary="RNG predecible generó claves débiles; impacto directo en SSH."; Mitigation="Regenerar claves afectadas; auditar authorized_keys."; Ref="Debian DSA-1571" }
    [pscustomobject]@{ Id="CVE-2006-5051"; Sev="9.8 Crítica"; Affects="OpenSSH antes de 4.4"; Systems="Linux/Unix"; Summary="Race condition histórica con potencial RCE no autenticada."; Mitigation="Actualizar; deshabilitar GSSAPI si no se usa."; Ref="NVD" }
    [pscustomobject]@{ Id="CVE-2002-0640"; Sev="10.0 Crítica"; Affects="OpenSSH 3.x antiguas"; Systems="Linux/Unix"; Summary="Vulnerabilidad histórica crítica en versiones antiguas."; Mitigation="No exponer versiones obsoletas; actualizar."; Ref="NVD" }
)

$WinVulns = @(
    [pscustomobject]@{ Id="CVE-2024-38029"; Sev="7.5 Alta"; Affects="Microsoft Windows OpenSSH Server (componentes Windows)"; Systems="Windows"; Summary="Vulnerabilidad en OpenSSH de Windows corregida por Microsoft; riesgo de RCE/impacto según escenario."; Mitigation="Aplicar Windows Update; mantener componente OpenSSH actualizado."; Ref="Microsoft MSRC" }
    [pscustomobject]@{ Id="CVE-2023-48795"; Sev="5.9 Media"; Affects="Implementaciones SSH en Windows (OpenSSH, PuTTY, WinSCP, etc.)"; Systems="Windows"; Summary="Terrapin afecta protocolo SSH; depende de versión y algoritmos."; Mitigation="Actualizar clientes/servidores SSH en Windows; aplicar parches."; Ref="MSRC / terrapin-attack.com" }
    [pscustomobject]@{ Id="CVE-2019-16905"; Sev="7.8 Alta"; Affects="OpenSSH/ports en Windows y otros (según build)"; Systems="Windows"; Summary="Problemas de manejo de memoria/escalación en implementaciones afectadas."; Mitigation="Actualizar OpenSSH; aplicar parches del proveedor."; Ref="NVD" }
)

function Show-VulnDetail($v) {
    Write-Host $v.Id -ForegroundColor Cyan -NoNewline
    Write-Host " [$($v.Sev)]" -ForegroundColor Yellow
    Write-Host "Afecta:      $($v.Affects)"
    Write-Host "Sistemas:    $($v.Systems)"
    Write-Host "Resumen:     $($v.Summary)"
    Write-Host "Mitigación:  $($v.Mitigation)"
    Write-Host "Referencia:  $($v.Ref)"
    Write-Host ""
}

function Hardening-Checklist {
    Write-Banner
    Write-Host "Checklist de hardening SSH (laboratorio)" -ForegroundColor Cyan
    Write-Host @"

[Linux - sshd_config]
  - PasswordAuthentication no (usar claves)
  - PermitRootLogin no
  - PubkeyAuthentication yes
  - MaxAuthTries 3
  - LoginGraceTime 30
  - AllowUsers/AllowGroups
  - X11Forwarding no si no se necesita
  - Actualizar OpenSSH

[Windows - OpenSSH Server]
  - Instalar OpenSSH Server oficial
  - Mantener Windows Update al día
  - Limitar firewall a red local
  - Usar claves; revisar %ProgramData%\ssh\sshd_config
  - Revisar logs de OpenSSH

[Red/operación]
  - Exponer SSH solo en red local
  - fail2ban/rate limiting
  - Rotar claves y auditar authorized_keys
  - Monitorear logs
"@
    Pause
}

function Vuln-Menu {
    while ($true) {
        Write-Banner
        Write-Host "Catálogo educativo de vulnerabilidades SSH/OpenSSH" -ForegroundColor Cyan
        Write-Host "Nota: catálogo curado de CVEs relevantes/históricas, no exhaustivo." -ForegroundColor DarkYellow
        Write-Host "Verifica siempre NVD, OpenSSH advisories y Microsoft MSRC."
        Write-Host ""
        Write-Host "  1) Vulnerabilidades OpenSSH/Linux/multiplataforma"
        Write-Host "  2) Vulnerabilidades relevantes en Windows/OpenSSH"
        Write-Host "  3) Ver todas"
        Write-Host "  4) Buscar por CVE/texto"
        Write-Host "  5) Checklist de hardening"
        Write-Host "  0) Volver"
        $opt = Read-Host "Opción"
        switch ($opt) {
            "1" { Write-Banner; $Vulns | ForEach-Object { Show-VulnDetail $_ }; Pause }
            "2" { Write-Banner; $WinVulns | ForEach-Object { Show-VulnDetail $_ }; Write-Host "Nota: en Windows muchas correcciones llegan por Windows Update." -ForegroundColor Yellow; Pause }
            "3" { Write-Banner; @($Vulns + $WinVulns) | ForEach-Object { Show-VulnDetail $_ }; Pause }
            "4" {
                $q = (Read-Host "Texto/CVE a buscar").ToLowerInvariant()
                Write-Banner
                $all = @($Vulns + $WinVulns)
                $found = @($all | Where-Object { ($_.Id + $_.Affects + $_.Systems + $_.Summary + $_.Mitigation + $_.Ref).ToLowerInvariant().Contains($q) })
                if ($found.Count -eq 0) { Write-Host "No se encontraron coincidencias en el catálogo curado." }
                else { $found | ForEach-Object { Show-VulnDetail $_ } }
                Pause
            }
            "5" { Hardening-Checklist }
            "0" { return }
            default { Write-Host "Opción inválida." -ForegroundColor Yellow; Start-Sleep -Milliseconds 800 }
        }
    }
}

function Main-Menu {
    if (-not (Test-CommandExists "ssh")) {
        Write-Host "Error: No se encontró el cliente 'ssh'." -ForegroundColor Red
        Write-Host "Instala Cliente OpenSSH en Características opcionales de Windows."
        exit 1
    }
    while ($true) {
        Write-Banner
        Write-WarningMessage
        Write-Host "Menú principal" -ForegroundColor Cyan
        Write-Host "  1) Conexión manual por SSH"
        Write-Host "  2) Perfiles de hosts (guardar/usar)"
        Write-Host "  3) Catálogo educativo de vulnerabilidades SSH"
        Write-Host "  4) Checklist de hardening"
        Write-Host "  0) Salir"
        $opt = Read-Host "Selecciona una opción"
        switch ($opt) {
            "1" { Manual-Connect }
            "2" { Profile-Menu }
            "3" { Vuln-Menu }
            "4" { Hardening-Checklist }
            "0" { Write-Host "Saliendo."; exit 0 }
            default { Write-Host "Opción inválida." -ForegroundColor Yellow; Start-Sleep -Milliseconds 800 }
        }
    }
}

Main-Menu
