#!/usr/bin/env bash
# Build a test tarball of the addon, ready to untar inside Interface/AddOns/.
#
# Packages the .toc plus every file the .toc loads, under a PopupAtCursor/
# folder, and names the result from the .toc's "## Version:" line:
#   .release/PopupAtCursor-<version>.tar.gz
#
# Usage: build-tools/make-tarball.sh   (works from any directory)
set -euo pipefail

ADDON=PopupAtCursor
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOC="$ROOT/$ADDON.toc"
OUT="$ROOT/.release"

[[ -f "$TOC" ]] || { echo "error: $TOC not found" >&2; exit 1; }

VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' "$TOC" | tr -d '\r' | head -n1)"
[[ -n "$VERSION" ]] || { echo "error: no '## Version:' line in $TOC" >&2; exit 1; }

# Files the .toc loads: non-blank lines that aren't "#" comments or "##" metadata.
FILES=("$ADDON.toc")
while IFS= read -r line; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
    line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line//\\//}"                      # WoW allows backslash paths
    [[ -f "$ROOT/$line" ]] || { echo "error: $line is listed in the .toc but missing" >&2; exit 1; }
    FILES+=("$line")
done < "$TOC"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$ADDON" "$OUT"
for f in "${FILES[@]}"; do
    mkdir -p "$STAGE/$ADDON/$(dirname "$f")"
    cp "$ROOT/$f" "$STAGE/$ADDON/$f"
done

TARBALL="$OUT/$ADDON-$VERSION.tar.gz"
rm -f "$TARBALL"

# Keep macOS resource forks and extended attributes (._* files) out of the archive.
if tar --version 2>/dev/null | grep -q bsdtar; then
    COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -czf "$TARBALL" -C "$STAGE" "$ADDON"
else
    tar -czf "$TARBALL" -C "$STAGE" "$ADDON"
fi

echo "Built $TARBALL"
tar -tzf "$TARBALL" | sed 's/^/  /'
