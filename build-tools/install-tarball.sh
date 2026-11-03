#!/usr/bin/env bash
# Install a PopupAtCursor test tarball into a WoW AddOns folder.
#
# Usage: build-tools/install-tarball.sh [-t TARBALL] [ADDONS_DIR]
#
#   ADDONS_DIR   AddOns folder to install into. Defaults to $WOW_ADDONS, or
#                /Applications/World of Warcraft/_retail_/Interface/AddOns
#   -t TARBALL   Tarball to install as-is. Without -t, the tarball for the
#                .toc's current version is rebuilt first, so it's never stale.
#
# Any existing PopupAtCursor folder in ADDONS_DIR is replaced, so files removed
# from the addon don't linger. Restart the game after installing if the .toc
# changed; /reload is enough for Lua-only changes.
set -euo pipefail

ADDON=PopupAtCursor
DEFAULT_ADDONS="/Applications/World of Warcraft/_retail_/Interface/AddOns"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p;}' "${BASH_SOURCE[0]}"; }

TARBALL=""
while getopts ":t:h" opt; do
    case "$opt" in
        t) TARBALL="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "error: -$OPTARG needs a value" >&2; exit 2 ;;
        *) echo "error: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -le 1 ]] || { echo "error: too many arguments" >&2; usage >&2; exit 2; }

DEST="${1:-${WOW_ADDONS:-$DEFAULT_ADDONS}}"
DEST="${DEST%/}"
[[ -d "$DEST" ]] || { echo "error: AddOns folder not found: $DEST" >&2; exit 1; }

if [[ -z "$TARBALL" ]]; then
    VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' "$ROOT/$ADDON.toc" | tr -d '\r' | head -n1)"
    [[ -n "$VERSION" ]] || { echo "error: no '## Version:' line in $ADDON.toc" >&2; exit 1; }
    TARBALL="$ROOT/.release/$ADDON-$VERSION.tar.gz"
    "$ROOT/build-tools/make-tarball.sh"
fi
[[ -f "$TARBALL" ]] || { echo "error: tarball not found: $TARBALL" >&2; exit 1; }

# Only accept archives whose every entry lives under PopupAtCursor/.
if tar -tzf "$TARBALL" | grep -v -e "^$ADDON/" -e "^$ADDON\$" -e '^$' | grep -q .; then
    echo "error: $TARBALL contains files outside $ADDON/; refusing to install" >&2
    exit 1
fi

# Extract next to the destination, then swap it in.
STAGE="$(mktemp -d "$DEST/.$ADDON-install.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
tar -xzf "$TARBALL" -C "$STAGE"
[[ -f "$STAGE/$ADDON/$ADDON.toc" ]] || { echo "error: $TARBALL has no $ADDON/$ADDON.toc" >&2; exit 1; }

rm -rf "${DEST:?}/$ADDON"
mv "$STAGE/$ADDON" "$DEST/$ADDON"

echo "Installed $(basename "$TARBALL") into $DEST/$ADDON"
