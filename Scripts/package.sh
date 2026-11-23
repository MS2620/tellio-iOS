#!/usr/bin/env bash
# Builds Tellio and packages it as an unsigned .ipa, ready to install or sideload.
#
#   Scripts/package.sh [debug|release] [output.ipa]
#
# xtool doesn't embed dynamic frameworks that Swift packages build from source (Sentry), so
# the app would close at launch. This copies them in before zipping. Used by run.sh and CI.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-debug}"
output="${2:-Tellio.ipa}"
case "$output" in /*) ;; *) output="$PWD/$output" ;; esac

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

rm -f "$output"
(cd "$staging" && zip -qry "$output" Payload)
echo "Packaged $output"
