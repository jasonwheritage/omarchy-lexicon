# Maintainer: Jason Heritage
#
# Packages the native Omarchy overlay plugin (acme.lexicon) and its embedded
# Python search engine modules.

pkgname=omarchy-lexicon
pkgver=1.0.0
pkgrel=1
pkgdesc="Native Omarchy word-finder and dictionary overlay plugin"
arch=('any')
license=('MIT')
depends=('python' 'wl-clipboard' 'words')
source=("git+https://github.com/jasonwheritage/omarchy-lexicon.git")
sha256sums=('SKIP')

package() {
    local plugin_dir="$pkgdir/usr/share/omarchy-lexicon/plugins/acme.lexicon"

    install -Dm644 "$srcdir/omarchy-lexicon/config/default.conf" "$pkgdir/etc/omarchy-lexicon/default.conf"
    install -Dm644 "$srcdir/omarchy-lexicon/README.md" "$pkgdir/usr/share/doc/omarchy-lexicon/README.md"

    install -d "$plugin_dir/i18n"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/manifest.json" "$plugin_dir/manifest.json"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/LexiconOverlay.qml" "$plugin_dir/LexiconOverlay.qml"
    install -Dm755 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/search.py" "$plugin_dir/search.py"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/session.js" "$plugin_dir/session.js"
    install -Dm644 "$srcdir/omarchy-lexicon/plugins/acme.lexicon/i18n/en.json" "$plugin_dir/i18n/en.json"

    for module in "$srcdir"/omarchy-lexicon/src/*.py; do
        install -Dm644 "$module" "$plugin_dir/$(basename "$module")"
    done
}
