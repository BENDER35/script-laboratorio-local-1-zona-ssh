#!/usr/bin/env bash

# script laboratorio local 1, zona SSH (ssh_connect.sh)
# Laboratorio didáctico SSH: conexión a equipos propios/autorizados + catálogo educativo de vulnerabilidades.
# NO usar para acceso no autorizado.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/ssh_profiles.csv"

banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}${BOLD}"
  echo "=============================================================="
  echo "   script laboratorio local 1, zona SSH"
  echo "=============================================================="
  echo -e "${NC}"
}

warning() {
  echo -e "${YELLOW}${BOLD}ADVERTENCIA LEGAL/ÉTICA:${NC}"
  echo "Este script es solo para aprendizaje en tu red local y equipos propios"
  echo "o con autorización explícita. No lo uses para acceder a sistemas ajenos."
  echo
}

pause() {
  echo
  read -r -p "Presiona Enter para continuar..." _
}

check_dependencies() {
  if ! command -v ssh >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} No se encontró el cliente 'ssh'."
    echo "Instala openssh-client según tu sistema."
    exit 1
  fi
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value
  read -r -p "$prompt [$default]: " value
  echo "${value:-$default}"
}

prompt_required() {
  local prompt="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$prompt: " value
    if [[ -z "$value" ]]; then
      echo -e "${RED}Este campo es obligatorio.${NC}"
    fi
  done
  echo "$value"
}

is_valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
is_valid_host() { [[ "$1" =~ ^[A-Za-z0-9._:-]+$ ]]; }
is_valid_user() { [[ "$1" =~ ^[A-Za-z0-9._@\\-]+$ ]]; }

ensure_profile_file() {
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "name,os,host,user,port,auth,key_path" > "$PROFILE_FILE"
  fi
}

save_profile() {
  ensure_profile_file
  local name os host user port auth key_path
  echo -e "${BOLD}Guardar perfil de laboratorio${NC}"
  name="$(prompt_required "Nombre del perfil (sin comas)")"
  name="${name//,/ }"
  echo "Sistema remoto: 1) Linux  2) Windows"
  os="$(prompt_default "Opción" "1")"
  [[ "$os" == "2" ]] && os="Windows" || os="Linux"
  host="$(prompt_required "IP/hostname")"
  user="$(prompt_required "Usuario")"
  port="$(prompt_default "Puerto" "22")"
  echo "Autenticación: 1) Contraseña 2) Clave"
  auth="$(prompt_default "Opción" "1")"
  key_path=""
  if [[ "$auth" == "2" ]]; then
    auth="key"
    key_path="$(prompt_required "Ruta clave privada")"
  else
    auth="password"
  fi

  if ! is_valid_host "$host" || ! is_valid_user "$user" || ! is_valid_port "$port"; then
    echo -e "${RED}Datos inválidos. Perfil no guardado.${NC}"
    pause; return
  fi

  # Reemplazar perfil existente con mismo nombre
  local tmp
  tmp="$(mktemp)"
  awk -F, -v n="$name" 'NR==1 || $1!=n' "$PROFILE_FILE" > "$tmp"
  mv "$tmp" "$PROFILE_FILE"
  printf '%s,%s,%s,%s,%s,%s,%s\n' "$name" "$os" "$host" "$user" "$port" "$auth" "$key_path" >> "$PROFILE_FILE"
  echo -e "${GREEN}Perfil guardado en $PROFILE_FILE${NC}"
  pause
}

list_profiles() {
  ensure_profile_file
  echo -e "${BOLD}Perfiles guardados:${NC}"
  local i=0
  while IFS=, read -r name os host user port auth key_path; do
    [[ "$name" == "name" ]] && continue
    i=$((i+1))
    printf "  %2d) %-20s %-7s %s@%s:%s (%s)\n" "$i" "$name" "$os" "$user" "$host" "$port" "$auth"
  done < "$PROFILE_FILE"
  if [[ $i -eq 0 ]]; then
    echo "  (No hay perfiles guardados)"
  fi
  echo "$i"
}

