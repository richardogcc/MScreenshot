#!/bin/bash
# Builds and (re)installs MScreenshot into /Applications, replacing any
# previous version, then launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build_app.sh
pkill -x MScreenshot 2>/dev/null || true
sleep 0.5
rm -rf /Applications/MScreenshot.app
ditto build/MScreenshot.app /Applications/MScreenshot.app
open /Applications/MScreenshot.app
echo "MScreenshot v$(cat VERSION) instalada en /Applications y en ejecución."
