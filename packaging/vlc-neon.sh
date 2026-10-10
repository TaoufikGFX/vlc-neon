#!/usr/bin/env bash
# VLC Neon launcher: runs the private VLC 4 build in @PREFIX@ with its own plugins
set -euo pipefail
prefix=${VLC_NEON_PREFIX:-@PREFIX@}
export VLC_PLUGIN_PATH="$prefix/lib64/vlc/plugins"
export VLC_LIB_PATH="$prefix/lib64/vlc"
export VLC_LIBEXEC_PATH="$prefix/libexec/vlc"
export VLC_DATA_PATH="$prefix/share/vlc"
export LD_LIBRARY_PATH="$prefix/lib64:$prefix/lib64/vlc${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# On hybrid AMD/Intel + NVIDIA Wayland laptops, keep automatic EGL probing on the
# integrated Mesa GPU (enumerating an idle NVIDIA driver can stall start-up).
# Explicit GPU/vendor selections in the environment always win.
if [[ -n "${WAYLAND_DISPLAY:-}" && -z "${__EGL_VENDOR_LIBRARY_FILENAMES+x}" \
      && -z "${__EGL_VENDOR_LIBRARY_DIRS+x}" && -z "${DRI_PRIME:-}" \
      && "${__NV_PRIME_RENDER_OFFLOAD:-0}" != 1 \
      && "${__GLX_VENDOR_LIBRARY_NAME:-}" != nvidia \
      && -r /usr/share/glvnd/egl_vendor.d/50_mesa.json ]]; then
    has_nvidia=false
    has_integrated=false
    for vendor_file in /sys/class/drm/card*/device/vendor; do
        [[ -r "$vendor_file" ]] || continue
        read -r vendor < "$vendor_file"
        case "$vendor" in
            0x10de) has_nvidia=true ;;
            0x1002|0x8086) has_integrated=true ;;
        esac
    done
    if $has_nvidia && $has_integrated; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
    fi
fi
exec "$prefix/bin/vlc-neon" "$@"
