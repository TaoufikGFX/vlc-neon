#!/usr/bin/env bash
# Download the pinned upstream VLC source (see ../UPSTREAM) into ./upstream
# Usage: scripts/fetch-upstream.sh [destination]
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
source "$root/UPSTREAM"
dest=${1:-"$root/upstream"}

if [[ -f "$dest/.neon-upstream" && "$(cat "$dest/.neon-upstream")" == "$VLC_COMMIT" ]]; then
    echo "Upstream VLC $VLC_COMMIT already present in $dest"
    exit 0
fi

rm -rf -- "$dest"
mkdir -p -- "$dest"
git -C "$dest" init -q
for url in "$VLC_REPO" "$VLC_MIRROR"; do
    echo "Fetching VLC $VLC_COMMIT from $url"
    if git -C "$dest" fetch -q --depth 1 "$url" "$VLC_COMMIT"; then
        git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD
        [[ "$(git -C "$dest" rev-parse HEAD)" == "$VLC_COMMIT" ]] || { echo "Commit mismatch" >&2; exit 1; }
        rm -rf -- "$dest/.git"
        echo "$VLC_COMMIT" > "$dest/.neon-upstream"
        echo "Upstream VLC ready in $dest"
        exit 0
    fi
done
echo "Could not fetch VLC $VLC_COMMIT" >&2
exit 1
