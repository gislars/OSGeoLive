# Abweichungen vom OSGeo-Upstream (FOSSGIS-Edition)

Dieses Dokument listet alle Änderungen dieses Forks (`gislars/OSGeoLive`) gegenüber
[OSGeo/OSGeoLive](https://github.com/OSGeo/OSGeoLive). Jeder Themen-Branch, der etwas
in `bin/`, `app-conf/`, `desktop-conf/`, `sources.list.d/` oder `fossgis/` ändert,
ergänzt hier seinen Eintrag im selben Branch. `fossgis/tools/check_clean.sh` prüft das
für jeden Merge nach `master` ab dem Tag `fossgis2027-base`.

Gegenprobe: `fossgis/tools/upstream_diff_report.sh` listet alle geänderten Dateien und
meldet Dateien, die hier nicht erwähnt sind.

## Stand

| | |
|---|---|
| Edition | FOSSGIS 2027 Heidelberg |
| Upstream-Basis | OSGeo/OSGeoLive `master` bei `4ee8d3ab` (nach Tag `17.0.0`) |
| Letzter Upstream-Sync | keiner, Basis vom 27.10.2026 |
| Archiv-Branches | `fossgis2025` (Münster), `fossgis2026` (Göttingen) |

## Einordnung

Jeder Eintrag ist einer von drei Klassen zugeordnet:

- **FOSSGIS-spezifisch:** gehört nur zur Konferenz-Edition (Branding, Ort, Daten,
  Prüfwerkzeuge des Forks). Wird nicht an OSGeo gemeldet.
- **upstream-tauglich:** behebt einen allgemeinen Fehler oder verbessert den Build
  für alle. Kandidat für einen Pull Request an OSGeo; den stellt nur der Maintainer
  selbst, nie ein Skript.
- **temporär:** Übergangslösung, bis Upstream oder ein Paket nachzieht. Mit Bedingung,
  wann der Eintrag entfallen kann.

## Build-System

### Build ohne eigenen Host-Benutzer

- **Dateien:** `bin/build_chroot.sh`, `bin/bootstrap.sh`, `bin/inchroot.sh`
- **Was:** `build_chroot.sh` baut aus dem Checkout, aus dem es aufgerufen wird, nach
  `./build` (änderbar über `BUILD_DIR`) und kopiert den Arbeitsbaum in den Chroot,
  statt von GitHub zu klonen. Reste abgebrochener Builds werden vorher ausgehängt und
  gelöscht. Ohne Tags dient die Zahl der Commits als Build-Nummer. Die Build-Nummer
  zählt nur ab numerischen Release-Tags (`git describe --match '[0-9]*'`), damit
  Fork-Tags wie `fossgis2027-base` sie nicht verfälschen.
  `bootstrap.sh` nimmt auf dem Host den Benutzer, der `sudo` aufgerufen hat, bricht
  bei unbekannten Benutzern ab und kann mehrfach laufen (vorhandener Klon wird
  übersprungen, `ln -sfn`). `inchroot.sh` setzt `USER_NAME=user` vor `bootstrap.sh`
  und entfernt das vom Host durchgereichte `SUDO_USER`.
- **Warum:** Upstream setzt einen Host-Benutzer `user` und einen Klon unter
  `/usr/local/share/gisvm` voraus. Wir bauen ohne zusätzlichen Benutzer, vollständig
  im Projektverzeichnis.
- **Einordnung:** upstream-tauglich
- **Commit:** `4fc4f84d`

### Nur versionierte Dateien in den Chroot kopieren

- **Dateien:** `bin/build_chroot.sh`, `bin/bootstrap.sh`
- **Was:** In den Chroot kommen nur versionierte und nicht ignorierte Dateien
  (`git ls-files --cached --others --exclude-standard`). Der Build bricht ab, wenn
  `osgeolive_old`, `local`, `osgeolive-doc`, `local.env`, `build`, `*.nmconnection`,
  `*.pbf` oder `*.iso` in der Kopie auftauchen. `bootstrap.sh` überspringt den Klon
  auch dann, wenn eine Kopie ohne `.git` vorliegt.
- **Warum:** Das vorherige `tar` des ganzen Checkouts hätte lokale Daten, Secrets
  und den Referenz-Checkout `osgeolive_old/` mit ins ISO genommen.
- **Einordnung:** upstream-tauglich (zusammen mit dem Eintrag oben)
- **Merge:** `fix/build-copy-tracked-only`

### Lubuntu-Image: aktuelles Point-Release, Prüfsumme, Abbruch bei Fehlern

- **Dateien:** `bin/build_chroot.sh`
- **Was:** `ISO_RELEASE` von 24.04.2 auf 24.04.5. Der Build prüft die SHA256-Summe
  des Images gegen `SHA256SUMS` von cdimage und bricht ab, wenn Download,
  Prüfsumme, Mount, die EFI-Partition oder `unsquashfs` scheitern. Die Aufräumphase
  entfernt zusätzlich `squashfs-root` und `myinitrd` abgebrochener Läufe.
- **Warum:** cdimage hält nur das neueste Point-Release einer Serie vor; 24.04.2
  lieferte 404. Ohne Abbruch lief das Skript mit Dutzenden Folgefehlern bis zum
  Ende weiter.
- **Einordnung:** upstream-tauglich (Upstream hat dasselbe Problem). Die Version
  wird mit `build/resolute-base` ohnehin 26.04.1.
- **Merge:** `fix/build-iso-download`

### ISO mit squashfs über 4 GiB

- **Dateien:** `bin/build_chroot.sh`
- **Was:** `xorriso` bekommt `-iso-level 3`. Scheitern `mksquashfs` oder `xorriso`,
  bricht der Build ab, bevor aufgeräumt wird; `edit/` bzw. `extract-cd/` bleiben
  erhalten.
- **Warum:** Mit 24.04.5 ist `casper/filesystem.squashfs` 4,28 GB groß; ohne
  ISO-Level 3 lehnt libisofs Dateien ab 4 GiB ab. Der Build lief trotzdem bis zum
  Ende und löschte das Ergebnis.
- **Einordnung:** upstream-tauglich
- **Merge:** `fix/iso-large-squashfs`

### Build-Logs werden automatisch abgelegt

- **Dateien:** `bin/build_chroot.sh`, `fossgis/tools/record_full_build.sh`
- **Was:** `build_chroot.sh` ruft sich einmal selbst auf und schreibt die gesamte
  Ausgabe nach `build/logs/<Startzeit>-<ISO-Name>.log`. Der Kopf enthält Commit,
  `git describe`, die Zahl geänderter Dateien, Aufruf und Build-Verzeichnis, das
  Ende Exit-Code und ISO mit SHA256. `build/logs/index.tsv` listet alle Builds,
  `build/logs/latest.log` zeigt auf den letzten. `record_full_build.sh` nimmt
  ohne Angabe `latest.log` und akzeptiert `green` nur, wenn das Log zu HEAD ohne
  lokale Änderungen gehört und ein ISO entstanden ist.
- **Warum:** Kein `tee`, kein Umbenennen von Hand; jedes Log bleibt erhalten und
  ist einem Commit und einem ISO zugeordnet.
- **Einordnung:** upstream-tauglich
- **Merge:** `chore/build-logs`

### ISO in QEMU starten

- **Dateien:** `fossgis/tools/run_iso.sh`
- **Was:** startet das neueste `build/osgeolive-*.iso` (oder ein angegebenes) in
  QEMU/KVM, standardmäßig per UEFI, mit `--bios` per BIOS. Die Zwischenablage wird
  über SPICE mit dem Host geteilt: Auf dem Host braucht es `remote-viewer` (Paket
  `virt-viewer`), im Gast läuft `spice-vdagent`. Das GTK-Fenster von Ubuntus QEMU
  kann keine Zwischenablage; ohne `remote-viewer` startet das Skript trotzdem und
  weist darauf hin.
- **Warum:** ein kurzer Befehl für den QEMU-Test vor jedem Push, Fehlermeldungen
  lassen sich aus der VM auf den Host kopieren.
- **Einordnung:** nur FOSSGIS (Werkzeug)
- **Merge:** `chore/run-iso`

### Vorgabe-Repository ist der Fork

- **Dateien:** `bin/build_chroot.sh`, `bin/inchroot.sh`, `bin/bootstrap.sh`
- **Was:** Ohne Angabe eines GitHub-Benutzers gilt `gislars` statt `OSGeo`, also
  `https://github.com/gislars/OSGeoLive.git`. Die Usage-Texte nennen die neue Vorgabe.
- **Warum:** Wird `bootstrap.sh` außerhalb des lokalen Builds aufgerufen, etwa in
  einer VM, soll es die FOSSGIS-Edition klonen und nicht OSGeo.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `chore/fork-defaults`

### Edition-Einstellungen und lokale Eingaben

- **Dateien:** `fossgis/edition.conf`, `fossgis/local.env.example`,
  `fossgis/load_edition.sh`, `bin/build_chroot.sh`, `bin/inchroot.sh`,
  `bin/setdown.sh`, `docs/fossgis/README.md`
- **Was:** Alles, was sich jährlich ändert, steht in `fossgis/edition.conf`;
  Secrets stehen in der nicht versionierten `local/local.env`. `build_chroot.sh`
  kopiert `edition.conf` und aus `local/` die Einträge `local.env`, `inchroot.list`,
  `artwork/` und `data/` nach `/tmp/fossgis` im Chroot. `inchroot.sh` lädt die Werte
  über `load_edition.sh` und exportiert sie. `setdown.sh` und `inchroot.sh` löschen
  `/tmp/fossgis` am Ende. Mit `local/inchroot.list` laufen nur die dort genannten
  Skripte (Teilbuild).
- **Warum:** Jahreswerte zentral statt fest in den Skripten; Secrets und große Daten
  bleiben außerhalb des Repos; Teilbuilds für die Portierung, ohne `inchroot.sh`
  jedes Mal zu ändern.
- **Einordnung:** Teilbuild upstream-tauglich, Edition und `local/` FOSSGIS-spezifisch
- **Merge:** `chore/fossgis-layout`

### Lokaler Download-Cache

- **Dateien:** `bin/build_chroot.sh`, `bin/setdown.sh`, `bin/inchroot.sh`,
  `fossgis/tools/wget_cache.sh`, `fossgis/local.env.example`, `docs/fossgis/README.md`
- **Was:** `build_chroot.sh` hängt `local/cache/apt` als `/var/cache/apt/archives` und
  `local/cache/downloads` als `/var/cache/fossgis-downloads` in den Chroot und legt
  `wget_cache.sh` als `/usr/local/bin/wget` ab. Der Wrapper liefert bekannte
  Downloads aus dem Cache und speichert neue. `setdown.sh` hängt beides vor
  `apt-get clean` aus und entfernt den Wrapper; `inchroot.sh` tut dasselbe vor dem
  abschließenden `apt-get clean`, weil ein Teilbuild `setdown.sh` nicht ausführt.
  `build_chroot.sh` prüft das vor dem Packen und hängt alte Mounts vor
  `rm -rf edit` aus.
- **Warum:** Viele Builds pro Edition; ohne Cache lädt jeder Lauf mehrere GB von
  denselben Quellen.
- **Einordnung:** upstream-tauglich
- **Merge:** `feature/build-cache`

## Repository und Werkzeuge

### `.gitignore`

- **Dateien:** `.gitignore`
- **Was:** ignoriert `/build/`, `/osgeolive_old/`, `/local/` und `/osgeolive-doc/`.
- **Warum:** `build/` enthält Chroot, ISO und Logs. `osgeolive_old/` ist der nur
  lesend genutzte Checkout der Arbeit von 2026. `local/` enthält Secrets, Daten und
  Notizen, `osgeolive-doc/` den Klon des Doku-Forks.
- **Einordnung:** `build/` upstream-tauglich, der Rest FOSSGIS-spezifisch
- **Commits:** `4fc4f84d`, Merges `chore/ignore-osgeolive-old`, `chore/fossgis-layout`

### Prüfung vor dem Push

- **Dateien:** `fossgis/tools/check_clean.sh`, `fossgis/tools/check_clean.allow`,
  `fossgis/tools/check_clean.large`, `fossgis/tools/pre-push.hook`,
  `fossgis/tools/record_full_build.sh`
- **Was:** `check_clean.sh` prüft Commits vor dem Push auf Secrets (Zuweisungen von
  Passwörtern, PSK und Tokens sowie die Werte aus `local/local.env` und lokalen
  `*.nmconnection`), auf lokale Pfade, Datendateien und Dateigrößen, auf
  Konfliktmarker und Leerzeichenfehler, auf die Syntax von Shell- und Python-Dateien,
  auf Autor und Committer, auf die Merge-Regeln für `master` und auf den Nachweis des
  letzten Vollbuilds (`build/last-full-build.txt`, geschrieben von
  `record_full_build.sh`). Bei den Archiv-Branches werden Syntax, Autor, Betreff und
  Leerzeichen nur gemeldet. `pre-push.hook` ist die Vorlage für `.git/hooks/pre-push`:
  Push nur zu `gislars`, nur mit `FOSSGIS_PUSH_APPROVED=1` und nur mit grünem
  `check_clean.sh`.
- **Warum:** Ins Fork-Repo kommen nur saubere, getestete Commits, und kein Push geht
  ohne ausdrückliche Freigabe raus.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `chore/clean-check`

### Dieses Dokument

- **Dateien:** `docs/fossgis/upstream-diff.md`, `fossgis/tools/upstream_diff_report.sh`
- **Was:** Übersicht aller Abweichungen und ein Bericht zur Gegenprobe.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `docs/upstream-diff`

## Hinweise

- **Zeilenenden:** Einige Upstream-Dateien haben CRLF-Zeilenenden, zum Beispiel
  `app-conf/mapcache/index.html` und `app-data/jupyter/jupyter.svg`. Im Repo ist
  deshalb lokal `core.autocrlf=false` gesetzt, sonst entstehen bei einem global
  gesetzten `core.autocrlf=input` scheinbare Änderungen an diesen Dateien.
- **Archiv-Branches** werden nicht nach `master` gemergt. Fixes daraus kommen als
  eigene Commits in Themen-Branches und bekommen dort ihren Eintrag.

## Versionen

Abweichende Versionen gegenüber OSGeoLive 17.0. Wird von den Branches für Basis,
GIS-Stack und Anwendungen ergänzt.

| Komponente | OSGeoLive 17.0 | FOSSGIS 2027 | Einordnung |
|---|---|---|---|
| Basis | Lubuntu 24.04.2 | Lubuntu 24.04.5 (26.04.1 folgt) | upstream-tauglich |
