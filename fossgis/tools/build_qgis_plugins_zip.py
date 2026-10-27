#!/usr/bin/env python3
"""
Builds a ZIP archive of QGIS plugins from plugins.qgis.org.
Layout: usr/share/qgis/python/plugins/<PluginName>/... (standard QGIS plugin path).
Extract with: unzip -d <target> <output.zip>
"""
import io
import os
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Optional

# Plugin name and version string (as used on plugins.qgis.org).
PLUGINS_CURRENT = {
    "DigitizingTools": "1.5.3",
    "DirectionalSlope": "1.3.2",
    "GroupStats": "2.2.7",
    "OSMDownloader": "1.0.4",
    "Qgis2threejs": "3.3",
    "QuickOSM": "2.5.0",
    "SpreadsheetLayers": "2.1.2",
    "clipper": "1.2",
    "contour": "2.0.15",
    "lrs": "1.2.5",
    "Mergin": "2026.1.2",
    "mmqgis": "2026.6.12",
    "pgRoutingLayer": "4.0.0",
    "plaingeometryeditor": "3.0.0",
    "processing_r": "4.1.0",
    "profiletool": "4.3.3",
    "qgis2web": "3.32.0",
    "quick_map_services": "1.1.0",
    "timemanager": "3.7",
    "valuetool": "3.1.0",
    # plugins.qgis.org uses a leading "v" for this plugin's versions
    "qfieldsync": "v4.23.2",
}

# Output under local/ (not committed); path is resolved from the repo root.
OUTPUT_REL = Path("local/data/qgis")
OUTPUT_ZIP = "qgis4-osgeolive-plugins.zip"
# Path prefix inside the ZIP (standard system path for QGIS Python plugins).
BASE_PATH = "usr/share/qgis/python/plugins"
# Skip plugins that declare they do not support QGIS 4.
MIN_QGIS_MAJOR = 4
# User-Agent sent when requesting plugin downloads.
USER_AGENT = "QGIS-Plugin-Builder/1.0"

# URL template for plugin ZIP download; placeholders: {plugin_name}, {version}.
PLUGIN_DOWNLOAD_URL = "https://plugins.qgis.org/plugins/{plugin_name}/version/{version}/download/"

# Request timeout in seconds for plugin downloads.
DOWNLOAD_TIMEOUT = 60


def download_plugin(plugin_name: str, version: str) -> bytes:
    """Download the given plugin version from plugins.qgis.org and return the ZIP bytes."""
    url = PLUGIN_DOWNLOAD_URL.format(plugin_name=plugin_name, version=version)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=DOWNLOAD_TIMEOUT) as resp:
        return resp.read()


def get_top_level_folder(zf: zipfile.ZipFile) -> Optional[str]:
    """Return the single top-level directory in the plugin ZIP, or None if not unique."""
    names = zf.namelist()
    top_dirs = set()
    for n in names:
        if "/" in n:
            top_dirs.add(n.split("/", 1)[0])
    # Keep only entries that are real directories (have children), not single root files.
    top_dirs = {d for d in top_dirs if any(n.startswith(d + "/") for n in names)}
    if len(top_dirs) == 1:
        return next(iter(top_dirs))
    return None


def supports_qgis4(plugin_dir: Path) -> bool:
    """Return False if metadata.txt caps the plugin below QGIS 4."""
    meta = plugin_dir / "metadata.txt"
    if not meta.is_file():
        return True
    max_ver = ""
    for line in meta.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.lower().startswith("qgismaximumversion"):
            max_ver = line.split("=", 1)[-1].strip()
            break
    if not max_ver:
        return True
    try:
        major = int(max_ver.split(".", 1)[0])
    except ValueError:
        return True
    return major >= MIN_QGIS_MAJOR


def main() -> None:
    """Download each plugin, skip those incompatible with QGIS 4, write local ZIP."""
    workdir = tempfile.mkdtemp(prefix="qgis_plugins_")
    target_base = os.path.join(workdir, BASE_PATH)
    os.makedirs(target_base, exist_ok=True)
    kept = 0
    skipped = 0

    try:
        for i, (plugin_name, version) in enumerate(PLUGINS_CURRENT.items(), 1):
            print(f"[{i}/{len(PLUGINS_CURRENT)}] {plugin_name} {version} ... ", end="", flush=True)
            try:
                data = download_plugin(plugin_name, version)
            except (urllib.error.URLError, OSError) as e:
                print(f"Download failed: {e}")
                continue

            with zipfile.ZipFile(io.BytesIO(data), "r") as zf:
                top = get_top_level_folder(zf)
                for info in zf.infolist():
                    name = info.filename.rstrip("/")
                    # Skip root entry and the top-level folder entry (we flatten one level).
                    if not name or (top and name == top):
                        continue
                    # Path inside the output plugin dir: strip single top folder if present.
                    arcname = name[len(top) + 1:] if (top and name.startswith(top + "/")) else name
                    target_path = os.path.join(target_base, plugin_name, arcname)
                    if info.is_dir() or info.filename.endswith("/"):
                        os.makedirs(target_path, exist_ok=True)
                    else:
                        os.makedirs(os.path.dirname(target_path) or ".", exist_ok=True)
                        with zf.open(info) as src, open(target_path, "wb") as dst:
                            shutil.copyfileobj(src, dst)
            plugin_dir = Path(target_base) / plugin_name
            if not supports_qgis4(plugin_dir):
                shutil.rmtree(plugin_dir, ignore_errors=True)
                print("SKIP (qgisMaximumVersion < 4)")
                skipped += 1
                continue
            print("OK")
            kept += 1
    finally:
        repo_root = Path(__file__).resolve().parents[2]
        output_dir = repo_root / OUTPUT_REL
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / OUTPUT_ZIP
        print(f"\nCreating {OUTPUT_ZIP} ({kept} plugins, {skipped} skipped) ...")
        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
            for root, _dirs, files in os.walk(workdir):
                for f in files:
                    full = os.path.join(root, f)
                    arcname = os.path.relpath(full, workdir)
                    out_zip.write(full, arcname)
        shutil.rmtree(workdir, ignore_errors=True)
        size_mb = output_path.stat().st_size / (1024 * 1024)
        print(f"Done: {output_path} ({size_mb:.2f} MiB)")


if __name__ == "__main__":
    main()
