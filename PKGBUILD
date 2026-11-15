# Maintainer: Your Name <you@example.com>
#
# Milestone packaging note:
# This PKGBUILD installs the current CLI-first prototype as a system command,
# while keeping the source layout compatible with a future upstream release.
# The binary entry point remains /usr/bin/omarchy-lexicon even before a native
# Omarchy plugin or QML overlay is introduced.

pkgname=omarchy-lexicon
pkgver=0.1.0
pkgrel=1
pkgdesc="Offline word finder and dictionary utility for word games"
arch=('any')
license=('MIT')
depends=('python' 'wl-clipboard')
source=("git+https://github.com/jasonwheritage/omarchy-lexicon.git")
sha256sums=('SKIP')

package() {
    # The repo is checked out under $srcdir/omarchy-lexicon during makepkg.
    # These install commands make the prototype usable as a real system binary.
    install -Dm755 "$srcdir/omarchy-lexicon/bin/omarchy-lexicon" "$pkgdir/usr/bin/omarchy-lexicon"
    install -Dm755 "$srcdir/omarchy-lexicon/bin/omarchy-lexicon-walker" "$pkgdir/usr/bin/omarchy-lexicon-walker"
    for module in "$srcdir"/omarchy-lexicon/src/*.py; do
        install -Dm644 "$module" "$pkgdir/usr/lib/omarchy-lexicon/$(basename "$module")"
    done
    install -Dm644 "$srcdir/omarchy-lexicon/config/default.conf" "$pkgdir/etc/omarchy-lexicon/default.conf"
    install -Dm644 "$srcdir/omarchy-lexicon/config/keybinds.conf" "$pkgdir/etc/omarchy-lexicon/keybinds.conf"
    install -Dm644 "$srcdir/omarchy-lexicon/README.md" "$pkgdir/usr/share/doc/omarchy-lexicon/README.md"
}
