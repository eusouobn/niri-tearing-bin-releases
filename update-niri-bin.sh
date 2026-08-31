#!/bin/bash
set -e
rm -rf /tmp/niri-tearing-git-build /tmp/niri-tearing-extracted

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Repositório upstream do niri-tearing (fork com tearing)
UPSTREAM="https://github.com/urayde/niri.git"

echo -e "${GREEN}=== Atualizador automático do niri-tearing-git-bin ===${NC}"

# 1. Obter versão atual do -bin (do PKGBUILD)
CURRENT_VER=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
echo -e "${GREEN}Versão atual do -bin: ${CURRENT_VER}${NC}"

# 2. Consultar o commit mais recente do upstream
echo -e "${GREEN}Consultando commit mais recente do upstream...${NC}"
LATEST_SHA=$(git ls-remote "$UPSTREAM" HEAD | cut -f1)
if [ -z "$LATEST_SHA" ]; then
    echo -e "${RED}ERRO: Não foi possível consultar o upstream.${NC}"
    exit 1
fi
echo -e "${GREEN}Commit mais recente no upstream: ${LATEST_SHA}${NC}"

CURRENT_SHA=$(echo "$CURRENT_VER" | grep -oE '[0-9a-f]{7,}$' | head -1)

# 3. Comparar os commits (a versão do RPC do AUR é desatualizada para -git)
if [[ "$LATEST_SHA" == "$CURRENT_SHA"* ]]; then
    echo -e "${YELLOW}Já está na versão mais recente. Nada a fazer.${NC}"
    exit 0
fi

echo -e "${YELLOW}Nova versão disponível! Atualizando...${NC}"

# 4. Clonar o -git do AUR e compilar (gera os binários da versão nova)
echo -e "${GREEN}Baixando PKGBUILD do niri-tearing-git...${NC}"
git clone https://aur.archlinux.org/niri-tearing-git.git /tmp/niri-tearing-git-build
cd /tmp/niri-tearing-git-build

echo -e "${GREEN}Compilando niri-tearing-git... (build Rust, pode demorar)${NC}"
makepkg --noconfirm

# 5. Obter a versão real calculada pelo makepkg e extrair os binários
echo -e "${GREEN}Extraindo arquivos do pacote compilado...${NC}"
PKG_FILE=$(ls niri-tearing-git-*.pkg.tar.zst | grep -v -- '-debug-' | head -1)
NEW_VER=$(basename "$PKG_FILE" .zst | sed -E 's/^niri-tearing-git-//; s/-[0-9]+-[^.]+\.pkg\.tar$//')
mkdir -p /tmp/niri-tearing-extracted
tar -xf "$PKG_FILE" -C /tmp/niri-tearing-extracted
echo -e "${GREEN}Versão compilada: ${NEW_VER}${NC}"

# 6. Criar estrutura do tarball para o -bin
echo -e "${GREEN}Criando tarball para o -bin...${NC}"
cd /tmp
rm -rf pkg-temp
mkdir -p pkg-temp/usr/bin
mkdir -p pkg-temp/usr/lib/systemd/user
mkdir -p pkg-temp/usr/share/wayland-sessions
mkdir -p pkg-temp/usr/share/xdg-desktop-portal

cp /tmp/niri-tearing-extracted/usr/bin/niri pkg-temp/usr/bin/
cp /tmp/niri-tearing-extracted/usr/bin/niri-session pkg-temp/usr/bin/
cp /tmp/niri-tearing-extracted/usr/lib/systemd/user/niri-shutdown.target pkg-temp/usr/lib/systemd/user/
cp /tmp/niri-tearing-extracted/usr/lib/systemd/user/niri.service pkg-temp/usr/lib/systemd/user/
cp /tmp/niri-tearing-extracted/usr/share/wayland-sessions/niri.desktop pkg-temp/usr/share/wayland-sessions/
cp /tmp/niri-tearing-extracted/usr/share/xdg-desktop-portal/niri-portals.conf pkg-temp/usr/share/xdg-desktop-portal/

# Copia a licença (se existir)
if [ -d "/tmp/niri-tearing-extracted/usr/share/licenses/niri-tearing-git" ]; then
    mkdir -p pkg-temp/usr/share/licenses/niri-tearing-git-bin
    cp -r /tmp/niri-tearing-extracted/usr/share/licenses/niri-tearing-git/* pkg-temp/usr/share/licenses/niri-tearing-git-bin/
    echo "✅ Licença do Niri-Tearing copiada."
fi

TARBALL="niri-full-${NEW_VER}-x86_64.tar.gz"
tar -czf "$TARBALL" -C pkg-temp .
rm -rf pkg-temp

# 7. Enviar para GitHub Releases (a tag do niri NÃO tem prefixo 'v')
echo -e "${GREEN}Enviando para GitHub Releases...${NC}"
REPO="eusouobn/niri-tearing-bin-releases"
TAG="${NEW_VER}"

if ! command -v gh &>/dev/null; then
    echo -e "${RED}GitHub CLI não instalado. Instale com 'sudo pacman -S github-cli' e autentique.${NC}"
    exit 1
fi

if gh release view "$TAG" -R "$REPO" &>/dev/null; then
    gh release delete "$TAG" -R "$REPO" --yes
fi

gh release create "$TAG" "$TARBALL" -R "$REPO" \
    --title "niri-full ${NEW_VER}" \
    --notes "Build automático da versão ${NEW_VER}"

# 8. Atualizar o PKGBUILD do -bin
cd ~/aur-bins/niri-tearing-git-bin
echo -e "${GREEN}Atualizando PKGBUILD...${NC}"
sed -i "s/^pkgver=.*/pkgver=${NEW_VER}/" PKGBUILD
sed -i "s|https://github.com/eusouobn/niri-tearing-bin-releases/releases/download/[^/]*/|https://github.com/eusouobn/niri-tearing-bin-releases/releases/download/${NEW_VER}/|" PKGBUILD

# 9. Recalcular checksums
echo -e "${GREEN}Recalculando checksums...${NC}"
updpkgsums

# 10. Atualizar .SRCINFO
echo -e "${GREEN}Atualizando .SRCINFO...${NC}"
makepkg --printsrcinfo > .SRCINFO

# 11. Commit e push para o AUR
echo -e "${GREEN}Fazendo commit e push para o AUR...${NC}"
git add PKGBUILD .SRCINFO
git commit -m "Atualização automática para versão ${NEW_VER}"
git push origin master

# 12. Limpeza
echo -e "${GREEN}Limpando arquivos temporários...${NC}"
rm -rf /tmp/niri-tearing-git-build /tmp/niri-tearing-extracted /tmp/pkg-temp /tmp/"$TARBALL"

echo -e "${GREEN}✅ Atualização concluída com sucesso!${NC}"
echo -e "Pacote disponível em: https://aur.archlinux.org/packages/niri-tearing-git-bin"
