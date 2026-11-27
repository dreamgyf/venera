from pathlib import Path
import re
import shutil
import subprocess

import httpx


def require_file(path):
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Build output is missing or empty: {path}")


def main():
    root = Path(__file__).resolve().parent.parent
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s+]+)", pubspec, re.MULTILINE)
    if match is None:
        raise RuntimeError("pubspec.yaml does not contain a version")
    version = match.group(1)

    subprocess.run(
        ["flutter", "build", "windows", "--release"],
        shell=True,
        cwd=root,
        check=True,
    )

    release_dir = root / "build/windows/x64/runner/Release"
    require_file(release_dir / "venera.exe")
    require_file(release_dir / "flutter_windows.dll")
    if not (release_dir / "data/flutter_assets").is_dir():
        raise RuntimeError(f"Flutter assets are missing: {release_dir}")

    archive_base = root / f"build/windows/Venera-{version}-windows"
    shutil.make_archive(str(archive_base), "zip", root_dir=release_dir)

    language_file = root / "windows/ChineseSimplified.isl"
    if not language_file.exists():
        url = (
            "https://cdn.jsdelivr.net/gh/"
            "kira-96/Inno-Setup-Chinese-Simplified-Translation@latest/"
            "ChineseSimplified.isl"
        )
        response = httpx.get(url, follow_redirects=True, timeout=30)
        response.raise_for_status()
        language_file.write_bytes(response.content)

    iss_path = root / "windows/build.iss"
    original_iss = iss_path.read_bytes()
    rendered_iss = original_iss.decode("utf-8").replace("{{version}}", version)
    rendered_iss = rendered_iss.replace("{{root_path}}", str(root))
    installer = root / f"build/windows/Venera-{version}-windows-installer.exe"
    if installer.exists():
        installer.unlink()
    try:
        iss_path.write_bytes(rendered_iss.encode("utf-8"))
        subprocess.run(
            ["iscc", str(iss_path)], shell=True, cwd=root, check=True
        )
        require_file(installer)
    finally:
        iss_path.write_bytes(original_iss)


if __name__ == "__main__":
    main()
