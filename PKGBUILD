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
depends=('python' 'wl-clipboard' 'words')
source=("git+https://github.com/jasonwheritage/omarchy-lexicon.git")
sha256sums=('SKIP')

package() {
    # The repo is checked out under $srcdir/omarchy-lexicon during makepkg.
    install -Dm755 "$srcdir/omarchy-lexicon/bin/omarchy-lexicon" "$pkgdir/usr/bin/omarchy-lexicon"
    for module in "$srcdir"/omarchy-lexicon/src/*.py; do
        install -Dm644 "$module" "$pkgdir/usr/lib/omarchy-lexicon/$(basename "$module")"
    done
    install -Dm644 "$srcdir/omarchy-lexicon/config/default.conf" "$pkgdir/etc/omarchy-lexicon/default.conf"
    install -Dm644 "$srcdir/omarchy-lexicon/README.md" "$pkgdir/usr/share/doc/omarchy-lexicon/README.md"

    install -d "$pkgdir/usr/share/omarchy-lexicon/plugins/acme.lexicon"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/manifest.json" \
        "$pkgdir/usr/share/omarchy-lexicon/plugins/acme.lexicon/manifest.json"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/LexiconOverlay.qml" \
        "$pkgdir/usr/share/omarchy-lexicon/plugins/acme.lexicon/LexiconOverlay.qml"
    install -Dm755 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/search.py" \
        "$pkgdir/usr/share/omarchy-lexicon/plugins/acme.lexicon/search.py"
}
