# Guía didáctica: script laboratorio local 1, zona SSH

Esta guía acompaña a `ssh_connect.sh` y `ssh_connect.ps1`. Su objetivo es ayudarte a aprender **SSH**, administración básica y conceptos de **ciberseguridad defensiva** en un entorno controlado.

> **Regla de oro**: practica solo en tu red local, en máquinas virtuales, equipos propios o sistemas para los que tengas autorización explícita por escrito.

## 1. Objetivos de aprendizaje

Al terminar, deberías poder:

- Entender qué es SSH y para qué se usa.
- Configurar un cliente y un servidor SSH en Linux y Windows.
- Conectarte de forma segura usando contraseña o claves.
- Guardar perfiles de laboratorio para agilizar pruebas.
- Interpretar un catálogo de vulnerabilidades y relacionarlo con mitigaciones.
- Aplicar medidas básicas de hardening.

## 2. Conceptos básicos

### ¿Qué es SSH?

SSH (Secure Shell) es un protocolo para acceder y administrar equipos de forma remota mediante un canal cifrado. Normalmente usa el puerto TCP `22`.

### Componentes

- **Cliente SSH**: el equipo desde el que te conectas (`ssh`).
- **Servidor SSH**: el equipo que acepta conexiones (`sshd` en Linux/OpenSSH Server en Windows).
- **Autenticación**: cómo demuestras quién eres (contraseña o clave pública/privada).
- **Cifrado**: protege la confidencialidad e integridad de la sesión.

### Autenticación por contraseña vs. claves

| Método | Ventaja | Riesgo/Limitación | Recomendación |
|---|---|---|---|
| Contraseña | Fácil de empezar | Vulnerable a brute force si es débil | Solo en laboratorio inicial; usar contraseñas fuertes |
| Clave SSH | Más segura y automatizable | Requiere gestionar archivos de clave | Preferida para práctica y uso real |

## 3. Preparación del laboratorio

### Topología sugerida

Usa una red local aislada o NAT de laboratorio:

```text
[Tu PC - Cliente SSH]
        |
   Red local / NAT
      /       \
[VM Linux]   [VM Windows]
 sshd         OpenSSH Server
```

### Requisitos mínimos

- 2 máquinas: 1 cliente y 1 servidor (pueden ser VMs).
- Conectividad IP entre ellas (`ping` o prueba TCP al puerto 22).
- Usuarios locales de prueba en el servidor.
- Cliente OpenSSH instalado en el cliente.

### Instalación del servidor

#### Linux (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

#### Windows 10/11 (PowerShell como Administrador)

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Get-Service sshd
```

Si el firewall bloquea conexiones, permite SSH en la red de laboratorio:

```powershell
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

## 4. Uso del script

### Linux / macOS / WSL

```bash
chmod +x ssh_connect.sh
./ssh_connect.sh
```

