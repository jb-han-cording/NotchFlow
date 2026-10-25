#!/usr/bin/env python3
"""Validate the latest appcast entry against the built app and signed DMG."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
app = root / "build/Build/Products/Release/NotchFlow.app"
with (app / "Contents/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
with (root / "Resources/Info.plist").open("rb") as stream:
    source = plistlib.load(stream)
feed = ET.parse(root / "appcast.xml").getroot().find("channel/item")
manifest = json.loads((root / "update.json").read_text())
version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
assert source["CFBundleShortVersionString"] == version
assert source["CFBundleVersion"] == build
assert feed.findtext(sparkle + "version") == build
assert feed.findtext(sparkle + "shortVersionString") == version
assert manifest["version"] == version and str(manifest["build"]) == build
dmg = root / "dist" / f"NotchFlow-{version}.dmg"
enclosure = feed.find("enclosure")
url = f"https://raw.githubusercontent.com/jb-han-cording/NotchFlow/main/dist/{dmg.name}"
assert enclosure.attrib["url"] == manifest["dmgURL"] == url
assert int(enclosure.attrib["length"]) == dmg.stat().st_size
assert hashlib.sha256(dmg.read_bytes()).hexdigest() == manifest["sha256"]
bin_dir = root / "build/SourcePackages/artifacts/sparkle/Sparkle/bin"
public_key = subprocess.check_output(
    [str(bin_dir / "generate_keys"), "--account", "notchflow", "-p"], text=True
).strip()
assert public_key == info["SUPublicEDKey"] == source["SUPublicEDKey"]
subprocess.run([str(bin_dir / "sign_update"), "--account", "notchflow",
                "--verify", str(dmg), enclosure.attrib[sparkle + "edSignature"]], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
print(f"Verified {version} (build {build}): metadata, SHA-256, EdDSA and app code signature.")
