# Lubuntu-Schichten zu einem Squashfs zusammenführen

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Die FOSSGIS-Ausgabe 2027 steht auf Lubuntu 26.04.1 (Resolute). Das
Lubuntu-ISO hat statt einer `filesystem.squashfs` drei Schichten:
`minimal`, `minimal.standard`, `minimal.standard.live`. OSGeoLive 17.0 und
Calamares erwarten eine einzelne `filesystem.squashfs`. Die Live-Schicht
ersetzt dracut durch initramfs-tools.

Eine eigene OSGeoLive-Schicht würde den Build und Calamares auf das
Schichtenmodell festlegen. Upstream braucht für 26.04 dieselbe Entscheidung.
Details der Umsetzung stehen in [upstream-diff.md](../upstream-diff.md).

## Entscheidung

`bin/build_chroot.sh` hängt die drei Schichten per overlayfs zusammen,
kopiert sie nach `edit/` und packt am Ende eine `filesystem.squashfs`, wie
bisher. `conf/conf.d/default-layer.conf` fliegt aus der initrd, damit casper
diese eine Datei nimmt.

Für das installierte System gilt initramfs-tools, nicht dracut: Calamares
bekommt `initramfs` und `initramfscfg` statt `dracut` und `dracutlukscfg`,
`unpackfs.conf` nennt nur `filesystem.squashfs`, `stacked_squashfs.flag`
entfällt.

Ein ISO ohne Schichten wird wie bisher verarbeitet. Fehlt nach dem Entpacken
der initrd `main/conf`, bricht der Build ab.

## Konsequenzen

Installer, casper und die bisherige Packkette bleiben bei einer Datei. Der
Preis ist ein vollständiges Kopieren der zusammengeführten Schichten nach
`edit/` und das Wissen über die drei Dateinamen und über initramfs-tools.

Zieht Ubuntu das Schichtenmodell wieder ein oder ändert die Namen, muss
diese Entscheidung neu geprüft und entweder ergänzt oder durch eine neue
Datei ersetzt werden. Die Paketquellen für Resolute (Wegfall des
OSGeoLive-PPA, Mozilla-Repository statt Team-PPA) sind eine Folge der
Basis, keine eigene Architekturentscheidung. Sie bleiben in
`upstream-diff.md`.
