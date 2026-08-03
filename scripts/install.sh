#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT_DIR/scripts/build.sh"

DESTINATION="/Applications/ohCapture.app"
ditto "$ROOT_DIR/build/ohCapture.app" "$DESTINATION"
echo "Installed $DESTINATION"

