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

### ISO-Test: VirtualBox statt run_iso.sh

- **Dateien:** `fossgis/tools/run_iso.sh` (entfernt)
- **Was:** Das QEMU/SPICE-Hilfsskript `run_iso.sh` ist entfernt. Gebaute ISOs
  werden lokal in VirtualBox getestet (Maus/Zwischenablage ueber Guest
  Additions bzw. VirtualBox-UI). Die Build-VM bleibt QEMU (`builder_vm.sh`).
- **Warum:** SPICE/Tablet/HiDPI war fehleranfaellig; VirtualBox reicht fuer den
  ISO-Smoke. Kein `spice-vdagent` im Image noetig.
- **Einordnung:** nur FOSSGIS (Werkzeug)
- **Merge:** `fix/otb-env-no-qemu`

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
  `artwork/` und `data/` nach `/usr/local/share/gisvm/fossgis-local` im Container
  (nicht nach `/tmp`, dort hängt nspawn ein tmpfs ein). `inchroot.sh` lädt die Werte
  über `load_edition.sh` und exportiert sie. `setdown.sh` und `inchroot.sh` löschen
  `fossgis-local` am Ende. Mit `local/inchroot.list` laufen nur die dort genannten
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
  Build vor   dem Packen ab. `mksquashfs` läuft mit `-one-file-system`. Einstiegsskripte und
  FOSSGIS-Inputs liegen unter `/usr/local/share/gisvm/` (nicht unter `/tmp`), weil
  nspawn dort ein tmpfs aus der Live-`fstab` einhängt. Die apt-Quelle
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
  Leerzeichen nur gemeldet. Mehrzeilige `Tested:`-Angaben im Merge-Body (ohne
  eingerückte Fortsetzungszeilen) zählen weiterhin; reine Git-Trailer-Erkennung
  würde sie sonst übersehen. `pre-push.hook` ist die Vorlage für `.git/hooks/pre-push`:
  Push nur zu `gislars`, nur mit `FOSSGIS_PUSH_APPROVED=1` und nur mit grünem
  `check_clean.sh`.
- **Warum:** Ins Fork-Repo kommen nur saubere, getestete Commits, und kein Push geht
  ohne ausdrückliche Freigabe raus.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `chore/clean-check`, Nacharbeit `fix/check-clean-tested-body`

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
  `docs/fossgis/build-safety.md`, `bin/build_chroot.sh`,
  `fossgis/tools/tests/test_build_safety.sh`
- **Was:** `builder_vm.sh` startet eine QEMU/KVM-VM ohne gemeinsame Verzeichnisse mit
  dem Host, schickt den committeten Stand als Git-Bundle und `local/` per rsync,
  startet den Build in der VM und holt ISO, Log und neue Cache-Dateien zurück.
  Verbindungen der VM zum Host (10.0.2.2) werden verworfen. `host_guard.sh`
  vergleicht vor und nach dem Build `/dev`, Mounts und freien Platz auf dem Host;
  Hotplug-Knoten (Input, Sound, USB) bleiben beim Vergleich unberücksichtigt.
  Default-RAM der VM ist 32G. DNS: öffentliche Resolver, Stub-Listener aus;
  im Chroot feste `resolv.conf` und `systemd-nspawn --resolv-conf=off` (sonst
  legt nspawn `127.0.0.53` wieder über die Datei und apt scheitert unter Last).
  `AGENTS.md` verbietet Builds direkt auf dem Host.
- **Warum:** Der Build braucht root; Fehler im Chroot dürfen den Build-Rechner nicht
  mehr erreichen können. QEMU-User-Networking und Headset-Hotplug dürfen den
  Guard bzw. den Build nicht falsch scheitern lassen.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `chore/builder-vm`, Nacharbeit `fix/gis-stack-verify`

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

## GIS-Stack

### QGIS 4.2 von qgis.org, GRASS 8.4 und ein GDAL

- **Dateien:** `bin/setup.sh`, `bin/install_qgis.sh`, `bin/install_grass.sh`,
  `bin/check_gis_stack.sh`, `bin/inchroot.sh`, `bin/base_python.sh`,
  `sources.list.d/qgis.sources`, `app-conf/apt/qgis-pin.pref`,
  `app-conf/apt/keyrings/qgis-archive-keyring.gpg`,
  `fossgis/tools/build_qgis_plugins_zip.py`,
  `fossgis/tools/update_qgis_plugins.py`, `fossgis/tools/qgis_plugins_pins.json`
