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

### Chroot nie mit eingehängtem /dev löschen

- **Dateien:** `bin/build_chroot.sh`, `bin/inchroot.sh`, `bin/setup.sh`,
  `fossgis/tools/tests/test_build_safety.sh`
- **Was:** Der Inchroot-Teil läuft in `systemd-nspawn` mit privatem `/dev` und
  Host-Netzwerk; Cache-Verzeichnisse kommen als `--bind` nur für die Laufzeit des
  Containers. Beim Ende des Containers enden auch übrig gebliebene Prozesse.
  `edit/` wird nur noch über `remove_chroot` gelöscht: Alles, was darunter
  eingehängt ist, wird vorher ausgehängt (lazy), bleibt trotzdem etwas übrig, bricht
  der Build ab; `rm` läuft mit `--one-file-system`. Bleibt nach dem Container etwas
  unter `edit/` eingehängt oder laufen noch Prozesse mit Root im Baum, bricht der
  Build vor dem Packen ab. `mksquashfs` läuft mit `-one-file-system`. Die apt-Quelle
  `cdrom.sources` des Live-Systems wird während des Builds beiseitegelegt und danach
  zurückgestellt. `depmod` läuft für die Kernel des Images. `test_build_safety.sh`
  prüft das statisch (und optional mit sudo zur Laufzeit); `check_clean.sh` ruft den
  statischen Teil auf, wenn `bin/build_chroot.sh` geändert wurde.
- **Warum:** Im ersten 26.04-Teilbuild war `edit/dev` (Bindung des Host-`/dev`) beim
  Aushängen belegt. Das folgende `rm -rf edit` leerte das `/dev` des Build-Rechners
  (Neustart nötig), und `mksquashfs` packte das `/dev` des Hosts ins Image. Ohne
  Abbruch bei laufenden Prozessen änderte PostgreSQL Dateien während des Packens.
  `cdrom.sources` zeigt auf `/cdrom`, das es im Container nicht gibt.
- **Einordnung:** upstream-tauglich (das Risiko stand schon als Kommentar im Skript)
- **Merge:** `build/resolute-base`, ergänzt in `fix/build-safety-hardening`

## Basis Lubuntu 26.04

### Geschichtetes Lubuntu-Image wird zusammengeführt

- **Dateien:** `bin/build_chroot.sh`, `desktop-conf/calamares/unpackfs.conf`,
  `desktop-conf/calamares/packages.conf`, `desktop-conf/calamares/initramfs.conf`
- **Was:** `UBU_RELEASE` 26.04, `ISO_RELEASE` 26.04.1. Das 26.04-ISO hat statt
  `filesystem.squashfs` drei Schichten (`minimal`, `minimal.standard`,
  `minimal.standard.live`). `build_chroot.sh` hängt die Kette per overlayfs
  zusammen, kopiert sie nach `edit/` und packt am Ende wie bisher eine
  `filesystem.squashfs`. `conf/conf.d/default-layer.conf` fliegt aus der initrd,
  damit casper diese eine Datei nimmt. Die initrd wird mit `3cpio -x -s` in
  getrennte Archive (`early`/`main`) entpackt (26.04 `unmkinitramfs` mischt sie
  sonst), dann mit dem Kompressor aus `conf/initramfs.conf` (zstd) neu gepackt.
  Fehlt `main/conf`, bricht der Build ab. Für Calamares ersetzt der Build
  `unpackfs.conf` (nur
  `filesystem.squashfs`), entfernt `stacked_squashfs.flag`, stellt in
  `settings.conf` `dracut`/`dracutlukscfg` auf `initramfs`/`initramfscfg` um und
  ergänzt `packages.conf` um das Entfernen der Live-Pakete (casper, Calamares,
  `user-setup`, `zram-config` und andere). Ein ISO ohne Schichten wird wie bisher
  verarbeitet. Plymouth-Titel und `.disk/info` werden unabhängig von „LTS“ und
  Codename ersetzt.
- **Warum:** Ohne Zusammenführen müssten die OSGeoLive-Pakete in eine eigene
  Schicht und Calamares diese zusätzlich kennen. Die Live-Schicht ersetzt dracut
  durch initramfs-tools, deshalb muss das installierte System initramfs-tools nutzen.
- **Einordnung:** upstream-tauglich (Upstream braucht dasselbe für 26.04)
- **Merge:** `build/resolute-base`

### Paketquellen für resolute

- **Dateien:** `bin/setup.sh`, `sources.list.d/`, `app-conf/apt/keyrings/`
- **Was:** Das OSGeoLive-PPA fällt weg (keine Pakete für resolute), ebenso die
  `apt-key`-Aufrufe und die unbenutzte `ubuntugis.list`. Firefox kommt aus dem
  offiziellen Mozilla-Repository (`mozilla.sources`, Schlüssel unter
  `app-conf/apt/keyrings/packages.mozilla.org.asc`, Fingerprint
  `35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3`) statt aus dem Mozilla-Team-PPA.
  CRAN und pgAdmin zeigen auf resolute. `apt-get upgrade` läuft, die Snap-Mounts
  werden aus `/proc/self/mounts` ermittelt statt mit festen Revisionsnummern, die
  Änderung an `20auto-upgrades` nur, wenn die Datei existiert. Paketnamen:
  `7zip` statt `p7zip`, `iw` statt `wireless-tools`, `libieee1284-3t64`.
