#!/usr/bin/env bash
# VLC Neon package smoke test, run inside a clean container (see tests/README.md).
#   tests/smoke-test.sh <launch command> <media file> <output dir>
# Checks: version, plugin inventory, audio + video decoding, and the Qt interface with the
# built-in Neon integration test (seek previews, seeking, speed, repeat, A-B...) under Xvfb.
set -uo pipefail
cmd=$1 media=$2 out=$3
mkdir -p "$out"
# VLC refuses to run as root: containers run the test as "nobody"
if [[ $EUID -eq 0 ]]; then
    chmod 777 "$out"
    exec setpriv --reuid=65534 --regid=65534 --clear-groups "$0" "$@"
fi
export HOME="$out/home" XDG_CONFIG_HOME="$out/home/.config" XDG_CACHE_HOME="$out/home/.cache" XDG_DATA_HOME="$out/home/.local/share"
export XDG_RUNTIME_DIR="$out/runtime"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
pass=0 fail=0
check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

$cmd --version > "$out/version.txt" 2>&1
check "starts and reports its version" "grep -q 'VLC version 4' '$out/version.txt'"

$cmd --list > "$out/plugins.txt" 2>/dev/null
echo "      $(grep -c '^ *[a-z0-9_]* ' "$out/plugins.txt") modules"
for m in qt avcodec avformat mp4 mkv es ogg vpx opus faad mpg123 gl egl_x11 xcb_window pulse alsa freetype; do
    grep -qE "^ +$m +" "$out/plugins.txt" && echo "      module $m" || echo "      (no module $m)"
done
check "Qt interface plugin loads" "grep -qE '^ +qt +' '$out/plugins.txt'"
check "FFmpeg decoder plugin loads" "grep -qE '^ +avcodec +' '$out/plugins.txt'"
check "an audio output plugin loads" "grep -qE '^ +(pulse|alsa|pipewire) +' '$out/plugins.txt'"
check "a video output plugin loads" "grep -qE '^ +(gl|xcb_x11|egl_x11|wl_shm) +' '$out/plugins.txt'"

timeout 60 $cmd -I dummy --no-video --aout=afile --audiofile-file="$out/audio.wav" --stop-time=4 --play-and-exit "$media" > "$out/audio.log" 2>&1
check "decodes audio (4 s to WAV)" "[[ \$(stat -c %s '$out/audio.wav' 2>/dev/null || echo 0) -gt 300000 ]]"

timeout 60 $cmd -I dummy --no-audio --vout=yuv --yuv-file="$out/video.y4m" --yuv-yuv4mpeg2 --stop-time=2 --play-and-exit "$media" > "$out/video.log" 2>&1
check "decodes video (2 s to Y4M)" "[[ \$(stat -c %s '$out/video.y4m' 2>/dev/null || echo 0) -gt 10000000 ]]"

# Qt interface + Neon integration test in a virtual X server (software OpenGL)
Xvfb :77 -screen 0 1600x1000x24 -nolisten tcp > "$out/xvfb.log" 2>&1 &
xvfb=$!
sleep 2
DISPLAY=:77 QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1 VLC_REBORN_TEST_REPORT="$out/neon-report.json" \
    timeout 120 $cmd --no-qt-privacy-ask --aout=dummy --snapshot-path="$out" "$media" > "$out/gui.log" 2>&1 &
gui=$!
sleep 12
DISPLAY=:77 import -window root "$out/gui-screenshot.png" 2>/dev/null
wait $gui
kill $xvfb 2>/dev/null
check "Qt interface shows video" "grep -q '\"video_output\": *true' '$out/neon-report.json' 2>/dev/null"
if [[ -f "$out/neon-report.json" ]]; then
    python3 - "$out/neon-report.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
for k in ("application_display_name", "desktop_file_name", "window_title"):
    print(f"      {k}: {r.get(k)}")
flat = dict(r, **{f"playback.{k}": v for k, v in r.get("playback", {}).items()})
for k, v in sorted(flat.items()):
    if isinstance(v, bool):
        print(f"      {'ok ' if v else 'BAD'} {k}")
PY
    check "Neon feature checks all true" "! python3 -c \"import json,sys;r=json.load(open('$out/neon-report.json'));v=list(r.values())+list(r.get('playback',{}).values());sys.exit(0 if any(x is False for x in v) or r.get('timeout') else 1)\""
fi
echo "Result: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