- **Was:** QGIS 4.2 kommt von `qgis.org/debian resolute` (Keyring und Pinning gegen
  Ubuntu-Universe mit QGIS 3.x; Pin nach `o=QGIS project`, nicht nach Hostname,
  weil Redirects die Origin-Zeile brechen). Installiert werden `qgis`,
  `python3-qgis`, `qgis-plugin-grass` (und `qgis-server` weiter in
  `install_qgis_server.sh`). GRASS 8.4 aus Ubuntu ohne `libgdal-grass` (Paket
  fehlt); Desktop-Datei wird dynamisch ermittelt. Teilbuilds mit
  `local/inchroot.list` brechen beim ersten fehlgeschlagenen Schritt ab.
  `check_gis_stack.sh` bricht den Build ab, wenn GDAL nicht 3.12.x, GRASS nicht
  8.4, QGIS nicht 4.2 oder mehr als eine `libgdal*` in den Abhängigkeiten
  vorkommt, und prüft `ldd` am GRASS-Plugin; Versionen kommen robust aus
  Paketmetadaten bzw. `grass --config version` (nicht nur aus Banner-Zeilen).
  Plugin-ZIP für QGIS 4 liegt in `local/data/qgis/` (nicht im Repo). Gepinnte
  Plugin-Versionen stehen in `qgis_plugins_pins.json` (`last_check` ISO-Zeit);
  `update_qgis_plugins.py` holt einmal `plugins.xml?qgis=4.2`, cached unter
  `local/cache/qgis-plugins/` (TTL 24 h, `--force` ignoriert TTL), schreibt
  Pins; `build_qgis_plugins_zip.py` baut das ZIP. Vor jedem
  `builder_vm.sh build` ruft `ensure_qgis_plugins.sh` Update und bei Bedarf
  ZIP-Neubau auf dem Host auf; unveraenderte Pins nutzen das bestehende ZIP.
- **Warum:** Ein einheitlicher Stack ohne UbuntuGIS-PPA; QGIS 4 ist gegen
  `libgdal38` und `grass842` gebaut. Falsch-grüne Teilbuilds und flaky DNS
  im Chroot dürfen den Stack nicht als fertig melden. Plugin-Pins schonend
  gegen Upstream halten, ohne Dauerfeuer einzelner Plugin-Seiten.
- **Einordnung:** upstream-tauglich (QGIS-Quelle und Prüfskript); Plugin-ZIP,
  Pinning und Updater FOSSGIS-spezifisch
- **Merge:** `build/gis-stack`, Nacharbeit `fix/gis-stack-verify`,
  `chore/qgis-plugin-updater`

### check_build_log erkennt Content-Failures aus build126

- **Dateien:** `fossgis/tools/check_build_log.sh`
- **Was:** Zusaetzlich zu Host-Schaeden: `E: Unable to locate package`,
  `E: Package ... has no installation candidate`,
  `patchelf: open: Permission denied`, `First time launching OTB...`,
  `Can not find GDAL bindings at`, `ERROR: install step failed`.
  Damit zaehlt ein Log wie build126 nicht mehr als gruen trotz `exit=0`.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `fix/check-log-content-failures`

### builder_vm findet Build-Logs mit YYYYMMDD-HHMMSS

- **Dateien:** `fossgis/tools/builder_vm.sh`, `bin/build_chroot.sh`
- **Was:** Fallback-Glob war `20*-*-*-osgeolive-*.log` (drei Segmente) und
  matchte nicht `20261028-010032-osgeolive-...` (build126 Host:
  `no build log in the VM`). Neu: `20??????-??????-osgeolive-*.log`.
  `build_chroot.sh` setzt `logs/latest.log` sofort nach Anlegen der Logdatei.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `fix/builder-vm-log-glob`

### builder_vm follow nur aktuelles Log waehrend laufendem Build

- **Dateien:** `fossgis/tools/builder_vm.sh`
- **Was:** Solange `fossgis-build` aktiv ist, warten `follow`/`status`/`vm_build_log`
  nur auf `logs/latest.log` und fallen nicht mehr auf `ls -1t` zurueck (sonst
  haengt follow am vorherigen dated Log, weil Build-Start den Symlink loescht).
  `tail -F` folgt dem Symlink-Pfad.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `fix/builder-vm-follow-current-log`

### GeoServer rm -f fuer fehlende JAR-Globs; pgAdmin Status hart