- **Warum:** `apt-key` gibt es nicht mehr. Der Schlüssel des Mozilla-Team-PPA ist
  RSA 1024, apt 3 verlangt mindestens RSA 2048.
- **Einordnung:** upstream-tauglich
- **Merge:** `build/resolute-base`

### Basis-Pakete und Versionen

- **Dateien:** `bin/base_c.sh`, `bin/base_java.sh`, `bin/base_python.sh`,
  `bin/install_postgis.sh`, `bin/service_postgresql.sh`, `bin/service_tomcat.sh`,
  `bin/inchroot.sh`
- **Was:** `libgdal38` (GDAL 3.12), PostgreSQL 18, OpenJDK 21 statt `default-jdk`
  (dort OpenJDK 25) und als Vorgabe gesetzt, `mappyfile` 1.2.0 per pip (die
  Abhängigkeiten aus Ubuntu). `service_tomcat.sh` nimmt GID 998 nur, wenn sie frei
  ist (unter 26.04 gehört sie `systemd-network`). In `inchroot.sh` heißt die Datei
  `machine-id` statt `machines-id` und wird mit `rm -f` entfernt.
- **Warum:** Die alten Pakete gibt es unter resolute nicht; `default-jdk` zeigte
  bisher dank PPA auf OpenJDK 17.
- **Einordnung:** upstream-tauglich
- **Merge:** `build/resolute-base`

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

### Sicherheitsregeln für Build und KI-Assistenten

- **Dateien:** `AGENTS.md`, `docs/fossgis/build-safety.md`, `docs/fossgis/README.md`
- **Was:** verbindliche Regeln für KI-Assistenten (`AGENTS.md`) und ein Dokument mit
  zwei Vorfällen vom 27.10.2026, den versagten Sicherungen, Regeln für Build-Skripte
  und den Stand der Schutzmaßnahmen.
- **Warum:** Ein Teilbuild löschte über das eingebundene `/dev` die Gerätedateien des
  Build-Rechners; ein danach empfohlener Reparaturbefehl beendete die Sitzung des
  Nutzers. Das darf sich nicht wiederholen.
- **Einordnung:** FOSSGIS-spezifisch (die Build-Regeln sind upstream-tauglich)
- **Merge:** `docs/build-safety`

### Build nur in einer Wegwerf-VM

- **Dateien:** `fossgis/tools/builder_vm.sh`, `fossgis/tools/host_guard.sh`,
  `fossgis/tools/check_clean.allow`, `AGENTS.md`, `docs/fossgis/README.md`,
  `docs/fossgis/build-safety.md`
- **Was:** `builder_vm.sh` startet eine QEMU/KVM-VM ohne gemeinsame Verzeichnisse mit
  dem Host, schickt den committeten Stand als Git-Bundle und `local/` per rsync,
  startet den Build in der VM und holt ISO, Log und neue Cache-Dateien zurück.
  Verbindungen der VM zum Host (10.0.2.2) werden verworfen. `host_guard.sh`
  vergleicht vor und nach dem Build `/dev`, Mounts und freien Platz auf dem Host.
  `AGENTS.md` verbietet Builds direkt auf dem Host.
- **Warum:** Der Build braucht root; Fehler im Chroot dürfen den Build-Rechner nicht
  mehr erreichen können.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `chore/builder-vm`

### Log-Wächter für kritische Build-Meldungen

- **Dateien:** `fossgis/tools/check_build_log.sh`, `bin/build_chroot.sh`,
  `fossgis/tools/record_full_build.sh`, `fossgis/tools/builder_vm.sh`
- **Was:** `check_build_log.sh` sucht im Build-Log nach Meldungen wie
  „target is busy“, „Device or resource busy“, „cannot remove …edit/“ und
  Dateien, die sich während `mksquashfs` ändern. Trifft etwas zu, wird ein
  scheinbar grüner Build (`exit=0`) auf `exit=1` gesetzt. `record_full_build.sh
  green` und `builder_vm.sh fetch` lehnen solche Logs ab.
- **Warum:** Der Vorfall vom 27.10.2026 endete mit `exit=0` trotz „target is busy“
  und gelöschtem `/dev`.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `fix/build-safety-hardening`

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
| Basis | Lubuntu 24.04.2 | Lubuntu 26.04.1 | upstream-tauglich |
| PostgreSQL | 16 | 18 | upstream-tauglich |
| Java | OpenJDK 17 (PPA) | OpenJDK 21 | upstream-tauglich |
| GDAL (Bibliothek) | libgdal37 (3.11, PPA) | libgdal38 (3.12) | upstream-tauglich |
