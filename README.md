# niri-tearing-bin-releases

Scripts de empacotamento e releases de binários pré-compilados para o **niri** (scrollable-tiling Wayland compositor) a partir do fork com *tearing* do [urayde/niri](https://github.com/urayde/niri).

- Aplicativo upstream (fork): <https://github.com/urayde/niri>
- Aplicativo original: <https://github.com/YaLTeR/niri>
- Downloads (Releases): [Releases deste repositório](https://github.com/eusouobn/niri-tearing-bin-releases/releases)

> **Nota:** o pacote viveu originalmente no AUR como `niri-tearing-git-bin`, mas foi removido. A manutenção passou a ser feita aqui, com os binários publicados como **GitHub Releases**.

## Conteúdo

- `PKGBUILD` — receita de empacotamento (formato AUR/makepkg).
- `update-niri-bin.sh` — compila o upstream (tag oficial), publica o `.tar.gz` no GitHub Releases e atualiza o `PKGBUILD` automaticamente.
- `niri-tearing-bin-update.sh` — script de atualização instalado em `/usr/local/bin/`: baixa do GitHub, compara com a versão instalada e extrai sobre `/`.
- `90-niri-tearing-bin.hook` — hook do pacman que roda o updater a cada `pacman -Syu`, mantendo o binário sempre atualizado **sem depender do AUR**.
- `LICENSE` — licença do código de empacotamento (MIT).

## Atualização automática (hook do pacman)

O binário é atualizado automaticamente a cada `sudo pacman -Syu`:

1. `update-niri-bin.sh` publica `niri-full-<ver>-x86_64.tar.gz` como **GitHub Release**.
2. O script `niri-tearing-bin-update.sh` consulta a última versão no GitHub, compara com a versão instalada (em `/usr/share/niri-tearing-bin/version`) e, se houver nova, baixa e extrai o tarball sobre `/`.
3. O hook `/etc/pacman.d/hooks/90-niri-tearing-bin.hook` executa esse script após toda transação do pacman.

### Instalação manual (rápida)

```bash
# 1) Extrair o binário sobre / (root)
sudo curl -fL -O https://github.com/eusouobn/niri-tearing-bin-releases/releases/download/26.04/niri-full-26.04-x86_64.tar.gz
sudo tar -xzf niri-full-26.04-x86_64.tar.gz -C /

# 2) Instalar o updater + hook (atualização automática)
sudo install -m 755 niri-tearing-bin-update.sh /usr/local/bin/niri-tearing-bin-update.sh
sudo install -m 644 90-niri-tearing-bin.hook /etc/pacman.d/hooks/
```

O hook roda como root a cada transação do pacman e cuida das atualizações futuras.

## Créditos

Este repositório é apenas de **empacotamento** e **distribuição** de binários. Todo o crédito pelo aplicativo vai para os autores originais:

- **niri** — o compositor Wayland foi criado por [YaLTeR](https://github.com/YaLTeR/niri).
- **fork com tearing** — mantido por [urayde](https://github.com/urayde/niri), usado como base deste pacote.

## Uso

Compilar e criar o pacote localmente:

```bash
makepkg -si
```

Atualizar automaticamente para a versão mais recente do upstream:

```bash
./update-niri-bin.sh
```

## Licenças

O código de empacotamento (`PKGBUILD`, `update-*.sh`) é de Bruno do Nascimento, licenciado sob **MIT** (veja [`LICENSE`](LICENSE)).

Aplicativo empacotado:
- [niri](https://github.com/YaLTeR/niri) ([fork urayde/niri](https://github.com/urayde/niri)) é licenciado sob **GPL-3.0-or-later**.

### Redistribuição dos binários (GPL-3.0)

Os binários pré-compilados publicados nos **Releases** deste repositório são derivados do código-fonte **GPL-3.0-or-later**. Ao usar/redistribuir esses binários, os termos da GPL-3.0 se aplicam, incluindo:

- Manutenção do aviso de licença e copyright do upstream.
- Disponibilização do código-fonte correspondente.

O código-fonte correspondente está disponível no upstream:

- <https://github.com/urayde/niri> (fork com tearing, usado neste pacote)
- <https://github.com/YaLTeR/niri> (niri original)

O texto completo da GPL-3.0 está disponível em <https://www.gnu.org/licenses/gpl-3.0.html>.
