#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# When the installer is launched with sudo, keep generated build files owned by
# the logged-in developer instead of root. Elevated access is only needed for
# the final copy into /Applications.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    sudo -H -u "$SUDO_USER" "$ROOT_DIR/scripts/build.sh"
else
    "$ROOT_DIR/scripts/build.sh"
fi

DESTINATION="/Applications/ohCapture.app"
ditto "$ROOT_DIR/build/ohCapture.app" "$DESTINATION"
echo "Installed $DESTINATION"
