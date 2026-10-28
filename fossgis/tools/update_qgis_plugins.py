#!/usr/bin/env python3
"""
Compare pinned QGIS plugin versions with plugins.qgis.org and update
fossgis/tools/qgis_plugins_pins.json.

Fetches a single plugins.xml for the pinned QGIS major.minor, caches it under
local/cache/qgis-plugins/ (TTL 24h), and avoids per-plugin HTTP requests.

Usage:
  python3 fossgis/tools/update_qgis_plugins.py [--dry-run] [--force]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Optional, Tuple

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[1]
PINS_FILE = TOOLS_DIR / "qgis_plugins_pins.json"
CACHE_DIR = REPO_ROOT / "local" / "cache" / "qgis-plugins"

USER_AGENT = "FOSSGIS-QGIS-Plugin-Updater/1.0"
DOWNLOAD_TIMEOUT = 60
TTL = timedelta(hours=24)
PLUGINS_XML_URL = "https://plugins.qgis.org/plugins/plugins.xml?qgis={qgis}"


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def parse_iso(value: str) -> datetime:
    # Python 3.11+: fromisoformat handles offsets; tolerate Z.
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def norm_version(version: str) -> str:
    return (version or "").lstrip("v").strip()


def load_pins() -> dict:
    data = json.loads(PINS_FILE.read_text(encoding="utf-8"))
    if "plugins" not in data or not isinstance(data["plugins"], dict):
        raise SystemExit(f"Invalid pins file (missing plugins): {PINS_FILE}")
    return data


def save_pins(data: dict) -> None:
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    PINS_FILE.write_text(text, encoding="utf-8")


def cache_paths(qgis: str) -> Tuple[Path, Path]:
    safe = re.sub(r"[^0-9.]+", "_", qgis)
    return (
        CACHE_DIR / f"plugins-{safe}.xml",
        CACHE_DIR / f"plugins-{safe}.meta.json",
    )


def cache_is_fresh(meta_path: Path) -> bool:
    if not meta_path.is_file():
        return False
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        fetched = parse_iso(meta["fetched_at"])
    except (OSError, KeyError, ValueError, json.JSONDecodeError):
        return False
    if fetched.tzinfo is None:
        fetched = fetched.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc) - fetched.astimezone(timezone.utc) < TTL


def fetch_plugins_xml(qgis: str, force: bool) -> Tuple[bytes, str, bool]:
    """
    Return (xml_bytes, fetched_at_iso, from_cache).
    """
    url = PLUGINS_XML_URL.format(qgis=qgis)
    xml_path, meta_path = cache_paths(qgis)
    env_force = os.environ.get("FOSSGIS_CACHE_REFRESH", "") == "1"
    force = force or env_force

    if not force and xml_path.is_file() and cache_is_fresh(meta_path):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        print(f"cache hit: {xml_path} (fetched_at={meta.get('fetched_at')})")
        return xml_path.read_bytes(), meta["fetched_at"], True

    print(f"fetching {url} ...")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=DOWNLOAD_TIMEOUT) as resp:
            data = resp.read()
    except (urllib.error.URLError, OSError) as e:
        if xml_path.is_file():
            print(f"WARNING: fetch failed ({e}); using stale cache {xml_path}", file=sys.stderr)
            meta = {}
            if meta_path.is_file():
                try:
                    meta = json.loads(meta_path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    meta = {}
            fetched_at = meta.get("fetched_at") or "unknown"
            return xml_path.read_bytes(), fetched_at, True
        raise SystemExit(f"ERROR: could not fetch {url}: {e}") from e

    fetched_at = now_iso()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    xml_path.write_bytes(data)
    meta = {"fetched_at": fetched_at, "url": url, "qgis": qgis}
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"cache stored: {xml_path} (fetched_at={fetched_at})")
    return data, fetched_at, False


def parse_latest_versions(xml_data: bytes) -> Dict[str, str]:
    """Map plugin slug -> latest version from plugins.xml (first occurrence wins)."""
    root = ET.fromstring(xml_data)
    latest: Dict[str, str] = {}
    for pyqgis in root.findall("pyqgis_plugin"):
        dl = pyqgis.findtext("download_url") or ""
        m = re.search(r"/plugins/([^/]+)/version/([^/]+)/", dl)
        if not m:
            continue
        slug, ver = m.group(1), m.group(2)
        latest.setdefault(slug, ver)
    return latest


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update QGIS plugin pins from plugins.qgis.org (cached plugins.xml)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report only; do not write qgis_plugins_pins.json",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignore TTL and always re-fetch plugins.xml (also FOSSGIS_CACHE_REFRESH=1)",
    )
    args = parser.parse_args()

    pins = load_pins()
    qgis = str(pins.get("qgis") or "4.2")
    plugins: Dict[str, str] = {str(k): str(v) for k, v in pins["plugins"].items()}
    prev_check = pins.get("last_check")
    print(f"pins: {PINS_FILE}")
    print(f"qgis={qgis} last_check={prev_check!r} plugins={len(plugins)}")

    xml_data, fetched_at, from_cache = fetch_plugins_xml(qgis, force=args.force)
    latest = parse_latest_versions(xml_data)
    print(f"upstream entries for qgis={qgis}: {len(latest)} (cache={'hit' if from_cache else 'miss'})")

    updates = []
    missing = []
    current = []
    for name in sorted(plugins, key=str.lower):
        pinned = plugins[name]
        up = latest.get(name)
        if up is None:
            missing.append(name)
            print(f"  {name}: pinned={pinned}  NOT in XML (unchanged)")
            continue
        if norm_version(up) != norm_version(pinned):
            updates.append((name, pinned, up))
            print(f"  {name}: {pinned} -> {up}")
        else:
            current.append(name)
            print(f"  {name}: {pinned} (current)")

    print(
        f"\nsummary: {len(current)} current, {len(updates)} updates, "
        f"{len(missing)} not in XML; xml_fetched_at={fetched_at}"
    )

    check_time = now_iso()
    if args.dry_run:
        print(f"dry-run: not writing pins (would set last_check={check_time})")
        return 0

    for name, _old, new in updates:
        plugins[name] = new
    pins["plugins"] = plugins
    pins["last_check"] = check_time
    pins["qgis"] = qgis
    save_pins(pins)
    print(f"wrote {PINS_FILE} (last_check={check_time}, {len(updates)} version change(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
