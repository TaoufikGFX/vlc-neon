#!/usr/bin/env bash
# GPL "complete corresponding source": pinned upstream VLC + patches + build/packaging scripts
#   scripts/make-source-tarball.sh [output-dir]  ->  vlc-neon-<version>-source.tar.gz
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
source "$root/UPSTREAM"
out=$(mkdir -p "${1:-$root/dist}" && cd "${1:-$root/dist}" && pwd)
name="vlc-neon-$NEON_VERSION"
"$root/scripts/fetch-upstream.sh" "$root/upstream"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/$name"
# Repository files (tracked files only when this is a git checkout)
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$root" ls-files -z | (cd "$root" && xargs -0 cp --parents -t "$stage/$name")
else
    (cd "$root" && tar --exclude=./upstream --exclude=./build --exclude=./dist --exclude=./.git -cf - .) | tar -xf - -C "$stage/$name"
fi
rm -rf "$stage/$name/docs" "$stage/$name/assets/screenshots"   # website and screenshots are not source
cp -a "$root/upstream" "$stage/$name/upstream"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@0" \
    -C "$stage" -czf "$out/$name-source.tar.gz" "$name"
echo "$out/$name-source.tar.gz"
