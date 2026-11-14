#!/bin/sh
# Links each Forever addon folder into the game's AddOns folder, so /reload picks up edits
# (a new file needs a game restart). Replaces an old link of the same name (the pre-suite
# ForeverTweaks and ForeverCompendium repos); refuses to touch a real folder.
#   scripts/link.sh "/path/to/World of Warcraft/_retail_/Interface/AddOns"
set -e
addons=${1:?usage: scripts/link.sh <Interface/AddOns folder>}
repo=$(cd "$(dirname "$0")/.." && pwd)
for addon in ForeverCore ForeverTweaks ForeverCompendium; do
    target="$addons/$addon"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "$target is a real folder, not a link: move it away first." >&2
        exit 1
    fi
    ln -sfn "$repo/$addon" "$target"
    echo "$target -> $repo/$addon"
done
