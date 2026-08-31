#!/bin/bash
set -e

# =============================================================================
#  update-niri-bin.sh
#  Empacota o niri (fork com tearing) a partir da TAG OFICIAL do upstream
#  e publica o binário pré-compilado como GitHub Release.
#
#  Repo de releases : https://github.com/eusouobn/niri-tearing-bin-releases
#  Upstream         : https://github.com/urayde/niri
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --force: força o rebuild/publicação mesmo se a versão já estiver atual
FORCE=0
if [ "$1" = "--force" ]; then
    FORCE=1
fi

UPSTREAM="https://github.com/urayde/niri.git"
REPO="eusouobn/niri-tearing-bin-releases"

# Nome do branch local que aponta para o repo de releases
REL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/niri-tearing-tag-build"
SRC_DIR="$BUILD_ROOT/niri"
PACKAGING_NAME="niri-tearing-bin"

echo -e "${GREEN}=== Empacotador automático do niri-tearing-bin (via tag upstream) ===${NC}"

# -----------------------------------------------------------------------------
# 0. Pré-requisitos
# -----------------------------------------------------------------------------
for cmd in cargo rustc git gh clang makepkg; do
    command -v "$cmd" >/dev/null 2>&1 || { echo -e "${RED}ERRO: '$cmd' não instalado.${NC}"; exit 1; }
done

# -----------------------------------------------------------------------------
# 1. Descobrir a TAG mais recente de release do upstream
#    (ex: v26.04) e a versão do pacote correspondente (sem o 'v').
# -----------------------------------------------------------------------------
echo -e "${GREEN}Consultando tags de release no upstream...${NC}"
LATEST_TAG=$(git ls-remote --tags "$UPSTREAM" \
    | awk '{print $2}' \
    | grep -E '/v[0-9]+(\.[0-9]+)*(_?[0-9]+)?$' \
    | sed 's#refs/tags/##' \
    | sort -V \
    | tail -n1)

if [ -z "$LATEST_TAG" ]; then
    echo -e "${RED}ERRO: Não foi possível determinar a tag mais recente.${NC}"
    exit 1
fi

# Versão do pacote = tag sem o prefixo 'v' (ex: 26.04)
NEW_VER="${LATEST_TAG#v}"
echo -e "${GREEN}Tag upstream mais recente : ${LATEST_TAG}${NC}"
echo -e "${GREEN}Versão do pacote           : ${NEW_VER}${NC}"

# -----------------------------------------------------------------------------
# 2. Comparar com a versão atual no PKGBUILD do repo de releases
# -----------------------------------------------------------------------------
CURRENT_VER=$(grep "^pkgver=" "$REL_DIR/PKGBUILD" | cut -d'=' -f2)
echo -e "${GREEN}Versão atual no PKGBUILD  : ${CURRENT_VER}${NC}"

if [ "$CURRENT_VER" = "$NEW_VER" ] && [ "$FORCE" -eq 0 ]; then
    echo -e "${YELLOW}Já está na tag mais recente (${NEW_VER}). Nada a fazer.${NC}"
    exit 0
fi

echo -e "${YELLOW}Nova tag detectada! Empacotando a versão ${NEW_VER}...${NC}"

# -----------------------------------------------------------------------------
# 3. Clonar o upstream e fazer checkout da tag
# -----------------------------------------------------------------------------
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
git clone --quiet "$UPSTREAM" "$SRC_DIR"
cd "$SRC_DIR"
git checkout --quiet "$LATEST_TAG"
echo -e "${GREEN}Checkout na tag ${LATEST_TAG} (commit $(git rev-parse --short HEAD))${NC}"

# -----------------------------------------------------------------------------
# 4. Compilar em modo release (mesmo procedimento do PKGBUILD AUR)
# -----------------------------------------------------------------------------
export CARGO_HOME="$SRC_DIR/.cargo"
export CARGO_TARGET_DIR="$SRC_DIR/target"
export CARGO_ENCODED_RUSTFLAGS="--remap-path-prefix=$(pwd)=/"

echo -e "${GREEN}Baixando dependências (cargo fetch --locked)...${NC}"
cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"

echo -e "${GREEN}Compilando (cargo build --frozen --release). Pode demorar...${NC}"
cargo build --frozen --release