load_profile_and_connect() {
  ensure_profile_file
  local count
  count="$(list_profiles | tail -n1)"
  # Reprint list without count line
  list_profiles >/dev/null
  echo -e "${BOLD}Perfiles guardados:${NC}"
  local i=0
  local lines=()
  while IFS=, read -r name os host user port auth key_path; do
    [[ "$name" == "name" ]] && continue
    i=$((i+1))
    lines+=("$name,$os,$host,$user,$port,$auth,$key_path")
    printf "  %2d) %-20s %-7s %s@%s:%s (%s)\n" "$i" "$name" "$os" "$user" "$host" "$port" "$auth"
  done < "$PROFILE_FILE"
  if [[ $i -eq 0 ]]; then echo "  (No hay perfiles)"; pause; return; fi
  local sel
  read -r -p "Selecciona perfil (número): " sel
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "$i" ]; then
    echo -e "${RED}Selección inválida.${NC}"; pause; return
  fi
  IFS=, read -r name os host user port auth key_path <<< "${lines[$((sel-1))]}"
  connect_ssh "$os" "$host" "$user" "$port" "$auth" "$key_path"
}

delete_profile() {
  ensure_profile_file
  local i=0 names=()
  echo -e "${BOLD}Eliminar perfil${NC}"
  while IFS=, read -r name os host user port auth key_path; do
    [[ "$name" == "name" ]] && continue
    i=$((i+1)); names+=("$name")
    printf "  %2d) %s\n" "$i" "$name"
  done < "$PROFILE_FILE"
  [[ $i -eq 0 ]] && { echo "No hay perfiles."; pause; return; }
  local sel; read -r -p "Número a eliminar: " sel
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "$i" ]; then
    echo -e "${RED}Selección inválida.${NC}"; pause; return
  fi
  local target="${names[$((sel-1))]}"
  local tmp; tmp="$(mktemp)"
  awk -F, -v n="$target" 'NR==1 || $1!=n' "$PROFILE_FILE" > "$tmp"
  mv "$tmp" "$PROFILE_FILE"
  echo -e "${GREEN}Perfil '$target' eliminado.${NC}"
  pause
}

connect_ssh() {
  local target_os="$1" host="$2" user="$3" port="$4" auth="$5" key_path="${6:-}"
  if ! is_valid_host "$host" || ! is_valid_user "$user" || ! is_valid_port "$port"; then
    echo -e "${RED}Datos de conexión inválidos.${NC}"; pause; return
  fi
  local cmd=(ssh -p "$port" -o ServerAliveInterval=30 -o ServerAliveCountMax=3)
  if [[ "$auth" == "key" ]]; then
    key_path="${key_path/#\~/$HOME}"
    if [[ ! -f "$key_path" ]]; then
      echo -e "${RED}Clave no encontrada: $key_path${NC}"; pause; return
    fi
    cmd+=(-i "$key_path")
  fi
  local verbose; read -r -p "¿Modo verbose? (s/N): " verbose
  [[ "${verbose,,}" == "s" || "${verbose,,}" == "si" ]] && cmd+=(-v)
  local target="${user}@${host}"
  echo
  echo -e "${CYAN}Resumen:${NC} OS=$target_os Destino=$target Puerto=$port Auth=$auth"
  echo -e "${GREEN}Comando:${NC}"; printf '  '; printf '%q ' "${cmd[@]}" "$target"; echo; echo
  local confirm; read -r -p "¿Conectar? (S/n): " confirm; confirm="${confirm:-S}"
  [[ "${confirm,,}" == "n" || "${confirm,,}" == "no" ]] && { echo "Cancelado."; pause; return; }
  echo -e "${GREEN}Conectando... (exit o Ctrl+D para salir)${NC}"
  "${cmd[@]}" "$target" || echo -e "${YELLOW}SSH terminó con código $?.${NC}"
  pause
}

manual_connect() {
  echo -e "${BOLD}Conexión manual${NC}"
  echo "Sistema remoto: 1) Linux  2) Windows"
  local os_opt; os_opt="$(prompt_default "Opción" "1")"
  local target_os="Linux"; [[ "$os_opt" == "2" ]] && target_os="Windows"
  local host user port auth_opt auth key_path=""
  host="$(prompt_required "IP o hostname")"
  user="$(prompt_required "Usuario remoto")"
  port="$(prompt_default "Puerto SSH" "22")"
  echo "Autenticación: 1) Contraseña 2) Clave privada"
  auth_opt="$(prompt_default "Opción" "1")"
  if [[ "$auth_opt" == "2" ]]; then auth="key"; key_path="$(prompt_required "Ruta clave privada")"; else auth="password"; fi
  connect_ssh "$target_os" "$host" "$user" "$port" "$auth" "$key_path"
}

