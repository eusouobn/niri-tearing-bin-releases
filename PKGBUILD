# Mantenedor: Bruno do Nascimento <eusouobn@gmail.com>
# Pacote pré-compilado a partir da TAG OFICIAL do upstream (urayde/niri).
# Versão alinhada com o release upstream (ex: v26.04 -> pkgver 26.04).
pkgname=niri-tearing-bin
pkgver=26.04
pkgrel=1
pkgdesc="Scrollable-tiling Wayland compositor (tearing fork) - versão binária pré-compilada"
arch=('x86_64')
url="https://github.com/urayde/niri"
license=('GPL-3.0-or-later')
depends=(cairo glib2 libdisplay-info libinput libpipewire libxkbcommon mesa pango pixman seatd)
provides=('niri')
conflicts=('niri' 'niri-git' 'niri-tearing-git' 'niri-tearing-git-bin')

# Binário pré-compilado publicado no GitHub Releases deste repositório
source=("https://github.com/eusouobn/niri-tearing-bin-releases/releases/download/26.04/niri-full-${pkgver}-x86_64.tar.gz")
sha256sums=('06bda636904d6b4a401b89887ca6e62aaa8a46e950117ac1158742d0d0ff6fe5')

package() {
    cd "$srcdir"
    cp -a usr "$pkgdir/"
}