- **Dateien:** `bin/install_geoserver.sh`, `bin/install_pgadmin.sh`
- **Was:** `rm -f` fuer `parboiled-*-1.2.0.jar` und `gs-web-app-*-SNAPSHOT.jar`
  (build126: Dateien fehlen unter GS 3.0.2). pgAdmin: nach AppArmor-Workaround
  muss `dpkg` Status `install ok installed` sein, sonst Exit 1.
- **Einordnung:** upstream-tauglich
- **Merge:** `fix/geoserver-pgadmin-harden`

### Vollbuild bricht bei Install-Fehlern ab

- **Dateien:** `bin/inchroot.sh`
- **Was:** Der Hauptpfad (ohne `inchroot.list`) ruft jeden Install-Schritt ueber
  `fossgis_run` auf und beendet den Build bei Exit ungleich 0. Vorher liefen
  Skripte ohne `set -e` nach fehlgeschlagenem `apt-get` weiter und meldeten
  trotzdem `Finished` (build126: fehlende Pakete, OTB).
- **Einordnung:** upstream-tauglich
- **Merge:** `fix/inchroot-fail-hard`

## Entfernt oder ersetzt (Ubuntu 26.04)

### Willkommensdialog: gxmessage durch zenity

- **Dateien:** `bin/install_desktop.sh`, `desktop-conf/welcome_message.sh`
- **Was:** `gxmessage` fehlt in 26.04; Welcome-Dialog und Paket nutzen `zenity`.
- **Einordnung:** upstream-tauglich
- **Merge:** `build/resolute-app-ports`

### Leaflet MarkerCluster von Upstream

- **Dateien:** `bin/install_leaflet.sh`
- **Was:** `libjs-leaflet-markercluster` fehlt; Installation von
  Leaflet.markercluster v1.5.3 nach `/usr/share/javascript/leaflet-markercluster/`.
- **Einordnung:** upstream-tauglich
- **Merge:** `build/resolute-app-ports`

### R: sf/terra statt rgdal/rgeos/maptools

- **Dateien:** `bin/install_R.sh`
- **Was:** CRAN hat `rgdal`, `rgeos`, `maptools` entfernt; zusätzlich `r-cran-terra`.
  `r-cran-rgrass` fehlt in 26.04 noch.
- **Einordnung:** upstream-tauglich
- **Merge:** `build/resolute-app-ports`

### Gemeinsame Python-venv und fehlende Debs

- **Dateien:** `bin/tools/osgeolive_venv.sh`, `bin/base_python.sh`,
  `bin/install_mapnik.sh`, `bin/install_osm.sh`, `bin/install_pygeoapi.sh`,
  `bin/install_mapproxy.sh`
- **Was:** venv unter `/opt/osgeolive-venv` für `mappyfile`, `mapnik` (PyPI),
  `nik4`, `pygeoapi`, und Runtime-`mapproxy` (PyPI). System-`libmapnik4.2`
  bleibt; das Mapnik-Wheel kann eine eigene libmapnik/GDAL mitbringen
  (Ausnahme vom einheitlichen GDAL-Stack). Deb-`mapproxy` bleibt fuer Docs;
  `mapproxy_start.sh` nutzt den venv-`mapproxy-util`, sonst scheitert der
  Start an `Could not import Mapnik` (System-Python sieht die venv-Bindings
  nicht). Starter haelt bei Fehler das Terminal offen (Port bleibt 8011).
  Nach `pip install mapproxy` Patch auf `mapproxy/source/mapnik.py`: `map_obj_pid`
  nicht am Mapnik-`Map` setzen (kein `__dict__`, sonst GetMap 500 auf
  `mapnik_tile`), und SRS ohne veraltetes `+init=`.
- **Einordnung:** FOSSGIS-spezifisch (Pfad); Ersatz upstream-tauglich
- **Merge:** `build/resolute-app-ports`, `fix/live-test-blockers`

### Fehlende Resolute-Debs per osgeolive-venv (datacube, ipyleaflet); istsos aus

- **Dateien:** `bin/install_datacube.sh`, `bin/install_jupyter.sh`,
  `bin/install_istsos.sh`, `bin/inchroot.sh`, `bin/tools/osgeolive_venv.sh`
- **Was:** Unter 26.04 fehlen `python3-datacube`, `python3-odc-*`,
  `python3-ipyleaflet` (build126). Installation per `pip` in
  `/opt/osgeolive-venv` (`datacube[postgres]` inkl. `psycopg2-binary`,
  build140). `istsos`: kein Deb und auf PyPI nur ge yankte `3.0.0b1` /
  `No matching distribution` (build138); aus `inchroot.sh` auskommentiert,
  Skript bleibt fuer spaeter.
