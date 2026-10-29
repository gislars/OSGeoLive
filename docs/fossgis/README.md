# OSGeoLive FOSSGIS-Edition bauen

Dieses Repository ist der FOSSGIS-Fork von OSGeoLive. Was sich gegenüber OSGeo
unterscheidet, steht in [upstream-diff.md](upstream-diff.md).

Vor jedem Build und jeder Änderung an Build-Skripten:
[build-safety.md](build-safety.md). Der Build läuft als root auf dem Arbeitsrechner;
dort stehen zwei Vorfälle und die Regeln, die daraus folgen. Regeln für
KI-Assistenten: [`AGENTS.md`](../../AGENTS.md).

Warum die großen Schnitte so gewählt sind, steht in [adr/](adr/README.md)
(eine Datei pro Entscheidung). `upstream-diff.md` bleibt die Liste der
Dateiänderungen.

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

## Voraussetzungen

- Host mit KVM/QEMU, genug freiem Speicher (ISO und Cache: mehrere 10 GB)
- `fossgis/tools/builder_vm.sh create` einmalig ausgefuehrt
- Vor dem ersten Build mit Heidelberg-Daten: `fossgis/prepare_data.sh`
  (benoetigt `osmium-tool`, `gdal-bin`, `wget`, Netz)
- Kein `sudo ./bin/build_chroot.sh` auf dem Host (siehe build-safety.md)

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
   `local.env`, `inchroot.list`, `artwork/` und `data/` nach
   `/usr/local/share/gisvm/fossgis-local` (nicht nach `/tmp`, dort hängt nspawn
   ein tmpfs ein). `local.env` bekommt dort die Rechte `600`.
3. `bin/inchroot.sh` lädt beides über `fossgis/load_edition.sh` und exportiert die
   Werte für alle Install-Skripte.
4. `bin/setdown.sh` löscht `fossgis-local` am Ende, `inchroot.sh` zur Sicherheit
   ebenfalls.

## Lokale Einstellungen

```sh
mkdir -p local
cp fossgis/local.env.example local/local.env
chmod 600 local/local.env
```

Variablen in `local/local.env` (siehe `fossgis/local.env.example`):

| Variable | Wirkung |
|---|---|
| `FOSSGIS_CACHE` | `"0"` schaltet den Download-Cache ab |
| `FOSSGIS_CACHE_DIR` | anderes Cache-Verzeichnis (Host-Pfad; in der VM gilt `local/cache`) |
| `FOSSGIS_CACHE_REFRESH` | `"1"` laedt Downloads neu und ersetzt den Cache |
| `WIFI_SSID` / `WIFI_PSK` / `WIFI_KEY_MGMT` | optionales WLAN-Profil (siehe unten) |
| `WORKSHOP_URL` | URL fuer das Desktop-Icon „Workshop Downloads“ |

Jahreswerte stehen in `fossgis/edition.conf` (`EDITION_*`, `MAP_*`, `OSM_*`,
`LOCALE`, `TIMEZONE`, `WALLPAPER`, `EDITION_ISO_SUFFIX`).

## Offline-Doku

```sh
git clone git@github.com:gislars/OSGeoLive-doc.git osgeolive-doc
fossgis/build_docs.sh
```

Baut `de` und `en` in `local/data/docs/html` und schreibt `local/data/docs/COMMIT`.
`DOCS_COMMIT` in `edition.conf` muss denselben Hash haben. Ohne passende Dateien
bricht der Build ab (kein stiller Rueckfall auf das PPA).

## OSM-Daten vorbereiten

```sh
fossgis/prepare_data.sh
```

Laedt das Geofabrik-PBF aus `OSM_SOURCE_PBF_URL`, stanzt die Relation
`OSM_RELATION` aus und schreibt nach `local/data/osm/`:

- `<MAP_CITY>.osm.pbf` (ins Image als `feature_city.osm.pbf`)
- `<MAP_CITY>.osm` (nur fuer osm2pgrouting im Build, nicht im ISO)
- `<MAP_CITY>.stamp` (SHA-256, Build-Pruefung)

