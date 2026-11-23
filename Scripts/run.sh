#!/usr/bin/env bash
# Builds Tellio and installs it on the connected iPhone/iPad.
#
# Use this instead of `xtool dev run`: xtool doesn't embed dynamic frameworks that Swift
# packages build from source (Sentry), so the app would close at launch. This copies them in, then installs
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

# Frameworks copied from package checkouts (the player engine's FFmpeg) are read-only,
# and the signer has to rewrite them.
chmod -R u+w "$staging/Payload"

(cd "$staging" && zip -qry Tellio.ipa Payload)
xtool install --usb "$staging/Tellio.ipa"
