# Mirror bidireccional GitHub <-> GitLab

La rama `main` se sincroniza en ambos sentidos. Cada plataforma ejecuta el mismo
script (`scripts/sync-mirrors.sh`) desde su propio CI:

- **GitHub Actions** (`.github/workflows/mirror.yml`): al hacer push a `main`, cada
  15 minutos y manualmente. Usa la clave `GITLAB_DEPLOY_KEY` (deploy key de GitLab
  con permiso de escritura).
- **GitLab CI** (`.gitlab-ci.yml`): al hacer push a `main`, con pipeline programado
  y ejecución manual. Usa la variable `GITHUB_DEPLOY_KEY` (deploy key de GitHub con
  permiso de escritura).

## Comportamiento

1. Si los dos repos tienen el mismo commit, no hace nada (esto corta los bucles).
2. Si uno está por delante, hace fast-forward del otro.
3. Si los historiales divergieron, intenta un merge. Si tiene éxito, sube el commit
   de merge a ambos. Si hay conflicto real, **no fuerza nada**: falla el job y,
   cuando hay token disponible, crea un issue de aviso en GitHub.

## Secretos configurados

| Plataforma | Variable | Contenido |
|---|---|---|
| GitHub Actions | `GITLAB_DEPLOY_KEY` | Clave privada del deploy key del proyecto GitLab |
| GitHub Actions | `GITLAB_KNOWN_HOSTS` (variable) | Entrada `ed25519` de `gitlab.com` |
| GitLab CI | `GITHUB_DEPLOY_KEY` | Clave privada del deploy key del repo GitHub |
| GitLab CI | `GITHUB_KNOWN_HOSTS` | Entrada `ed25519` de `github.com` |

> Los cambios se sincronizan solo en `main`. Los tags y las releases de GitHub no
> se replican automáticamente a GitLab.