Ohne passende Dateien bricht `build_chroot.sh` ab. Das Skript ist idempotent.

## Artwork

Hintergrundbild und optionale Logos liegen in `local/artwork/` (nicht im Repo).
Dateiname laut `WALLPAPER` in `edition.conf` (Standard `fossgis-desktop.png`).
Fehlt die Datei, nimmt `install_desktop.sh` `desktop-conf/osgeo-desktop.png`.

Erzeugen mit `fossgis/tools/build_wallpaper.sh` aus Quellen unter
`local/artwork/sources/` (Audimax-Foto + Heidelberg-Logo aus dem Orga-Artwork).
Ausgabe: `local/artwork/fossgis-desktop.png` (16:9, Safe-Zone ca. 110 px Rand)
plus Plymouth-Wasserzeichen unter `desktop-conf/plymouth/lubuntu-logo/`.
Der Desktop nutzt `WallpaperMode=zoom` (flaechenfuellend, ohne Verzerrung;
bei anderen Seitenverhaeltnissen werden Bildraender beschnitten). Zielhardware
der Workshop-Flotte: 15,6" Full HD (1920x1080, 16:9).

VM-Experimente (LXQt-Akzent, wanderndes Lock-Logo) stehen in
[branding-experiments.md](branding-experiments.md) und sind nicht Default.

Firefox: Policies und New-Tab-Extension unter `app-conf/fossgis/firefox/`
(Logo-Hintergrund, Verknuepfungen zur Konferenz-Website und zum Pretalx-Fahrplan,
keine Widgets/Empfehlungen). Firefox wird als Standardbrowser gesetzt.

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

## Optionales WLAN

In `local/local.env` koennen `WIFI_SSID`, `WIFI_PSK` und optional `WIFI_KEY_MGMT`
(`wpa-psk` oder `sae`) gesetzt werden. `bin/install_wifi.sh` schreibt dann
`/etc/NetworkManager/system-connections/fossgis.nmconnection` mit Rechten `600`.
Sind die Werte leer, wird der Schritt uebersprungen.

Sicherheit: Das PSK liegt im ISO und ist fuer jeden lesbar, der das Image hat.
Fuer Workshops einen eigenen Zugang nutzen, der nach der Konferenz wieder
gesperrt wird. Die alte Datei `app-conf/wifi_connection.nmconnection` wird nicht
uebernommen.

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

## Branch-Workflow

Jedes Thema bekommt einen eigenen Branch. Merges nach `master` laufen mit
`git merge --no-ff` und dem Trailer `Tested:` (Teilbuild-Nummer oder
`n/a` bei reiner Doku). Vor dem Merge: `fossgis/tools/check_clean.sh HEAD`.
Push nur nach ausdruecklicher Freigabe; Ziel ist ausschliesslich
`gislars/OSGeoLive`, nie `OSGeo/OSGeoLive`.

## Checkliste fuer das naechste Jahr

1. `fossgis/edition.conf`: Name, Daten, Ort, `OSM_RELATION`, PBF-URL, Kartenmitte
2. `fossgis/prepare_data.sh` neu laufen lassen; Stamp und Groessen pruefen
3. Artwork-Quellen nach `local/artwork/sources/`, dann `fossgis/tools/build_wallpaper.sh`
4. `bin/tools/list_pinned_versions.sh` und ggf. Versionen anheben
5. Neues Lubuntu-Point-Release / Basis pruefen
6. deegree 3.7 (Java 21+, Tomcat 11) und andere Major-Upgrades abwaegen
7. Offline-Doku (`osgeolive-doc/`) und `DOCS_COMMIT` aktualisieren
8. Vollbuild in der VM, `host_guard`, QEMU-Boot, `check_gis_stack.sh`

## Verwandte Dokumente

- [upstream-diff.md](upstream-diff.md): Abweichungen vom Upstream
- [branding-experiments.md](branding-experiments.md): optionale Branding-Tests in der VM
- [build-safety.md](build-safety.md): Host-Schutz und Vorfaelle
- [adr/](adr/README.md): Architekturentscheidungen