# --- Catálogo educativo de vulnerabilidades ---
# Nota: lista curada de vulnerabilidades conocidas y relevantes. No es exhaustiva ni sustituto de advisories oficiales.
# Campos: ID|CVSS/Sev|Afecta|Sistemas|Resumen|Mitigación|Referencia

VULNS=(
  "CVE-2024-6387|8.1 Alta|OpenSSH server (sshd) 8.5p1-9.7p1 en glibc-based Linux; race condition en signal handler|Linux|RegreSSHion: posible RCE no autenticada en condiciones específicas por race condition en SIGALRM. Explotación difícil pero crítica.|Actualizar OpenSSH; LoginGraceTime 0 como mitigación temporal (riesgo DoS); limitar acceso por firewall/red.|OpenSSH advisory / NVD"
  "CVE-2025-26465|6.8 Media|OpenSSH client 6.8p1-9.9p1 con VerifyHostKeyDNS habilitado|Linux/Windows/macOS (cliente)|Ataque MitM: si VerifyHostKeyDNS está activo, un atacante puede suplantar servidor en ciertos escenarios.|Actualizar OpenSSH; deshabilitar VerifyHostKeyDNS salvo necesidad y comprender riesgos.|OpenSSH 9.9p2 release notes"
  "CVE-2025-26466|5.9 Media|OpenSSH client/server 9.5p1-9.9p1|Linux/Windows/macOS|DoS por consumo de memoria/CPU durante handshake (ping/pong packets) antes de autenticación.|Actualizar OpenSSH; usar rate limiting/firewall; MaxStartups/PerSourceMaxStartups.|OpenSSH 9.9p2 release notes"
  "CVE-2023-48795|5.9 Media|Protocolo SSH y muchas implementaciones (OpenSSH y otros) cuando usan extensiones vulnerables|Linux/Windows/otros|Terrapin: atacante MitM puede truncar mensajes iniciales y degradar seguridad (ej. downgrade de algoritmos/extensiones).|Actualizar implementaciones; usar algoritmos/etm seguros; aplicar parches de cliente y servidor.|terrapin-attack.com / NVD"
  "CVE-2023-51385|6.5 Media|OpenSSH client con ProxyCommand/expansión de tokens en ciertos casos|Linux/Windows/macOS (cliente)|Inyección de comandos vía nombres de host maliciosos si la configuración usa expansión insegura en ProxyCommand.|Actualizar OpenSSH; no usar nombres de host no confiables en configuraciones con expansión; sanear config.|OpenSSH 9.6p1 release notes"
  "CVE-2023-38408|9.8 Crítica|OpenSSH ssh-agent con forwarded agent en versiones vulnerables|Linux/macOS/Windows (cliente/agent)|Posible RCE vía biblioteca compartida cargada desde agent forwarding bajo ciertas condiciones.|Actualizar OpenSSH; evitar agent forwarding; usar ProxyJump en vez de agent forwarding cuando sea posible.|OpenSSH / NVD"
  "CVE-2021-41617|7.0 Alta|OpenSSH 6.2-8.7 en ciertas configuraciones AuthorizedKeysCommand/AuthorizedPrincipalsCommand|Linux/Unix|Escalada/ejecución por inicialización incorrecta de grupo suplementario en helper.|Actualizar OpenSSH; revisar configuraciones de AuthorizedKeysCommand.|OpenSSH 8.8p1 / NVD"
  "CVE-2020-15778|7.8 Alta|OpenSSH scp hasta versiones afectadas (diseño de scp)|Linux/Windows/macOS|scp puede permitir ejecución de comandos por nombres remotos maliciosos al copiar; depende de uso de scp con fuentes no confiables.|Usar sftp/rsync; actualizar y revisar políticas de uso; OpenSSH 8.8+ deshabilita protocolo scp legacy en ciertos modos.|NVD / OpenSSH"
  "CVE-2019-6111|5.9 Media|OpenSSH scp cliente/servidor (protocolo scp)|Linux/Windows/macOS|Manipulación de archivos por servidor malicioso durante scp (overwrite fuera de directorio esperado en escenarios).|Usar sftp; actualizar OpenSSH; no copiar desde servidores no confiables.|NVD"
  "CVE-2018-15473|5.3 Media|OpenSSH hasta 7.7 (enumeración de usuarios)|Linux/Unix|Permite enumerar usuarios válidos por diferencias de respuesta/tiempo.|Actualizar; deshabilitar autenticación por password si posible; usar rate limiting/fail2ban.|NVD"
  "CVE-2016-10012|7.8 Alta|OpenSSH antes de 7.4 (shared memory en pre-auth)|Linux/Unix|Bounds check en shared memory manager puede llevar a corrupción/DoS/RCE en escenarios específicos.|Actualizar OpenSSH; limitar acceso al servicio SSH.|NVD"
  "CVE-2016-0777|4.0 Media|OpenSSH client con roaming experimental|Linux/macOS/Windows (cliente)|Fuga de información de clave privada al conectarse a servidor malicioso con roaming habilitado.|Actualizar cliente; deshabilitar roaming (UseRoaming no en versiones antiguas).|OpenSSH / NVD"
  "CVE-2015-5600|8.5 Alta|OpenSSH hasta 6.9 (MaxAuthTries)|Linux/Unix|Bypass de limitación de intentos de contraseña con keyboard-interactive, facilitando brute force.|Actualizar OpenSSH; usar claves; fail2ban/rate limiting.|NVD"
  "CVE-2008-0166|7.8 Alta|OpenSSL en Debian/Ubuntu afectando claves generadas (incl. SSH keys)|Linux (Debian/Ubuntu derivados)|Generador RNG débil produjo claves predecibles; claves SSH generadas en periodo afectado son inseguras.|Regenerar claves afectadas; actualizar paquetes; auditar authorized_keys.|Debian Security Advisory"
  "CVE-2006-5051|9.8 Crítica|OpenSSH antes de 4.4 (signal handler race)|Linux/Unix|RCE no autenticada potencial por condición de carrera en GSSAPI/handler (histórica).|Actualizar; deshabilitar GSSAPI si no se usa; restringir acceso por red.|NVD"
  "CVE-2002-0640|10.0 Crítica|OpenSSH 3.x (privilege separation / challenge-response)|Linux/Unix|Vulnerabilidad histórica de RCE/privilege escalation en implementaciones antiguas.|Actualizar a versiones modernas; no exponer versiones obsoletas.|NVD"
)

