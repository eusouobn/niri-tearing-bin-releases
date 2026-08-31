#!/bin/bash
# =============================================================================
#  migrate.sh — niri-tearing-bin-releases
#
#  Migra com segurança de um niri instalado pelo AUR (niri-tearing-git, ou o
#  pacote 'niri' do repositório extra) para o niri-tearing-bin pré-compilado.
#
#  Motivo: não é possível sobrescrever /usr/bin/niri enquanto ele está em uso
#  (sessão gráfica ativa). Este script renomeia os binários em execução para um
#  backup (o processo atual continua rodando até o reboot) e então instala o
#  binário pré-compilado. Após reiniciar, o novo niri-tearing-bin será o usado.
#
#  Uso:  sudo bash migrate.sh
# =============================================================================

set -euo pipefail

REPO="eusouobn/niri-tearing-bin-releases"
INSTALL_RAW="https://raw.githubusercontent.com/$REPO/main/install.sh"
BACKUP_SUFFIX=".aur-bak"
NIRI_BIN="/usr/bin/niri"
NIRI_SESSION="/usr/bin/niri-session"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "  ${YELLOW}→${NC} $1"; }
ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✘${NC} $1"; }

# -----------------------------------------------------------------------------
# 0. Verificações
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    fail "Execute como root:  sudo bash migrate.sh"
    exit 1
fi

for cmd in curl tar pacman; do
    command -v "$cmd" >/dev/null 2>&1 || {
        fail "Comando '$cmd' não encontrado."
        exit 1
    }
done

echo ""
echo -e "${GREEN}=== Migração para o niri-tearing-bin (pré-compilado) ===${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Identificar o pacote que fornece o /usr/bin/niri atual
# -----------------------------------------------------------------------------
OWNER="$(pacman -Qo "$NIRI_BIN" 2>/dev/null | sed 's/.*pertence a //' || true)"
if [ -z "$OWNER" ]; then
    # pode ser arquivo órfão (não pertencente a nenhum pacote)
    if [ -e "$NIRI_BIN" ]; then
        warn "/usr/bin/niri existe mas não pertence a nenhum pacote (órfão)."
    else
        info "/usr/bin/niri inexistente — será apenas instalado limpo."
    fi
else
    info "Pacote atual que fornece /usr/bin/niri: $OWNER"
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Renomear binários em execução (o processo atual segue até o reboot)
# -----------------------------------------------------------------------------
do_backup() {
    local src="$1"
    if [ -e "$src" ]; then
        local dst="${src}${BACKUP_SUFFIX}"
        if [ ! -e "$dst" ]; then
            mv "$src" "$dst"
            ok "Renomeado '$src' -> '$dst' (será trocado no reboot)"
        else
            warn "Backup já existe para '$src' — pulando."
        fi
    fi
}

do_backup "$NIRI_BIN"
do_backup "$NIRI_SESSION"

echo ""
info "Agora instalando o niri-tearing-bin pré-compilado..."
echo ""

# -----------------------------------------------------------------------------
# 3. Rodar o instalador oficial (baixa o binário, instala updater + hook)
# -----------------------------------------------------------------------------
bash -c "$(curl -fsSL "$INSTALL_RAW")"

echo ""

# -----------------------------------------------------------------------------
# 4. Segurança: verificar se o novo binário ficou no lugar
# -----------------------------------------------------------------------------
if [ -x "$NIRI_BIN" ] && [ ! -L "$NIRI_BIN" ]; then
    ok "/usr/bin/niri agora é o niri-tearing-bin pré-compilado."
else
    warn "/usr/bin/niri pode não ter sido gravado corretamente."
fi

echo ""
echo -e "${YELLOW}═══ Próximos passos (após reiniciar) ═══${NC}"
echo ""
if [ -n "${OWNER:-}" ]; then
    echo "  1) Depois de reiniciar, remova o pacote AUR antigo:"
    echo "       sudo pacman -R --noconfirm $OWNER"
    echo ""
    echo "  2) É normal o gerenciador apontar arquivos órfãos enquanto o"
    echo "     pacote antigo não for removido."
    echo ""
fi
echo "  • O hook do pacman já mantém o niri-tearing-bin atualizado"
echo "    automaticamente a cada 'sudo pacman -Syu'."
echo "  • O backup antigo fica em: ${NIRI_BIN}${BACKUP_SUFFIX}"
echo ""
