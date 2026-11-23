#!/usr/bin/env bash
# Sincronizacion bidireccional GitHub <-> GitLab de la rama main.
# Se usa igual desde GitHub Actions y desde GitLab CI.
#
# Variables de entorno:
#   SYNC_SSH_KEY    clave privada (obligatoria; si falta, no hace nada)
#   SYNC_KNOWN_HOSTS  contenido de known_hosts (opcional; si falta, ssh-keyscan)
#   SYNC_GH_TOKEN   token de GitHub para avisar de conflictos creando un issue (opcional)
#   SYNC_BRANCH     rama a sincronizar (por defecto main)
#   SYNC_REMOTE_GH / SYNC_REMOTE_GL  nombres de remotos (por defecto github / gitlab)

set -euo pipefail

BRANCH="${SYNC_BRANCH:-main}"
REMOTE_GH="${SYNC_REMOTE_GH:-github}"
REMOTE_GL="${SYNC_REMOTE_GL:-gitlab}"

log() { echo "[mirror] $*"; }

if [[ -z "${SYNC_SSH_KEY:-}" ]]; then
  log "SYNC_SSH_KEY no configurado; se omite la sincronizacion."
  exit 0
fi

KEY_FILE="$HOME/.ssh/mirror_key"
mkdir -p "$HOME/.ssh"
printf '%s\n' "$SYNC_SSH_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

if [[ -n "${SYNC_KNOWN_HOSTS:-}" ]]; then
  printf '%s\n' "$SYNC_KNOWN_HOSTS" >> "$HOME/.ssh/known_hosts"
else
  ssh-keyscan -t ed25519 github.com gitlab.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi

export GIT_SSH_COMMAND="ssh -i $KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
git config user.name "mirror-bot"
git config user.email "mirror-bot@users.noreply.local"

git fetch --no-tags "$REMOTE_GH" "+refs/heads/$BRANCH:refs/remotes/$REMOTE_GH/$BRANCH" 2>/dev/null || true
git fetch --no-tags "$REMOTE_GL" "+refs/heads/$BRANCH:refs/remotes/$REMOTE_GL/$BRANCH" 2>/dev/null || true

GH_SHA="$(git rev-parse --verify -q "refs/remotes/$REMOTE_GH/$BRANCH" || true)"
GL_SHA="$(git rev-parse --verify -q "refs/remotes/$REMOTE_GL/$BRANCH" || true)"

if [[ -z "$GH_SHA" && -z "$GL_SHA" ]]; then
  log "Ningun remoto tiene la rama $BRANCH todavia."
  exit 0
fi
if [[ -z "$GL_SHA" ]]; then
  log "GitLab no tiene $BRANCH; creandola desde GitHub."
  git push "$REMOTE_GL" "$GH_SHA:refs/heads/$BRANCH"
  exit 0
fi
if [[ -z "$GH_SHA" ]]; then
  log "GitHub no tiene $BRANCH; creandola desde GitLab."
  git push "$REMOTE_GH" "$GL_SHA:refs/heads/$BRANCH"
  exit 0
fi

if [[ "$GH_SHA" == "$GL_SHA" ]]; then
  log "Ya sincronizados en $GH_SHA."
  exit 0
fi

if git merge-base --is-ancestor "$GH_SHA" "$GL_SHA"; then
  log "GitLab va por delante -> actualizando GitHub."
  git push "$REMOTE_GH" "$GL_SHA:refs/heads/$BRANCH"
  log "Listo."
  exit 0
fi

if git merge-base --is-ancestor "$GL_SHA" "$GH_SHA"; then
  log "GitHub va por delante -> actualizando GitLab."
  git push "$REMOTE_GL" "$GH_SHA:refs/heads/$BRANCH"
  log "Listo."
  exit 0
fi

log "Historiales divergentes; intentando fusion automatica."
git checkout -q -B mirror-merge "$GH_SHA"
if git merge --no-edit --no-ff "$GL_SHA"; then
  MERGED="$(git rev-parse HEAD)"
  log "Fusion correcta ($MERGED); publicando en ambos remotos."
  git push "$REMOTE_GH" "$MERGED:refs/heads/$BRANCH"
  git push "$REMOTE_GL" "$MERGED:refs/heads/$BRANCH"
  log "Listo."
else
  git merge --abort || true
  log "CONFLICTO: las dos ramas cambiaron el mismo contenido y no se pudo fusionar."
  log "No se ha forzado ningun push. Revisa los dos repos y resuelve a mano."
  if [[ -n "${SYNC_GH_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
    gh issue create \
      --repo "${SYNC_GH_REPO:-BENDER35/script-laboratorio-local-1-zona-ssh}" \
      --title "Conflicto en el mirror GitHub <-> GitLab" \
      --body "La sincronizacion automatica encontro historiales divergentes en \`$BRANCH\` (GitHub \`$GH_SHA\`, GitLab \`$GL_SHA\`). Revisa ambos repositorios y resuelve el conflicto manualmente." \
      || log "No se pudo crear el issue de aviso."
  fi
  exit 2
fi
