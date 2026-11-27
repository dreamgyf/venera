"""Attach successful platform builds without replacing published assets."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    repository = os.environ["GITHUB_REPOSITORY"]
    tag = os.environ["RELEASE_TAG"]
    release = json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{repository}/releases/tags/{tag}"], text=True,
    ))
    existing = {asset["name"] for asset in release["assets"]}
    extensions = {".dmg", ".apk", ".zip", ".exe", ".deb", ".zst", ".AppImage"}
    files = sorted(path for path in Path("outputs").rglob("*")
                   if path.is_file() and path.suffix in extensions)
    if not files:
        raise RuntimeError("No successful platform packages are available to publish")
    names = [path.name for path in files]
    if len(names) != len(set(names)):
        raise RuntimeError("Different platform artifacts contain duplicate package names")
    for path in files:
        if path.stat().st_size == 0:
            raise RuntimeError(f"Empty package: {path}")
        if path.name in existing:
            print(f"Keeping existing asset: {path.name}")
            continue
        subprocess.run(
            ["gh", "release", "upload", tag, str(path), "--repo", repository],
            check=True,
        )

    # A partial rebuild must retain warnings for packages already on the release.
    published_names = existing | set(names)
    notes = []
    if any(name.endswith("-unsigned.apk") for name in published_names):
        notes.append("* Android `*-unsigned.apk` files are unsigned and require signing before installation.")
    if any(name.endswith("-adhoc.dmg") for name in published_names):
        notes.append("* macOS `*-adhoc.dmg` uses ad hoc signing, without a Developer ID certificate or notarization.")
    if not notes:
        return
    run_url = f"https://github.com/{repository}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    start = "<!-- platform-build-notes:start -->"
    end = "<!-- platform-build-notes:end -->"
    block = "\n".join([start, "**Platform build notes**", "", *notes, "",
                       f"Build configuration and package provenance: [GitHub Actions]({run_url}).", end])
    body = release.get("body") or ""
    if start in body and end in body:
        before, rest = body.split(start, 1)
        _, after = rest.split(end, 1)
        body = before + block + after
    else:
        body = body.rstrip() + "\n\n" + block + "\n"
    with tempfile.TemporaryDirectory() as temporary:
        notes_file = Path(temporary) / "release-notes.md"
        notes_file.write_text(body, encoding="utf-8")
        subprocess.run(["gh", "release", "edit", tag, "--repo", repository,
                        "--notes-file", str(notes_file)], check=True)


if __name__ == "__main__":
    main()
