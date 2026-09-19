"""Validate public source, installable ZIP and exact CurseForge game compatibility."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def check(tag=None, archive=None):
    manifest = json.loads((ROOT / ".release-manifest.json").read_text())
    expected_tag = manifest["tag"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)[.\d]*)?", expected_tag):
        raise ValueError("Invalid release version")
    if tag and tag != expected_tag:
        raise ValueError("Release tag does not match exported version")
    toc = (ROOT / (manifest["addon"] + ".toc")).read_text()
    if not re.search(r"^## Version:\s*" + re.escape(expected_tag[1:]) + r"\s*$", toc, re.M):
        raise ValueError("TOC version mismatch")
    interface = manifest["interface"]
    if not re.search(r"^## Interface:\s*" + str(interface) + r"\s*$", toc, re.M):
        raise ValueError("Interface mismatch")
    game_version = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"
    if manifest["curseforge"]["gameVersion"] != game_version:
        raise ValueError("CurseForge game version does not match the TOC Interface")
    if not re.search(r"^## X-Curse-Project-ID:\s*" + str(manifest["curseforge"]["projectId"]) + r"\s*$", toc, re.M):
        raise ValueError("CurseForge project ID mismatch")
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    if set(filter(None, tracked)) != set(manifest["files"]) | {".release-manifest.json"}:
        raise ValueError("Unexpected public repository files")
    for name, checksum in manifest["files"].items():
        path = ROOT / name
        if path.is_symlink() or ROOT not in path.resolve().parents:
            raise ValueError("Unsafe public path")
        if hashlib.sha256(path.read_bytes()).hexdigest() != checksum:
            raise ValueError(f"Export checksum mismatch: {name}")
    if archive:
        with zipfile.ZipFile(archive) as z:
            prefix = manifest["addon"] + "/"
            expected = {prefix + name for name in manifest["runtime"]} | {prefix + "CHANGELOG.md"}
            entries = [n for n in z.namelist() if not n.endswith("/")]
            if len(entries) != len(set(entries)) or set(entries) != expected:
                raise ValueError("ZIP contains missing, duplicate or unexpected files")
            for name in expected:
                original = name[len(prefix):]
                if hashlib.sha256(z.read(name)).hexdigest() != manifest["files"][original]:
                    raise ValueError(f"Packaged bytes differ from verified source: {name}")
    print("PASS public source" + (" and ZIP" if archive else ""))
    return manifest


def curseforge_check(manifest):
    token = os.environ.get("CF_API_KEY")
    if not token:
        raise ValueError("CF_API_KEY is not configured")
    request = urllib.request.Request("https://wow.curseforge.com/api/game/wow/versions", headers={"X-Api-Token": token})
    with urllib.request.urlopen(request, timeout=30) as response:
        versions = json.load(response)
    target = manifest["curseforge"]
    matches = [v for v in versions if v["gameVersionTypeID"] == target["gameVersionTypeId"] and v["name"] == target["gameVersion"]]
    if len(matches) != 1:
        raise ValueError("CurseForge has no unique exact game-version match; refusing a fallback version")
    print(f"PASS CurseForge game version {target['gameVersion']} (ID {matches[0]['id']})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--zip", type=Path)
    parser.add_argument("--curseforge-check", action="store_true")
    args = parser.parse_args()
    result = check(args.tag, args.zip)
    if args.curseforge_check:
        curseforge_check(result)
