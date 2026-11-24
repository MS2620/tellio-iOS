#!/usr/bin/env python3
"""Turns String Catalogs into the .lproj files an app reads its text from.

    Scripts/localize.py OUTPUT_DIR CATALOG [CATALOG ...]

xtool builds on Linux, where Xcode's String Catalog compiler (xcstringstool) can't run, so
this does its job: for each language it writes <lang>.lproj/Localizable.strings (plain text)
and Localizable.stringsdict (plural forms). Later catalogs win, so the iOS catalog
(Resources/Localizable.xcstrings) can change or add to the Apple TV app's shared one.
package.sh copies the result into Tellio.app, where String(localized:) and Text look.
"""
import json
import os
import plistlib
import re
import sys

SPECIFIER = re.compile(r"%(?:\d+\$)?([-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDuUxXoOfeEgGcCsSpaAF])")


def escape(text):
    return (text.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\t", "\\t"))


def first_specifier(key):
    match = SPECIFIER.search(key)
    return match.group(1) if match else "lld"


def plural_forms(variations, arg=None):
    """{"one": "...", "other": "..."} from a catalog's plural variations.
    In a substitution, %arg stands for the substituted number."""
    forms = {}
    for form, value in variations.get("plural", {}).items():
        text = value.get("stringUnit", {}).get("value")
        if text is None:
            continue
        if arg is not None:
            text = text.replace("%arg", arg)
        forms[form] = text
    return forms


def entry(key, localization):
    """("strings", text) or ("stringsdict", dict), or None for nothing usable."""
    unit = localization.get("stringUnit", {}).get("value")
    subs = localization.get("substitutions")
    variations = localization.get("variations")

    if subs and unit is not None:
        result = {"NSStringLocalizedFormatKey": unit}
        for name, sub in subs.items():
            spec = sub.get("formatSpecifier", "lld")
            arg = "%{}${}".format(sub.get("argNum", 1), spec)
            forms = plural_forms(sub.get("variations", {}), arg)
            if not forms:
                continue
            result[name] = {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                            "NSStringFormatValueTypeKey": spec, **forms}
        return ("stringsdict", result)

    if variations and "plural" in variations:
        forms = plural_forms(variations)
        if forms:
            return ("stringsdict", {
                "NSStringLocalizedFormatKey": "%#@value@",
                "value": {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                          "NSStringFormatValueTypeKey": first_specifier(key), **forms},
            })

    if unit is not None:
        return ("strings", unit)
    return None


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    output, catalogs = sys.argv[1], sys.argv[2:]

    # language → key → entry; later catalogs replace earlier ones key by key.
    languages = {}
    for path in catalogs:
        with open(path, encoding="utf-8") as f:
            catalog = json.load(f)
        source = catalog.get("sourceLanguage", "en")
        languages.setdefault(source, {})
        for key, item in catalog.get("strings", {}).items():
            if item.get("shouldTranslate") is False:
                continue
            for language, localization in item.get("localizations", {}).items():
                made = entry(key, localization)
                if made is not None:
                    languages.setdefault(language, {})[key] = made

    for language, entries in sorted(languages.items()):
        folder = os.path.join(output, language + ".lproj")
        os.makedirs(folder, exist_ok=True)
        strings = {k: v for k, (kind, v) in entries.items() if kind == "strings"}
        plurals = {k: v for k, (kind, v) in entries.items() if kind == "stringsdict"}
        with open(os.path.join(folder, "Localizable.strings"), "w", encoding="utf-8") as f:
            for key in sorted(strings):
                f.write('"{}" = "{}";\n'.format(escape(key), escape(strings[key])))
        with open(os.path.join(folder, "Localizable.stringsdict"), "wb") as f:
            plistlib.dump(plurals, f, sort_keys=True)
        with open(os.path.join(folder, "InfoPlist.strings"), "w", encoding="utf-8") as f:
            f.write('"CFBundleDisplayName" = "Tellio";\n')
        print("{}: {} strings, {} with plurals".format(language, len(strings), len(plurals)))


if __name__ == "__main__":
    main()
