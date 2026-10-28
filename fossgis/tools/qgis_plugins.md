# QGIS 4 plugin pins and ZIP

Pinned versions: `fossgis/tools/qgis_plugins_pins.json` (`last_check`, `plugins`).

## Automatic (every `builder_vm.sh build`)

`fossgis/tools/ensure_qgis_plugins.sh` runs on the host before sources are sent:

1. Refresh pins via `update_qgis_plugins.py` (XML cached 24h under
   `local/cache/qgis-plugins/`).
2. Rebuild `local/data/qgis/qgis4-osgeolive-plugins.zip` only if plugin
   versions changed, the ZIP is missing, or the stamp does not match.
3. Otherwise reuse the existing ZIP.

`install_qgis.sh` unpacks that ZIP from `local/` during the image build.
Uncommitted pin edits are not in the git bundle; the ZIP under `local/` is
what ends up in the ISO. Commit updated `qgis_plugins_pins.json` when you
want the pins in git history.

## Manual

```sh
fossgis/tools/ensure_qgis_plugins.sh
fossgis/tools/ensure_qgis_plugins.sh --force   # ignore XML TTL

python3 fossgis/tools/update_qgis_plugins.py --dry-run
python3 fossgis/tools/build_qgis_plugins_zip.py
```
