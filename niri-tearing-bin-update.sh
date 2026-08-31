#!/bin/bash
# =============================================================================
#  niri-tearing-bin-update.sh
#  Instala ou atualiza o niri-tearing-bin (binário pré-compilado) extraindo o
#  tarball do GitHub Releases sobre o sistema.
#
#  Uso:
#    niri-tearing-bin-update.sh            # instala/atualiza (root)
#    niri-tearing-bin-update.sh --check    # só verifica, não instala
#
#  Chamado pelo hook do pacman (90-niri-tearing-bin.hook) a cada transação.
# =============================================================================

set -euo pipefail

REPO="eusouobn/niri-tearing-bin-releases"
BASE_URL="https://github.com/$REPO/releases/download"
VERSION_FILE="/usr/share/niri-tearing-bin/version"
MANIFEST="/usr/share/niri-tearing-bin/files.txt"
PKG_MARK="/usr/share/niri-tearing-bin"
BIN_DST="/usr/bin/niri"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
    CHECK_ONLY=1
fi

log()  { echo -e "\033[1;32m[niri-tearing-bin]\033[0m $*"; }
warn() { echo -e "\033[1;33m[niri-tearing-bin]\033[0m $*"; }
fail() { echo -e "\033[1;31m[niri-tearing-bin][ERRO]\033[0m $*"; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        fail "'$1' não está instalado."
        return 1
    }
}

# -----------------------------------------------------------------------------
# Descobrir a última versão publicada no GitHub Releases.
# Prefere a API do GitHub; se falhar, tenta com curl na página do release.
# -----------------------------------------------------------------------------
get_latest_version() {
    if command -v gh >/dev/null 2>&1; then
        gh release list -R "$REPO" --limit 1 --json tagName \
            --jq '.[0].tagName' 2>/dev/null || true
    fi
    if [ -z "${LATEST:-}" ]; then
        # fallback: curl da página do release (sem depender do gh)
        curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
            2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
    fi
}

# -----------------------------------------------------------------------------
# Obter a versão atualmente instalada (arquivo de marca, se existir)
# -----------------------------------------------------------------------------
get_installed_version() {
    [ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo ""
}

# -----------------------------------------------------------------------------
main() {
    # Apenas root pode instalar em /
    if [ "$(id -u)" -ne 0 ]; then
        fail "Execute como root (sudo)."
        # Não-fatal: nunca quebrar o pacman -Syu
        return 0
    fi

    log "Repositório: $REPO"

    # Última versão publicada
    local LATEST=""
    LATEST="$(get_latest_version)"
    if [ -z "$LATEST" ]; then
        warn "Não foi possível consultar a última versão no GitHub. Pulando."
        return 0
    fi
    log "Última versão publicada: $LATEST"

    # Versão instalada
    local INSTALLED="$(get_installed_version)"
    if [ -n "$INSTALLED" ] && [ "$INSTALLED" = "$LATEST" ]; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
            log "Já na versão mais recente ($INSTALLED)."
        else
            log "Já na versão mais recente ($INSTALLED). Nada a fazer."
        fi
        return 0
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
        log "Nova versão disponível: $LATEST (instalada: ${INSTALLED:-nenhuma})"
        return 1
    fi

    log "Versão instalada: ${INSTALLED:-nenhuma} → nova: $LATEST"

    # Tarball correspondente
    local TARBALL="niri-full-${LATEST}-x86_64.tar.gz"
    local TMP_DIR TMP_TAR
    TMP_DIR="$(mktemp -d)"
    TMP_TAR="$TMP_DIR/$TARBALL"

    cleanup() { rm -rf "$TMP_DIR"; }
    trap cleanup EXIT

    log "Baixando $TARBALL..."
    if ! require_cmd curl; then
        fail "O pacote 'curl' é necessário para baixar o binário."
        return 0
    fi
    curl -fL --retry 3 -o "$TMP_TAR" "$BASE_URL/$LATEST/$TARBALL" \
        || { fail "Falha ao baixar '$TARBALL'."; return 0; }

    # Extrai sobre / (mesma estrutura usr/ do tarball)
    log "Instalando arquivos sobre / ..."
    tar -xzf "$TMP_TAR" -C / --overwrite \
        || { fail "Falha ao extrair o tarball."; return 0; }

    # Marca versão + manifest
    mkdir -p "$PKG_MARK"
    echo "$LATEST" > "$VERSION_FILE"
    cp "$TMP_TAR" "$PKG_MARK/$(basename "$TMP_TAR")" 2>/dev/null || true
    tar -tzf "$TMP_TAR" | sed 's#^\./##' | grep -v '^$' > "$MANIFEST" 2>/dev/null || true

    log "niri-tearing-bin atualizado para $LATEST."
    if [ -x "$BIN_DST" ]; then
        "$BIN_DST" --version 2>/dev/null | head -n1 || true
    fi
    return 0
}

main "$@"
# Garante saída não-fatal mesmo se --check retornar 1 (nunca quebrar o hook do pacman)
exit 0
