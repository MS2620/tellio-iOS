#!/usr/bin/env bash
# Builds Tellio and installs it on the connected iPhone/iPad.
#
# Use this instead of `xtool dev run`: xtool doesn't embed dynamic frameworks from Swift
# packages (Sentry), so the app would close at launch. This copies them in, then installs
# the .ipa with `xtool install`, which provisions and signs it (nested frameworks included).
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-debug}"
xtool dev build --configuration "$configuration"

products=".build/out/Products/$([ "$configuration" = release ] && echo Release || echo Debug)-iphoneos"
app="xtool/Tellio.app"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$staging/Payload"
cp -R "$app" "$staging/Payload/"
mkdir -p "$staging/Payload/Tellio.app/Frameworks"
for framework in Sentry; do
    cp -R "$products/$framework.framework" "$staging/Payload/Tellio.app/Frameworks/"
    # Headers and module maps are only for building against it.
    rm -rf "$staging/Payload/Tellio.app/Frameworks/$framework.framework/"{Headers,PrivateHeaders,Modules}
done

(cd "$staging" && zip -qry Tellio.ipa Payload)
xtool install --usb "$staging/Tellio.ipa"
