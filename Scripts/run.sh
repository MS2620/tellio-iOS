#!/usr/bin/env bash
# Builds Tellio and installs it on the connected iPhone/iPad (unlocked, over USB).
#
#   Scripts/run.sh [debug|release]
#
# Use this instead of `xtool dev run`, which would leave out the Sentry framework (see
# package.sh). `xtool install` provisions and signs the app, nested frameworks included.
set -euo pipefail
cd "$(dirname "$0")/.."

ipa="$(mktemp -d)/Tellio.ipa"
trap 'rm -rf "$(dirname "$ipa")"' EXIT

Scripts/package.sh "${1:-debug}" "$ipa"
xtool install --usb "$ipa"