WIN_VULNS=(
  "CVE-2024-38029|7.5 Alta|Microsoft Windows OpenSSH Server (varias versiones Windows Server/Client)|Windows|Fuga/ejecución remota de código en escenarios específicos de OpenSSH en Windows según parche Microsoft.|Aplicar actualizaciones de Windows Update; revisar versión de OpenSSH opcional.|Microsoft Security Response Center"
  "CVE-2023-48795|5.9 Media|Implementaciones SSH en Windows (OpenSSH de Microsoft, PuTTY, etc., según versión)|Windows|Terrapin afecta protocolo; impacto depende de versión/configuración.|Actualizar OpenSSH de Windows, PuTTY/WinSCP u otros clientes; aplicar parches.|MSRC / terrapin-attack.com"
  "CVE-2019-16905|7.8 Alta|OpenSSH en Windows (antes de correcciones) - XMU/OEM/agent issues según implementación|Windows|Algunas implementaciones/ports tenían problemas de escalación o manejo de memoria; depende de build.|Mantener OpenSSH actualizado desde Windows Update; revisar advisories.|NVD / vendor advisories"
)

show_vuln_detail() {
  local entry="$1"
  IFS='|' read -r id sev affects systems summary mitigation ref <<< "$entry"
  echo -e "${BOLD}${CYAN}$id${NC} ${YELLOW}[$sev]${NC}"
  echo -e "${BOLD}Afecta:${NC} $affects"
  echo -e "${BOLD}Sistemas:${NC} $systems"
  echo -e "${BOLD}Resumen:${NC} $summary"
  echo -e "${BOLD}Mitigación:${NC} $mitigation"
  echo -e "${BOLD}Referencia:${NC} $ref"
  echo
}

