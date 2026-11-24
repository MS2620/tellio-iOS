#!/usr/bin/env bash
# Fills the built-in keys in Config/Info.plist from environment variables, for CI.
# Run before `xtool dev build`; GitHub Actions passes the values from repository secrets:
#   TRAKT_CLIENT_ID, TMDB_TOKEN (already scrambled), SENTRY_DSN, FEEDBACK_URL, LIBRARY_VERSIONS
# and BUILD_NUMBER (the build number shown in Settings › About, which also becomes the last
# part of the version).
# Unset variables leave the key empty. Never commit the filled plist.
set -euo pipefail

plist="${1:-Config/Info.plist}"

python3 - "$plist" <<'PY'
import os, plistlib, sys

path = sys.argv[1]
keys = {
    "TraktClientID": "TRAKT_CLIENT_ID",
    "TMDBToken": "TMDB_TOKEN",
    "SentryDSN": "SENTRY_DSN",
    "FeedbackURL": "FEEDBACK_URL",
    "LibraryVersions": "LIBRARY_VERSIONS",
}
with open(path, "rb") as f:
    info = plistlib.load(f)
for key, env in keys.items():
    info[key] = os.environ.get(env, "")
if os.environ.get("BUILD_NUMBER"):
    build = os.environ["BUILD_NUMBER"]
    info["CFBundleVersion"] = build
    # The version ends in the build number (0.1.0 becomes 0.1.12), so SideStore and AltStore,
    # which look for updates by version, see each build as newer. Change "0.1" in Info.plist.
    major_minor = ".".join(info.get("CFBundleShortVersionString", "0.1.0").split(".")[:2])
    info["CFBundleShortVersionString"] = major_minor + "." + build
with open(path, "wb") as f:
    plistlib.dump(info, f)
print("Filled", ", ".join(k for k, e in keys.items() if os.environ.get(e)) or "nothing (no secrets set)")
PY
