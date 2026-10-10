#!/usr/bin/env bash
# Build VLC Neon: pinned upstream VLC + patches/ -> install tree
#
#   scripts/build.sh [--prefix /opt/vlc-neon] [--destdir DIR] [--builddir DIR] [--jobs N] [--no-launcher]
#
# Installs the player under PREFIX (default /opt/vlc-neon) inside DESTDIR (default ./dist/root),
# plus the launcher, desktop entry, icons and AppStream metadata under /usr.
# --no-launcher skips /usr/bin/vlc-neon (the AppImage uses its own AppRun).
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
source "$root/UPSTREAM"

prefix=/opt/vlc-neon
destdir="$root/dist/root"
builddir="$root/build"
jobs=$(nproc)
launcher=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)   prefix=$2; shift 2 ;;
        --destdir)  destdir=$2; shift 2 ;;
        --builddir) builddir=$2; shift 2 ;;
        --jobs)     jobs=$2; shift 2 ;;
        --no-launcher) launcher=false; shift ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

upstream="$root/upstream"
[[ -f "$upstream/.neon-upstream" ]] || "$root/scripts/fetch-upstream.sh" "$upstream"

# Fresh source tree: upstream + patches
src="$builddir/src"
if [[ ! -f "$src/.neon-patched" ]]; then
    rm -rf -- "$src"
    mkdir -p -- "$builddir"
    cp -a -- "$upstream" "$src"
    for patch in "$root"/patches/*.patch; do
        echo "Applying $(basename -- "$patch")"
        # The ceiling keeps git from treating an enclosing checkout as the patch root
        (cd "$src" && GIT_CEILING_DIRECTORIES="$builddir" git apply -p1 --whitespace=nowarn "$patch")
    done
    touch "$src/.neon-patched"
fi

# Same feature set as the tested build: optional network discovery/cast and skins2 off
if [[ ! -f "$builddir/meson/build.ninja" ]]; then
    meson setup "$builddir/meson" "$src" \
        --prefix="$prefix" --libdir=lib64 --buildtype=release \
        -Dqt=enabled -Dwayland=enabled -Dtests=disabled -Dqt_gtk=disabled \
        -Dskins2=disabled -Dchromecast=disabled -Drust=disabled -Dnls=disabled \
        -Dmedialibrary=disabled -Dmicrodns=disabled -Davahi=disabled -Dupnp=disabled
fi
meson compile -C "$builddir/meson" -j "$jobs"
DESTDIR="$destdir" meson install -C "$builddir/meson" --quiet

# Plugin cache (speeds up start-up)
LD_LIBRARY_PATH="$destdir$prefix/lib64:$destdir$prefix/lib64/vlc" \
    "$destdir$prefix/libexec/vlc/vlc-cache-gen" "$destdir$prefix/lib64/vlc/plugins"

# Desktop integration
pkg="$root/packaging"
if $launcher; then
    install -Dm755 /dev/stdin "$destdir/usr/bin/vlc-neon" < <(sed "s|@PREFIX@|$prefix|g" "$pkg/vlc-neon.sh")
fi
install -Dm644 "$pkg/vlc-neon.desktop" "$destdir/usr/share/applications/org.VideoLAN.VLCNeon.desktop"
install -Dm644 "$pkg/org.VideoLAN.VLCNeon.metainfo.xml" "$destdir/usr/share/metainfo/org.VideoLAN.VLCNeon.metainfo.xml"
install -Dm644 "$root/assets/icons/vlc-neon.svg" "$destdir/usr/share/icons/hicolor/scalable/apps/vlc-neon.svg"
for size in 16 22 24 32 48 64 128 256 512; do
    install -Dm644 "$root/assets/icons/png/vlc-neon-$size.png" "$destdir/usr/share/icons/hicolor/${size}x${size}/apps/vlc-neon.png"
done
# Optional KWin script for Picture-in-Picture placement on KDE Plasma (Wayland)
mkdir -p "$destdir/usr/share/kwin/scripts"
cp -r "$pkg/kde/vlc-neon-pip" "$destdir/usr/share/kwin/scripts/"
echo "VLC Neon installed into $destdir (prefix $prefix)"