vuln_menu() {
  while true; do
    banner
    echo -e "${BOLD}Catálogo educativo de vulnerabilidades SSH/OpenSSH${NC}"
    echo "Nota: lista curada de CVEs relevantes/históricas. No es exhaustiva."
    echo "Usa esto para aprender a evaluar y mitigar en tu laboratorio."
    echo
    echo "  1) Ver vulnerabilidades comunes OpenSSH/Linux/multiplataforma"
    echo "  2) Ver vulnerabilidades relevantes en Windows/OpenSSH"
    echo "  3) Ver todas"
    echo "  4) Buscar por CVE/texto"
    echo "  5) Checklist de hardening SSH"
    echo "  0) Volver"
    read -r -p "Opción: " opt
    case "$opt" in
      1)
        banner; echo -e "${BOLD}OpenSSH / multiplataforma${NC}\n"
        for v in "${VULNS[@]}"; do show_vuln_detail "$v"; done
        pause ;;
      2)
        banner; echo -e "${BOLD}Windows / OpenSSH${NC}\n"
        for v in "${WIN_VULNS[@]}"; do show_vuln_detail "$v"; done
        echo -e "${YELLOW}Nota:${NC} En Windows, muchas correcciones llegan por Windows Update y por versiones del componente OpenSSH opcional."
        pause ;;
      3)
        banner; echo -e "${BOLD}Todas (curadas)${NC}\n"
        for v in "${VULNS[@]}" "${WIN_VULNS[@]}"; do show_vuln_detail "$v"; done
        pause ;;
      4)
        read -r -p "Texto/CVE a buscar: " q
        q="${q,,}"
        banner; echo -e "${BOLD}Resultados para: $q${NC}\n"
        local found=0
        for v in "${VULNS[@]}" "${WIN_VULNS[@]}"; do
          if [[ "${v,,}" == *"$q"* ]]; then show_vuln_detail "$v"; found=1; fi
        done
        [[ $found -eq 0 ]] && echo "No se encontraron coincidencias en el catálogo curado."
        pause ;;
      5) hardening_checklist ;;
      0) return ;;
      *) echo "Opción inválida."; sleep 1 ;;
    esac
  done
}

hardening_checklist() {
  banner
  echo -e "${BOLD}Checklist de hardening SSH (laboratorio)${NC}\n"
  cat <<'TXT'
[Linux - sshd_config]
  - PasswordAuthentication no (usar claves)
  - PermitRootLogin no
  - PubkeyAuthentication yes
  - MaxAuthTries 3
  - LoginGraceTime 30
  - AllowUsers / AllowGroups para limitar acceso
  - X11Forwarding no (si no se necesita)
  - Usar algoritmos modernos y actualizar OpenSSH

[Windows - OpenSSH Server]
  - Instalar OpenSSH Server desde componente oficial
  - Mantener Windows Update al día
  - Configurar firewall para red local
  - Usar claves y deshabilitar password si es posible
  - Revisar %ProgramData%\ssh\sshd_config y logs

[Red/operación]
  - Exponer SSH solo en red local/lab
  - Usar fail2ban/rate limiting
  - Rotar claves y auditar authorized_keys
  - Monitorear logs de autenticación
TXT
  pause
}

profile_menu() {
  while true; do
    banner
    echo -e "${BOLD}Perfiles de hosts (laboratorio)${NC}"
    echo "  1) Guardar/actualizar perfil"
    echo "  2) Conectar usando perfil"
    echo "  3) Eliminar perfil"
    echo "  4) Ver perfiles"
    echo "  0) Volver"
    read -r -p "Opción: " opt
    case "$opt" in
      1) save_profile ;;
      2) load_profile_and_connect ;;
      3) delete_profile ;;
      4) banner; list_profiles >/dev/null; 
         local i=0; while IFS=, read -r name os host user port auth key_path; do
           [[ "$name" == "name" ]] && continue; i=$((i+1))
           printf "  %2d) %-20s %-7s %s@%s:%s (%s)\n" "$i" "$name" "$os" "$user" "$host" "$port" "$auth"
         done < "$PROFILE_FILE"; [[ $i -eq 0 ]] && echo "  (No hay perfiles)"; pause ;;
      0) return ;;
      *) echo "Opción inválida."; sleep 1 ;;
    esac
  done
}

main_menu() {
  check_dependencies
  while true; do
    banner
    warning
    echo -e "${BOLD}Menú principal${NC}"
    echo "  1) Conexión manual por SSH"
    echo "  2) Perfiles de hosts (guardar/usar)"
    echo "  3) Catálogo educativo de vulnerabilidades SSH"
    echo "  4) Checklist de hardening"
    echo "  0) Salir"
    read -r -p "Selecciona una opción: " opt
    case "$opt" in
      1) banner; warning; manual_connect ;;
      2) profile_menu ;;
      3) vuln_menu ;;
      4) hardening_checklist ;;
      0) echo "Saliendo."; exit 0 ;;
      *) echo "Opción inválida."; sleep 1 ;;
    esac
  done
}

main_menu "$@"