### Windows (PowerShell)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ssh_connect.ps1
```

## 5. Recorrido por el menú

### Opción 1: Conexión manual por SSH

Úsala para aprender el flujo básico.

**Datos que pide:**
- **Sistema remoto**: informativo (Linux/Windows).
- **Host/IP**: dirección del servidor, ej. `192.168.1.50`.
- **Usuario**: cuenta existente en el servidor.
- **Puerto**: por defecto `22`.
- **Autenticación**: contraseña o clave privada.
- **Verbose**: muestra detalles de depuración (`-v`).

**Qué observar:**
- El comando SSH generado antes de ejecutar.
- La huella/confirmación del host la primera vez.
- Los mensajes de error si hay usuario, puerto o red incorrectos.

### Opción 2: Perfiles de hosts

Sirve para no repetir datos en prácticas frecuentes.

**Ejercicio:**
1. Guarda un perfil llamado `lab-linux`.
2. Conéctate usando el perfil.
3. Cambia el puerto o usuario y guarda el perfil con el mismo nombre para actualizarlo.
4. Elimina el perfil al finalizar.

El archivo `ssh_profiles.csv` guarda los perfiles localmente. No guardes contraseñas en perfiles; SSH las solicita en tiempo de conexión.

### Opción 3: Catálogo educativo de vulnerabilidades SSH

Este menú es para **aprender defensa**, no para explotar sistemas.

**Cómo usarlo:**
- Revisa por grupo: OpenSSH/multiplataforma o Windows.
- Busca por CVE, por ejemplo `CVE-2024-6387` o `Terrapin`.
- Lee cada entrada con este enfoque:
  - **Qué afecta**: versión/componente/configuración.
  - **Riesgo**: RCE, DoS, MitM, enumeración, etc.
  - **Mitigación**: actualización, configuración, control de red.

**Importante:** el catálogo es curado y educativo, no exhaustivo. Verifica siempre fuentes oficiales: NVD, OpenSSH advisories/release notes y Microsoft MSRC.

### Opción 4: Checklist de hardening

Úsala después de lograr una conexión funcional. Primero haz que funcione; luego endurece la configuración.

## 6. Ejercicios prácticos

### Ejercicio 1 - Primera conexión

1. Crea un usuario de prueba en la VM servidor.
2. Conéctate con el script usando contraseña.
3. Ejecuta comandos básicos: `whoami`, `hostname`, `ip a` (Linux) o `whoami`, `hostname`, `ipconfig` (Windows).
4. Cierra con `exit`.

**Resultado esperado:** sesión interactiva remota funcional.

### Ejercicio 2 - Claves SSH

En el cliente Linux:

```bash
ssh-keygen -t ed25519 -C "lab-ssh"
ssh-copy-id -p 22 usuario@IP_SERVIDOR
```

En Windows, puedes generar clave con:

```powershell
ssh-keygen -t ed25519 -C "lab-ssh"
```

Luego instala la clave pública en el servidor según la configuración de OpenSSH. Repite la conexión usando la opción de clave privada.

**Resultado esperado:** acceso sin contraseña, usando clave.

### Ejercicio 3 - Depuración

Activa el modo verbose en el script o prueba:

```bash
ssh -v usuario@IP_SERVIDOR
```

**Observa:** negociación de algoritmos, autenticación, y errores de red/clave.

### Ejercicio 4 - Análisis de vulnerabilidad

Elige una CVE del catálogo, por ejemplo `CVE-2023-48795` (Terrapin).

1. Identifica qué componente afecta.
2. Determina si el riesgo es MitM, DoS o RCE.
3. Escribe una mitigación concreta para tu laboratorio.
4. Comprueba la versión de OpenSSH instalada:

```bash
ssh -V
sshd -V 2>&1 | head -n 1
```

En Windows:

```powershell
ssh -V
Get-Command sshd
```

**Resultado esperado:** puedes relacionar versión/configuración con riesgo y mitigación.

### Ejercicio 5 - Hardening básico

En Linux, edita `/etc/ssh/sshd_config` con cuidado:

```text
PermitRootLogin no
PasswordAuthentication no  # solo después de probar claves
MaxAuthTries 3
```

Luego valida y reinicia:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

**Precaución:** mantén una sesión abierta mientras pruebas cambios para no bloquearte.

## 7. Buenas prácticas de seguridad

- **Principio de mínimo privilegio**: usa cuentas normales, no root/admin para todo.
- **Claves antes que contraseñas**: deshabilita contraseñas solo cuando las claves funcionen.
- **Actualizaciones**: muchas CVEs se mitigan actualizando OpenSSH/SO.
- **Exposición mínima**: no abras SSH a Internet en el laboratorio.
- **Firewall**: permite solo IPs/redes necesarias.
- **Registro y auditoría**: revisa logs de autenticación.
- **Backups de configuración**: antes de editar `sshd_config`.

## 8. Problemas comunes

| Problema | Causa probable | Comprobación |
|---|---|---|
| `Connection refused` | sshd apagado o puerto incorrecto | `systemctl status ssh`, `Get-Service sshd`, puerto/firewall |
| `Permission denied` | usuario/clave/contraseña incorrecta | usuario existe, permisos de `~/.ssh`, clave correcta |
| `Connection timed out` | red/firewall/ruta | IP correcta, ping, regla de firewall, misma red |
| Host key warning | cambió el servidor o IP reusada | verificar identidad del host antes de aceptar |
| Script no ejecuta en Windows | política de ejecución | usar `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |

## 9. Ética y alcance

Este proyecto tiene fines educativos. El catálogo de vulnerabilidades debe usarse para:

- entender riesgos;
- parchear y configurar correctamente;
- detectar exposiciones en sistemas propios;
- desarrollar criterio defensivo.

No debe usarse para explotar, escanear sin permiso, o acceder a sistemas ajenos.

## 10. Próximos pasos sugeridos

- Aprender `scp`, `sftp` y `rsync` sobre SSH.
- Configurar `~/.ssh/config` con alias de hosts.
- Probar Fail2Ban en Linux.
- Revisar logs: `journalctl -u ssh` o Event Viewer/OpenSSH logs.
- Comparar versiones de OpenSSH y leer release notes cuando aparezca una CVE nueva.