# -----------------------------------------------------------------------------
# 5. Montar a estrutura de pacote (usr/)
# -----------------------------------------------------------------------------
cd "$BUILD_ROOT"
PKG_TEMP="$BUILD_ROOT/pkg-temp"
rm -rf "$PKG_TEMP"
mkdir -p "$PKG_TEMP/usr/bin"
mkdir -p "$PKG_TEMP/usr/lib/systemd/user"
mkdir -p "$PKG_TEMP/usr/share/wayland-sessions"
mkdir -p "$PKG_TEMP/usr/share/xdg-desktop-portal"

cp "$SRC_DIR/target/release/niri"                  "$PKG_TEMP/usr/bin/"
cp "$SRC_DIR/resources/niri-session"               "$PKG_TEMP/usr/bin/"
cp "$SRC_DIR/resources/niri.desktop"               "$PKG_TEMP/usr/share/wayland-sessions/"
cp "$SRC_DIR/resources/niri-portals.conf"          "$PKG_TEMP/usr/share/xdg-desktop-portal/"
cp "$SRC_DIR/resources/niri.service"               "$PKG_TEMP/usr/lib/systemd/user/"
cp "$SRC_DIR/resources/niri-shutdown.target"       "$PKG_TEMP/usr/lib/systemd/user/"

# Copia a licença GPL para o pacote
mkdir -p "$PKG_TEMP/usr/share/licenses/$PACKAGING_NAME"
if [ -f "$SRC_DIR/LICENSE" ]; then
    cp "$SRC_DIR/LICENSE" "$PKG_TEMP/usr/share/licenses/$PACKAGING_NAME/LICENSE"
elif [ -f "$SRC_DIR/COPYING" ]; then
    cp "$SRC_DIR/COPYING" "$PKG_TEMP/usr/share/licenses/$PACKAGING_NAME/COPYING"
fi

TARBALL="niri-full-${NEW_VER}-x86_64.tar.gz"
rm -f "$TARBALL"
tar -czf "$TARBALL" -C "$PKG_TEMP" .

# -----------------------------------------------------------------------------
# 6. Publicar no GitHub Releases (a tag do niri NÃO leva prefixo 'v')
# -----------------------------------------------------------------------------
echo -e "${GREEN}Publicando no GitHub Releases...${NC}"
if gh release view "$NEW_VER" -R "$REPO" &>/dev/null; then
    gh release delete "$NEW_VER" -R "$REPO" --yes
fi

gh release create "$NEW_VER" "$TARBALL" -R "$REPO" \
    --title "niri-full ${NEW_VER}" \
    --notes "Binário pré-compilado do niri (tearing fork) a partir da tag upstream ${LATEST_TAG} (commit $(cd "$SRC_DIR" && git rev-parse --short HEAD))."

echo -e "${GREEN}Release publicada: https://github.com/$REPO/releases/tag/$NEW_VER${NC}"

# -----------------------------------------------------------------------------
# 7. Atualizar PKGBUILD do repo de releases
# -----------------------------------------------------------------------------
cd "$REL_DIR"
sed -i "s/^pkgver=.*/pkgver=${NEW_VER}/" PKGBUILD
NEW_SHA256=$(sha256sum "$BUILD_ROOT/$TARBALL" | awk '{print $1}')
sed -i "s|https://github.com/$REPO/releases/download/[^/]*/|https://github.com/$REPO/releases/download/$NEW_VER/|" PKGBUILD
sed -i "s/^sha256sums=.*/sha256sums=('${NEW_SHA256}')/" PKGBUILD

# Regenera o .SRCINFO (se makepkg estiver disponível)
if command -v makepkg >/dev/null 2>&1; then
    makepkg --printsrcinfo > .SRCINFO 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 8. Commit e push para o repo de releases (branch main)
# -----------------------------------------------------------------------------
git add PKGBUILD .SRCINFO
git commit -m "Atualização automática para a tag upstream ${LATEST_TAG} (pkgver ${NEW_VER})" 2>/dev/null \
    && git push origin main || echo -e "${YELLOW}Nada para commitar (ou push falhou).${NC}"

# -----------------------------------------------------------------------------
# 9. Limpeza
# -----------------------------------------------------------------------------
rm -rf "$BUILD_ROOT"
rm -f "$(dirname "$0")/niri-full-${NEW_VER}-x86_64.tar.gz"
echo -e "${GREEN}✅ Concluído com sucesso!${NC}"
