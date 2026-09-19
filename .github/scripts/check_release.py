"""Validate public source, installable ZIP and exact CurseForge game compatibility."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def release_notes(manifest):
    heading = "## " + manifest["flavor"].title() + " " + manifest["tag"].split("-v", 1)[1]
    lines = (ROOT / "CHANGELOG.md").read_text().splitlines()
    try:
        start = lines.index(heading) + 1
    except ValueError:
        raise ValueError("Selected flavor changelog entry is missing")
    end = next((i for i in range(start, len(lines)) if lines[i].startswith("## ")), len(lines))
    notes = "\n".join(lines[start:end]).strip()
    if not notes:
        raise ValueError("Selected flavor changelog entry is empty")
    return notes + "\n"


def check(tag=None, archive=None, for_release=False):
    manifest = json.loads((ROOT / ".release-manifest.json").read_text())
    if for_release and manifest.get("releaseBlockers"):
        raise ValueError("Release blocked: " + "; ".join(manifest["releaseBlockers"]))
    expected_tag = manifest["tag"]
    flavor = manifest["flavor"]
    if flavor not in ("retail", "forever") or not re.fullmatch(flavor + r"-v\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)[.\d]*)?", expected_tag):
        raise ValueError("Invalid release version")
    if tag and tag != expected_tag:
        raise ValueError("Release tag does not match exported version")
    release_notes(manifest)
    toc = (ROOT / (manifest["addon"] + ".toc")).read_text()
    if not re.search(r"^## Version:\s*" + re.escape(expected_tag.split("-v", 1)[1]) + r"\s*$", toc, re.M):
        raise ValueError("TOC version mismatch")
    interface = manifest["interface"]
    if not re.search(r"^## Interface:\s*" + str(interface) + r"\s*$", toc, re.M):
        raise ValueError("Interface mismatch")
    game_version = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"
    if manifest["curseforge"]["gameVersion"] != game_version:
        raise ValueError("CurseForge game version does not match the TOC Interface")
    if manifest["curseforge"]["gameVersionTypeId"] != {"retail": 517, "forever": 88568}[flavor]:
        raise ValueError("CurseForge game-version type does not match release flavor")
    if manifest["curseforge"]["projectId"] != 1703274:
        raise ValueError("Unexpected CurseForge project")
    if not re.search(r"^## X-Curse-Project-ID:\s*" + str(manifest["curseforge"]["projectId"]) + r"\s*$", toc, re.M):
        raise ValueError("CurseForge project ID mismatch")
    adapters = {"retail": "ClientRetail.lua", "forever": "ClientForever.lua"}
    if adapters[flavor] not in manifest["runtime"] or adapters[{"retail": "forever", "forever": "retail"}[flavor]] in manifest["runtime"]:
        raise ValueError("Wrong client adapter in runtime")
    if [n for n in manifest["runtime"] if n.endswith(".toc")] != [manifest["addon"] + ".toc"]:
        raise ValueError("Wrong client TOC in runtime")
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
    matches = [v for v in versions if v["gameVersionTypeID"] == target["gameVersionTypeId"] and v["name"] == target["gameVersion"] and isinstance(v.get("id"), int)]
    if len(matches) != 1:
        raise ValueError("CurseForge has no unique exact game-version match; refusing a fallback version")
    game_version_id = matches[0]["id"]
    print(f"PASS CurseForge {manifest['flavor']} game version {target['gameVersion']} (ID {game_version_id})")
    return game_version_id


def upload_curseforge(manifest, archive):
    game_version_id = curseforge_check(manifest)
    boundary = "companion-chronicle-" + uuid.uuid4().hex
    metadata = json.dumps({"displayName": manifest["tag"], "gameVersions": [game_version_id],
                           "releaseType": "release", "changelog": release_notes(manifest),
                           "changelogType": "markdown"}).encode()
    filename = Path(archive).name
    file_bytes = Path(archive).read_bytes()
    parts = [
        b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n" + metadata + b"\r\n",
        b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"" + filename.encode() + b"\"\r\nContent-Type: application/zip\r\n\r\n" + file_bytes + b"\r\n",
        b"--" + boundary.encode() + b"--\r\n",
    ]
    request = urllib.request.Request(
        f"https://wow.curseforge.com/api/projects/{manifest['curseforge']['projectId']}/upload-file",
        data=b"".join(parts), method="POST",
        headers={"X-Api-Token": os.environ["CF_API_KEY"], "Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 200:
            raise ValueError(f"CurseForge upload failed: HTTP {response.status}")
    print(f"PASS CurseForge uploaded verified {manifest['flavor']} ZIP for game-version ID {game_version_id}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--for-release", action="store_true")
    parser.add_argument("--zip", type=Path)
    parser.add_argument("--curseforge-check", action="store_true")
    parser.add_argument("--upload-curseforge", action="store_true")
    parser.add_argument("--notes-output", type=Path)
    args = parser.parse_args()
    result = check(args.tag, args.zip, args.for_release)
    if args.notes_output:
        args.notes_output.write_text(release_notes(result))
    if args.curseforge_check:
        curseforge_check(result)
    if args.upload_curseforge:
        if not args.zip or not args.for_release or not args.tag:
            raise ValueError("Upload requires --for-release, --tag and --zip")
        upload_curseforge(result, args.zip)
