# OSGeoLive FOSSGIS-Edition bauen

Dieses Repository ist der FOSSGIS-Fork von OSGeoLive. Was sich gegenüber OSGeo
unterscheidet, steht in [upstream-diff.md](upstream-diff.md).

> Gerüst, wird mit dem Branch `docs/fossgis-build` vervollständigt.

## Verzeichnisse

| Pfad | Im Repo | Inhalt |
|---|---|---|
| `fossgis/edition.conf` | ja | alles, was sich jedes Jahr ändert (Name, Ort, OSM-Relation, Karte) |
| `fossgis/local.env.example` | ja | Vorlage für `local/local.env` |
| `fossgis/load_edition.sh` | ja | lädt `edition.conf` und `local.env` in den Install-Skripten |
| `fossgis/tools/` | ja | Prüf- und Hilfsskripte (`check_clean.sh` usw.) |
| `local/` | nein | lokale Eingaben: `local.env`, `inchroot.list`, `artwork/`, `data/` |
| `local/docs/` | nein | nur informative Notizen (Workarounds), werden nicht kopiert |
| `build/` | nein | Chroot, ISO, Logs und Worktrees |
| `osgeolive_old/` | nein | Referenz-Checkout von 2026, nur lesen |

## Ablauf im Build

1. `bin/build_chroot.sh` kopiert die versionierten Dateien nach
   `/usr/local/share/gisvm` im Chroot.
2. Danach kopiert es `fossgis/edition.conf` sowie aus `local/` die Einträge
   `local.env`, `inchroot.list`, `artwork/` und `data/` nach `/tmp/fossgis`.
   `local.env` bekommt dort die Rechte `600`.
3. `bin/inchroot.sh` lädt beides über `fossgis/load_edition.sh` und exportiert die
   Werte für alle Install-Skripte.
4. `bin/setdown.sh` löscht `/tmp/fossgis` am Ende, `inchroot.sh` zur Sicherheit
   ebenfalls.

## Lokale Einstellungen

```sh
mkdir -p local
cp fossgis/local.env.example local/local.env
chmod 600 local/local.env
```

## Teilbuild

Liegt `local/inchroot.list` vor, führt `inchroot.sh` nur die dort genannten Skripte
aus, in dieser Reihenfolge und statt der normalen Liste. Eine Zeile pro Skript mit
Argumenten; leere Zeilen und Zeilen mit `#` am Anfang werden übersprungen:

```sh
setup.sh "$BUILD_MODE"
base_c.sh
service_postgresql.sh
install_postgis.sh
install_desktop.sh
setdown.sh
```

Für einen Vollbuild wird die Datei wieder entfernt oder umbenannt.
