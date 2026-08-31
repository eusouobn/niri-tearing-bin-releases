#!/bin/bash
# =============================================================================
#  install.sh — niri-tearing-bin-releases
#
#  Instala o niri-tearing-bin (binário pré-compilado) de uma vez só:
#    1) Baixa e extrai o binário sobre /
#    2) Instala o updater em /usr/local/bin/
#    3) Instala o hook do pacman (/etc/pacman.d/hooks/) para atualizações
#       automáticas a cada "sudo pacman -Syu".
#
#  Uso:  sudo bash install.sh
# =============================================================================

set -euo pipefail

REPO="eusouobn/niri-tearing-bin-releases"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
API_BASE="https://api.github.com/repos/$REPO/releases/latest"
BASE_URL="https://github.com/$REPO/releases/download"

UPDATER="/usr/local/bin/niri-tearing-bin-update.sh"
HOOK_DST="/etc/pacman.d/hooks/90-niri-tearing-bin.hook"
PKG_MARK="/usr/share/niri-tearing-bin"
VERSION_FILE="$PKG_MARK/version"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "  ${YELLOW}→${NC} $1"; }
ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
fail() { echo -e "  ${RED}✘${NC} $1"; }

# -----------------------------------------------------------------------------
# 0. Verificações
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    fail "Execute como root:  sudo bash install.sh"
    exit 1
fi

for cmd in curl tar pacman; do
    command -v "$cmd" >/dev/null 2>&1 || {
        fail "Comando '$cmd' não encontrado."
        exit 1
    }
done

echo ""
echo -e "${GREEN}=== Instalador do niri-tearing-bin ===${NC}"
info "Repositório: $REPO"
echo ""

# -----------------------------------------------------------------------------
# 1. Descobrir a última versão publicada
# -----------------------------------------------------------------------------
info "Consultando a última versão no GitHub..."
LATEST="$(curl -fsSL "$API_BASE" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
if [ -z "$LATEST" ]; then
    fail "Não foi possível determinar a última versão."
    exit 1
fi
ok "Última versão: $LATEST"
echo ""

# -----------------------------------------------------------------------------
# 2. Baixar e extrair o binário sobre /
# -----------------------------------------------------------------------------
TARBALL="niri-full-${LATEST}-x86_64.tar.gz"
TMP_DIR="$(mktemp -d)"
TMP_TAR="$TMP_DIR/$TARBALL"
trap 'rm -rf "$TMP_DIR"' EXIT

info "Baixando $TARBALL ..."
curl -fL --retry 3 -o "$TMP_TAR" "$BASE_URL/$LATEST/$TARBALL" \
    || { fail "Falha ao baixar $TARBALL."; exit 1; }

info "Instalando arquivos sobre / ..."
tar -xzf "$TMP_TAR" -C / --overwrite \
    || { fail "Falha ao extrair o tarball."; exit 1; }
ok "Binário instalado em /usr/bin/niri"
echo ""

# -----------------------------------------------------------------------------
# 3. Instalar o updater
# -----------------------------------------------------------------------------
info "Instalando updater em /usr/local/bin/ ..."
curl -fsSL "$RAW_BASE/niri-tearing-bin-update.sh" -o "$UPDATER"
chmod +x "$UPDATER"
ok "Updater instalado: $UPDATER"
echo ""

# -----------------------------------------------------------------------------
# 4. Instalar o hook do pacman
# -----------------------------------------------------------------------------
info "Instalando hook do pacman ..."
mkdir -p /etc/pacman.d/hooks
curl -fsSL "$RAW_BASE/90-niri-tearing-bin.hook" -o "$HOOK_DST"
ok "Hook instalado: $HOOK_DST"
echo ""

# -----------------------------------------------------------------------------
# 5. Marcar versão instalada
# -----------------------------------------------------------------------------
mkdir -p "$PKG_MARK"
echo "$LATEST" > "$VERSION_FILE"
cp "$TMP_TAR" "$PKG_MARK/$TARBALL" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 6. Confirmar instalação
# -----------------------------------------------------------------------------
echo -e "${GREEN}═══ Instalação concluída! ═══${NC}"
if [ -x /usr/bin/niri ]; then
    /usr/bin/niri --version 2>/dev/null | head -n1 || echo "niri instalado"
fi
info "A partir de agora, o niri-tearing-bin é atualizado automaticamente"
info "a cada 'sudo pacman -Syu' (via hook do pacman)."
echo ""
