#!/bin/sh
# Copies the runtime both Forever addons carry (Shared/, at the repository's root) into each
# addon's own Shared/ folder: edit only the root's, then run this. The `lint` test scenario and
# CI check the copies are the same as the root's. Forever Gearbox doesn't carry the settings window
# (Shared/Settings/): it draws its own page in Forever++'s look (ForeverGearbox/Settings/).
#   scripts/sync-shared.sh
set -e
repo=$(cd "$(dirname "$0")/.." && pwd)
for addon in ForeverGearbox ForeverCodex; do
    rm -rf "$repo/$addon/Shared"
    cp -R "$repo/Shared" "$repo/$addon/Shared"
done
rm -rf "$repo/ForeverGearbox/Shared/Settings"
