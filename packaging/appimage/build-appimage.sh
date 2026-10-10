#!/usr/bin/env bash
# Build vlc-neon-<version>-x86_64.AppImage. Run inside the container from Containerfile:
#   podman build -t vlc-neon-appimage-builder packaging/appimage
#   podman run --rm -v "$PWD:/src:Z" -w /src vlc-neon-appimage-builder packaging/appimage/build-appimage.sh
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=/dev/null
source "$root/UPSTREAM"
work=${APPIMAGE_WORK:-"$root/build/appimage"}
appdir="$work/AppDir"
out=${APPIMAGE_OUT:-"$root/dist"}
tools="$work/tools"
mkdir -p "$tools" "$out"

# Pinned linuxdeploy / Qt plugin / appimagetool releases
fetch() { [[ -s "$tools/$2" ]] || curl -fsSL -o "$tools/$2" "$1"; chmod +x "$tools/$2"; }
fetch https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage linuxdeploy
fetch https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/1-alpha-20250213-1/linuxdeploy-plugin-qt-x86_64.AppImage linuxdeploy-plugin-qt
fetch https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage appimagetool
export APPIMAGE_EXTRACT_AND_RUN=1 PATH="$tools:$PATH"

rm -rf "$appdir"
"$root/scripts/build.sh" --prefix /opt/vlc-neon --destdir "$appdir" --builddir "$work/build" --no-launcher
prefix="$appdir/opt/vlc-neon"
rm -rf "$prefix/include" "$prefix/lib64/pkgconfig"
find "$prefix" -name '*.a' -delete

# Libraries needed by the player, libVLC and every plugin go to usr/lib
deps=(--deploy-deps-only "$prefix/lib64")
while IFS= read -r -d '' so; do deps+=(--deploy-deps-only "$so"); done \
    < <(find "$prefix/lib64/vlc" "$prefix/libexec" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
# Wayland client plugins (shell, EGL integration, decorations) are not picked up automatically
mkdir -p "$appdir/usr/plugins"
for dir in wayland-shell-integration wayland-graphics-integration-client wayland-decoration-client; do
    cp -r "$QTDIR/plugins/$dir" "$appdir/usr/plugins/"
    for so in "$appdir/usr/plugins/$dir"/*.so; do deps+=(--deploy-deps-only "$so"); done
done
export LD_LIBRARY_PATH="$prefix/lib64:$prefix/lib64/vlc${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QMAKE="$QTDIR/bin/qmake"
export QML_SOURCES_PATHS="$work/build/src/modules/gui/qt"
export EXTRA_QT_MODULES="waylandclient;svg"
export EXTRA_PLATFORM_PLUGINS="libqwayland.so"
# Text shaping libraries are on the AppImage exclude list but missing from some minimal installs
bundle=()
for lib in libharfbuzz.so.0 libfribidi.so.0; do
    bundle+=(--library "$(ldconfig -p | awk -v l="$lib" '$1 == l && /x86-64/ {print $NF; exit}')")
done
linuxdeploy --appdir "$appdir" \
    --executable "$prefix/bin/vlc-neon" "${deps[@]}" "${bundle[@]}" \
    --desktop-file "$appdir/usr/share/applications/org.VideoLAN.VLCNeon.desktop" \
    --icon-file "$root/assets/icons/png/vlc-neon-256.png" --icon-filename vlc-neon \
    --plugin qt

# linuxdeploy rewrote the plugins' RPATH: refresh VLC's plugin cache so it is not stale
LD_LIBRARY_PATH="$prefix/lib64:$prefix/lib64/vlc:$appdir/usr/lib" \
    "$prefix/libexec/vlc/vlc-cache-gen" "$prefix/lib64/vlc/plugins"

# libVLC itself stays in its prefix (linuxdeploy copied it while resolving plugin dependencies)
rm -f "$appdir"/usr/lib/libvlc.so* "$appdir"/usr/lib/libvlccore.so*
install -m755 "$root/packaging/appimage/AppRun" "$appdir/AppRun"
rm -rf "$appdir/apprun-hooks"   # AppRun sets the Qt paths itself
printf '[Paths]\nPrefix = ../../../usr\n' > "$prefix/bin/qt.conf"
rm -f "$appdir/AppRun.wrapped"
cp "$root/assets/icons/vlc-neon.svg" "$appdir/vlc-neon.svg"
rm -f "$appdir/.DirIcon"; cp "$root/assets/icons/png/vlc-neon-256.png" "$appdir/.DirIcon"

target="$out/vlc-neon-$NEON_VERSION-x86_64.AppImage"
ARCH=x86_64 VERSION="$NEON_VERSION" appimagetool --no-appstream "$appdir" "$target"
echo "$target"