- **Einordnung:** FOSSGIS-spezifisch; istsos temporaer entfernt
- **Merge:** `fix/venv-missing-pkgs`, `fix/drop-istsos-no-pip`,
  `fix/datacube-psycopg2`

### Mapbender: schreibbare PHP-Sessions fuer www-data

- **Dateien:** `bin/install_mapbender.sh`
- **Was:** HTTP 500 mit Twig `Failed to start the session` /
  `session_start(): Failed to read session data` unter
  `var/sessions/prod`. Install setzte Rechte nur auf cache/log, nicht auf
  Sessions; Apache laeuft als `www-data`. Fix: `var/sessions/prod` anlegen,
  Sessions/Cache/Log `chown www-data` und `chmod ug+rwX`.
- **Einordnung:** FOSSGIS-Build-Fix; upstream-tauglich
- **Merge:** lokal

### JOSM: Upstream-APT + kein globales _JAVA_OPTIONS

- **Dateien:** `bin/install_osm.sh`, `bin/base_java.sh`
- **Was:** Ubuntu-`josm` (z.B. svn19481) hinter getestetem Upstream; Dialog
  „Missing JVM Arguments“, weil `base_java.sh` `_JAVA_OPTIONS` in
  `/etc/environment` setzte und der JOSM-Starter die Java-Version per
  `head -n1` auf `java -version` liest (erste Zeile ist dann „Picked up
  _JAVA_OPTIONS…“). Fix: Schriftglättung (#2478) über
  `$JAVA_HOME/lib/swing.properties` statt `_JAVA_OPTIONS`; JOSM aus
  `josm.openstreetmap.de/apt` (Suite = `lsb_release -sc`, Pin 700);
  `/etc/default/josm` setzt `--add-exports=…` zusätzlich ab.
- **Einordnung:** FOSSGIS / Live-tauglich; Upstream-JOSM-Repo empfohlen
- **Merge:** lokal

### pycsw Runtime im osgeolive-venv (kein Dist-Patch)

- **Dateien:** `bin/install_pycsw.sh`, `app-conf/pycsw/` (`wsgi.py`, `default.cfg`,
  `apache-pycsw.conf`)
- **Was:** Deb-`python3-pycsw` 2.6.2 ist unter Resolute kaputt (kein stdlib
  `cgi`, inkompatibel mit System-SQLAlchemy 2.0; Upstream-Issue #1012, Fix
  dort ausstehend). Statt Dateien in `dist-packages` zu patchen: Runtime in
  `/opt/osgeolive-venv` mit `pycsw==2.6.2`, `SQLAlchemy>=1.4,<2`,
  `legacy-cgi`, `setuptools>=65,<82` (`pkg_resources`; 82+ entfernt das Modul,
  build155);
  Apache `WSGIDaemonProcess` mit `python-home` und eigener WSGI-/Config unter
  `app-conf/pycsw/`. Deb-Pakete bleiben fuer Demo-DB und Docs. Deb-`pycsw-wsgi`
  wird per `a2disconf` zugunsten von `osgeolive-pycsw` abgeschaltet.
- **Einordnung:** FOSSGIS-Workaround bis Deb/Upstream SA2 + cgi liefern
- **Merge:** lokal

### Firefox Deutsch ohne firefox-locale-de

- **Dateien:** `bin/install_locale.sh`
- **Was:** Nach Wechsel auf das Mozilla-Firefox-Deb hat `firefox-locale-de`
  keinen apt-Kandidaten (build126). Zuerst restliche DE-Pakete; dann Versuch
  `firefox-locale-de`, sonst Langpack-XPI von
  `ftp.mozilla.org/.../xpi/de.xpi` nach
  `/usr/lib/firefox/distribution/extensions/`. Policy `RequestedLocales: ["de"]`
  bleibt. Scheitert beides, bleibt die UI englisch (dokumentiert), Firefox
  bleibt lauffaehig.
- **Einordnung:** FOSSGIS-spezifisch / temporaer
- **Merge:** `fix/venv-missing-pkgs`

### OTB als offizielles Linux-Binary

- **Dateien:** `bin/install_otb.sh`
- **Was:** `libotb`/`monteverdi` fehlen; OTB 9.1.1 von
  `orfeo-toolbox.org/packages/OTB-9.1.1-Linux.tar.gz` nach
  `/usr/local/lib/OTB-9.1.1`. Postinstall (cmake-Pfad, `sanitize_rpath`)
  laeuft einmal als root; Marker `tools/install_done.txt`. Globales
  `/etc/profile.d/otb.sh` setzt nur `OTB_INSTALL_DIR` (kein
  `PYTHONPATH`/`LD_LIBRARY_PATH`/`GDAL_*`): sonst ueberschattet OTBs
  unvollstaendiges `osgeo` das System-`python3-gdal` und QGIS meldet
  `No module named _gdal`. Volle OTB-Env nur in
  `/usr/local/bin/otb-env.sh` und den Wrappern `monteverdi`/`mapla`/`otbcli*`.
  Upstream liefert kein `OTB-9.1-GDAL-bindings-py314.tar.gz`; Python-OTB
  bleibt unter Resolute unvollstaendig, CLI/Mapla/Monteverdi bleiben nutzbar.
- **Einordnung:** upstream-tauglich (Binary + root-Postinstall); py314-Luecke temporaer
- **Merge:** `build/resolute-app-ports`, `fix/otb-root-postinstall`,
  `fix/otb-env-no-qemu`

### OSSIM und PDAL vorerst ausgelassen

- **Dateien:** `bin/install_ossim.sh`, `bin/install_PDAL.sh`
- **Was:** Keine Ubuntu-Pakete und kein gepflegtes Live-Binary; Skripte
  überspringen mit Hinweis. PDAL folgt, sobald ein pinbares Binary feststeht.
- **Einordnung:** temporär
- **Merge:** `build/resolute-app-ports`

## Offline-Doku

### Vorgebaute Sphinx-HTML statt PPA

- **Dateien:** `fossgis/build_docs.sh`, `bin/install_docs.sh`, `bin/build_chroot.sh`,
  `fossgis/edition.conf` (`DOCS_COMMIT`)
- **Was:** `osgeolive-doc/` (Fork) wird auf dem Host in `ubuntu:24.04` nach
  `local/data/docs/html` gebaut. Der ISO-Build verlangt passende `COMMIT` und
  kopiert die HTML-Dateien; kein stiller Rueckfall auf das PPA, wenn
  `DOCS_COMMIT` gesetzt ist. Desktop-Hilfe startet auf `/osgeolive/de/`.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** Offline-Doku (osgeolive-doc + Haupt-Repo)

## Build-Dokumentation

### README fuer FOSSGIS-Build und Jahres-Checkliste

- **Dateien:** `docs/fossgis/README.md`
- **Was:** Voraussetzungen, `local.env`, `prepare_data.sh`, Artwork, Branch-Workflow
  und Checkliste fuer das Folgejahr.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `docs/fossgis-build`

## Branding FOSSGIS 2027

### Texte, ISO-Suffix, Wallpaper-Fallback, Workshop-Icon

- **Dateien:** `fossgis/edition.conf`, `CHANGES.txt`, `desktop-conf/welcome_message.txt`,
  `bin/install_desktop.sh`, `bin/install_icons_and_menus.sh`, `bin/build_chroot.sh`
- **Was:** Begruessung und Calamares-Label aus `EDITION_NAME`. Release-ISO heisst
  `osgeolive-17.0-fossgis2027-amd64`. Wallpaper aus `local/artwork/` mit Fallback
  auf `desktop-conf/osgeo-desktop.png`. Workshop-Downloads-Icon nur wenn
  `WORKSHOP_URL` gesetzt ist.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `feature/fossgis2027-branding`

## Optionales WLAN

### Venue-Profil aus local.env

- **Dateien:** `bin/install_wifi.sh`, `bin/inchroot.sh`, `fossgis/local.env.example`,
  `docs/fossgis/README.md`
- **Was:** Wenn `WIFI_SSID` und `WIFI_PSK` gesetzt sind, schreibt das Skript ein
  NetworkManager-Profil. Sonst Skip mit Logzeile. Sicherheitshinweis in der README.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `feature/wifi-optional`

## Deutsche Systemvorgaben

### Locale, Tastatur, Zeitzone, Calamares, pgAdmin

- **Dateien:** `bin/install_locale.sh`, `bin/inchroot.sh`, `bin/build_chroot.sh`,
  `bin/install_desktop.sh`, `bin/install_pgadmin.sh`, `fossgis/edition.conf`,
  `desktop-conf/calamares/modules/locale.conf`,
  `desktop-conf/calamares/modules/keyboard.conf`, `app-conf/qgis/QGIS3.ini`
- **Was:** `install_locale.sh` setzt `de_DE.UTF-8`, QWERTZ, Europe/Berlin, A4,
  Sprachpakete und haltet XDG-Ordner auf englisch (`Desktop`). Casper-Bootparameter
  und Calamares-Module vorbelegen Deutsch/Berlin. QGIS `userLocale=de`. pgAdmin
  ohne Master-Passwort und mit `--no-sandbox`. Keyring-Unlock beim Login.
- **Warum:** Workshop-Laptops sollen ohne Nachkonfiguration deutsch starten.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `feature/german-defaults`

## Konferenzstadt OSM

### Heidelberg-Extrakt (PBF + XML vor dem Build)

- **Dateien:** `fossgis/prepare_data.sh`, `bin/extract_osm_by_relation.py`,
  `bin/README_extract_osm_by_relation.md`, `fossgis/edition.conf`,
  `bin/install_osm.sh`, `bin/load_postgis.sh`, `bin/install_pgrouting.sh`,
  `bin/build_chroot.sh`
- **Was:** Auf dem Host erzeugt `prepare_data.sh` aus dem Geofabrik-PBF und der
  Relation `OSM_RELATION` die Dateien `local/data/osm/<MAP_CITY>.osm.pbf`,
  `.osm` und `.stamp`. Der Build bricht ohne passende Dateien ab. Im Image liegt
  nur die PBF-Datei als `feature_city.osm.pbf`; das XML dient osm2pgrouting und
  bleibt in `fossgis-local` (nicht im ISO). `load_postgis.sh` importiert die PBF
  mit osm2pgsql **flex** und `app-conf/osm2pgsql/osgeolive.lua` (SRID 4326,
  kompatibel zu `default.style`). Leaflet bekommt `map_location.js` aus den
  `MAP_*`-Werten. Mindestschema: `fossgis/reference/osm_local_contract.txt`.
  Der vollstaendige Schema-Vergleich 1.11 gegen 2.2 folgt als manueller Test.
- **Warum:** Konferenzstadt statt Auckland; kein bz2 mehr im Image; pgsql-Ausgabe
  von osm2pgsql 2.x ist veraltet.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `feature/osm-heidelberg`

## Workshop-Werkzeuge

### Docker, Node.js (NVM) und VS Code

- **Dateien:** `bin/install_docker.sh`, `bin/install_node.sh`, `bin/install_vscode.sh`,
  `bin/setup.sh`, `bin/setdown.sh`, `bin/inchroot.sh`, `sources.list.d/docker.list`,
  `sources.list.d/vscode.list`
- **Was:** Docker CE aus dem offiziellen Repo (`resolute`), Node.js aktuelle LTS
  (Major 24) per NVM, VS Code aus dem Microsoft-Repo. Die Quellen werden in
  `setup.sh` unabhaengig vom Build-Modus eingebunden. `apt-get` nutzt `--yes`.
  VS Code startet im Live-System mit `--no-sandbox` (Desktop-Eintrag). Die
  `docker`-Gruppe wird in `setdown.sh` per oneshot-Service nachgezogen, weil
  Casper die Gruppenmitgliedschaft sonst verlieren kann. Nach der NVM-Installation
  werden `.nvm/.git` und `.nvm/test` entfernt; sonst scheitert
  `deluser --remove-home` an Testpfaden mit Anführungszeichen und Nicht-ASCII.
- **Warum:** Workshops brauchen Container, aktuelle Node-Toolchain und einen Editor.
- **Einordnung:** FOSSGIS-spezifisch
- **Merge:** `feature/extra-software`

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
| GRASS | 8.4 (PPA/Pinning) | 8.4.2 (Ubuntu) | upstream-tauglich |
| QGIS | 3.40 (PPA) | 4.2.x (qgis.org resolute) | upstream-tauglich |
| GeoServer | 2.27.x | 3.0.2 | upstream-tauglich |
| OpenLayers | 6.14.1 | 10.11.0 | upstream-tauglich |
| QField | v4.1.9 | v4.3.7 | upstream-tauglich |
| Cesium | 1.132 | 1.146 | upstream-tauglich |
| deegree | 3.6.0-pre2 | 3.6.13 | upstream-tauglich |
| Mapbender | 4.2.3 | 5.0.2 | upstream-tauglich |
