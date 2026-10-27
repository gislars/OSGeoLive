# OSGeoLive FOSSGIS-Edition bauen

Dieses Repository ist der FOSSGIS-Fork von OSGeoLive. Was sich gegenüber OSGeo
unterscheidet, steht in [upstream-diff.md](upstream-diff.md).

Vor jedem Build und jeder Änderung an Build-Skripten:
[build-safety.md](build-safety.md). Der Build läuft als root auf dem Arbeitsrechner;
dort stehen zwei Vorfälle und die Regeln, die daraus folgen. Regeln für
KI-Assistenten: [`AGENTS.md`](../../AGENTS.md).

## Build starten (nur in der Build-VM)

Gebaut wird ausschließlich in einer QEMU/KVM-VM, als normaler Benutzer, ohne `sudo`
auf dem Host. Gebaut wird der committete Stand (`HEAD`) des Checkouts, aus dem das
Skript aufgerufen wird.

```sh
fossgis/tools/builder_vm.sh create   # einmalig: Ubuntu-Cloud-Image, VM-Platte (bis 80G)
fossgis/tools/builder_vm.sh start
fossgis/tools/builder_vm.sh build    # wie build_chroot.sh amd64 nightly
fossgis/tools/builder_vm.sh build --ref build/resolute-base   # anderer Branch
fossgis/tools/builder_vm.sh stop
```

`build` folgt dem Log; bricht die Verbindung ab, holt `follow` es wieder.
Am Ende kopiert `fetch` ISO und Log nach `build/` und `build/logs/` und prüft mit
`host_guard.sh`, dass der Host unverändert ist. Grenzen über `FOSSGIS_VM_CPUS`,
`FOSSGIS_VM_RAM`, `FOSSGIS_VM_DISK`. `destroy` löscht die VM vollständig.

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

## Download-Cache

Der Build hält Downloads zwischen den Läufen in `local/cache/` vor (abschaltbar mit
`FOSSGIS_CACHE="0"` in `local/local.env`, anderes Verzeichnis mit
`FOSSGIS_CACHE_DIR`):

| Was | Verzeichnis | Wie |
|---|---|---|
| Lubuntu-Image | `build/` | bleibt liegen, `wget -c` und Prüfsumme bei jedem Lauf |
| apt-Pakete | `local/cache/apt/` | Bind-Mount als `/var/cache/apt/archives` im Chroot |
| `wget` der Install-Skripte | `local/cache/downloads/<host>/<pfad>` | Wrapper `fossgis/tools/wget_cache.sh` als `/usr/local/bin/wget` im Chroot |

- `setdown.sh` hängt den Cache vor `apt-get clean` aus und entfernt den Wrapper;
  `build_chroot.sh` prüft das nach dem Chroot-Teil noch einmal und bricht ab, wenn
  der Cache noch eingehängt ist. Er landet also nie im ISO.
- Der Wrapper bedient nur Aufrufe mit genau einer URL ohne Query-String und mit den
  in den Skripten üblichen Optionen (`-c`, `-N`, `-O`, `-P`, `-x`, `--tries`,
  `--progress`). Alles andere geht unverändert an das echte `wget`, zum Beispiel
  `-O-` für Ausgaben auf stdout. Fehlgeschlagene Downloads werden nicht gespeichert.
- Neu laden: `FOSSGIS_CACHE_REFRESH="1"` in `local/local.env` für einen Lauf, oder
  einzelne Dateien unter `local/cache/downloads/` löschen.
- Nicht gecacht werden `git clone`, `pip` und `apt-get update` (Paketlisten).
- In der Build-VM liegt der Cache auf der VM-Platte; `builder_vm.sh build` kopiert
  `local/cache/` hinein, `fetch` nur neue Dateien zurück.

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

Für einen Vollbuild wird die Datei wieder entfernt oder umbenannt. Startet ein
Skript der Liste einen Dienst (zum Beispiel `service_postgresql.sh`), muss die Liste
mit `setdown.sh` enden, das die Dienste wieder stoppt.
