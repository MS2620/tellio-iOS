#!/usr/bin/env python3
"""Writes Tellio's AltStore-format source, which SideStore, AltStore and LiveContainer read on
iPhone and iPad (and, for the Apple TV app, tvOS sideloaders such as ATVLoadly and FlareStore).

    altstore-source.py ios|tvos IPA TAG NOTES.md PREVIOUS.json OUT.json

IPA is the build just published as the release TAG; its version, build number, bundle ID and
minimum OS are read from its Info.plist, so the source always says what's inside the file
(AltStore refuses an IPA whose version isn't the one it was told). NOTES.md is the release's
notes. PREVIOUS.json is the source as it was (it needn't exist): its versions are kept, newest
first, up to KEEP of them. The workflow publishes OUT on the altstore branch.
"""

import hashlib
import json
import os
import plistlib
import re
import sys
import zipfile
from datetime import datetime, timezone

KEEP = 10
TINT = "6E5BFF"
ICON = "https://raw.githubusercontent.com/MS2620/tellio-iOS/master/Resources/AppIcon.png"

PLATFORMS = {
    "ios": {
        "repo": "MS2620/tellio-iOS",
        "source": "Tellio for iPhone and iPad",
        "identifier": "io.github.ms2620.tellio-ios",
        "subtitle": "A free player for your own addons and IPTV account.",
        "description": (
            "Tellio plays what you bring: your IPTV provider's login or M3U playlist for live TV, "
            "and your addons for films and series. On top of that it adds artwork, a proper TV "
            "guide, sports with live scores, multiview, reminders, Trakt sync and more.\n\n"
            "Tellio doesn't include any channels, films or streams. It only plays what your own "
            "IPTV account and addons provide."
        ),
        "entitlements": [],
    },
    "tvos": {
        "repo": "MS2620/tellio",
        "source": "Tellio for Apple TV",
        "identifier": "io.github.ms2620.tellio",
        "subtitle": "A free player for your own addons and IPTV account.",
        "description": (
            "Tellio plays what you bring: your IPTV provider's login or M3U playlist for live TV, "
            "and your addons for films and series. On top of that it adds artwork, a proper TV "
            "guide, sports with live scores, Top Shelf, Trakt sync and more.\n\n"
            "Tellio doesn't include any channels, films or streams. It only plays what your own "
            "IPTV account and addons provide."
        ),
        # Top Shelf reads what's on from the app through this App Group.
        "entitlements": ["com.apple.security.application-groups"],
    },
}


def info_plist(ipa):
    with zipfile.ZipFile(ipa) as archive:
        name = next(n for n in archive.namelist()
                    if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n))
        return plistlib.loads(archive.read(name))


def plain(notes):
    """Release notes as AltStore shows them: plain text without Markdown's marks."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", notes)
    text = re.sub(r"^#+\s*", "", text, flags=re.M)
    text = text.replace("**", "").replace("`", "")
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main():
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    platform, ipa, tag, notes_path, previous_path, out = sys.argv[1:]
    config = PLATFORMS[platform]
    repo = config["repo"]

    info = info_plist(ipa)
    data = open(ipa, "rb").read()
    with open(notes_path, encoding="utf-8") as f:
        notes = plain(f.read())

    entry = {
        "version": info["CFBundleShortVersionString"],
        "buildVersion": info["CFBundleVersion"],
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": notes,
        "downloadURL": f"https://github.com/{repo}/releases/download/{tag}/{os.path.basename(ipa)}",
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "minOSVersion": info.get("MinimumOSVersion", "18.0"),
    }

    older = []
    if os.path.exists(previous_path):
        try:
            with open(previous_path, encoding="utf-8") as f:
                older = json.load(f)["apps"][0]["versions"]
        except (ValueError, KeyError, IndexError):
            older = []
    # A rerun of the same build replaces its entry instead of listing it twice.
    versions = [entry] + [v for v in older if v.get("version") != entry["version"]]

    source = {
        "name": config["source"],
        "identifier": config["identifier"],
        "subtitle": config["subtitle"],
        "website": f"https://github.com/{repo}",
        "iconURL": ICON,
        "tintColor": TINT,
        "apps": [
            {
                "name": "Tellio",
                "bundleIdentifier": info["CFBundleIdentifier"],
                "developerName": "MS2620",
                "subtitle": config["subtitle"],
                "localizedDescription": config["description"],
                "iconURL": ICON,
                "tintColor": TINT,
                "category": "entertainment",
                "screenshots": [],
                "versions": versions[:KEEP],
                "appPermissions": {"entitlements": config["entitlements"], "privacy": {}},
            }
        ],
        "news": [],
    }
    with open(out, "w", encoding="utf-8") as f:
        json.dump(source, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"{out}: {entry['version']} ({entry['buildVersion']}), {len(source['apps'][0]['versions'])} versions listed")


if __name__ == "__main__":
    main()
