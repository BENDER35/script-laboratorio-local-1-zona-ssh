# script laboratorio local 1, zona SSH

Conexión y Catálogo de Vulnerabilidades. Herramienta didáctica para practicar SSH en **red local** con equipos propios o autorizados, con menú de perfiles y catálogo educativo de vulnerabilidades.

> **Uso ético y legal**: solo para sistemas propios o con autorización explícita. El acceso no autorizado es ilegal.

## Archivos

- `ssh_connect.sh`: versión Bash (Linux/macOS/WSL).
- `ssh_connect.ps1`: versión PowerShell (Windows).
- `ssh_profiles.csv`: se crea automáticamente al guardar perfiles.

## Funciones

- **Conexión manual SSH**: host/IP, usuario, puerto, contraseña o clave privada, modo verbose, confirmación antes de conectar.
- **Perfiles de hosts**: guardar, listar, usar y eliminar perfiles de laboratorio.
- **Catálogo educativo de vulnerabilidades SSH**: CVEs curadas relevantes/históricas para OpenSSH/Linux/multiplataforma y Windows, con resumen, mitigación y referencia.
- **Checklist de hardening**: recomendaciones básicas para Linux y Windows.

## Uso

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

## Requisitos

- Cliente: `ssh` (openssh-client / OpenSSH Client de Windows).
- Servidor remoto: OpenSSH Server activo en Linux o Windows, y acceso de red permitido en el firewall de tu laboratorio.

## Nota importante sobre el catálogo

El catálogo de vulnerabilidades es **curado y educativo**, no exhaustivo. Incluye CVEs conocidas y relevantes (antiguas y recientes) para aprender mitigación. Para cobertura completa y actualizada, verifica:

- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [OpenSSH Security / Release Notes](https://www.openssh.com/releasenotes.html)
- [Microsoft Security Response Center](https://msrc.microsoft.com/)

## Buenas prácticas

- Usa claves SSH y contraseñas fuertes.
- Limita SSH a la red local.
- Aplica actualizaciones del sistema y de OpenSSH.
- Revisa logs y usa rate limiting/fail2ban donde corresponda.
