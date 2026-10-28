# Host-Geräte bleiben außerhalb des Chroot

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Upstream bindet das echte `/dev` in den Chroot (`mount --bind /dev edit/dev`).
`edit/dev` und `/dev` sind dann dasselbe Dateisystem. Am 27.10.2026 hielt
PostgreSQL aus einem Teilbuild Dateien unter `edit/dev` offen, `umount`
scheiterte mit „target is busy“, das Skript lief weiter, `mksquashfs` packte
das `/dev` des Rechners, und `rm -rf edit` löschte darüber die Gerätedateien.
`rm -rf` ohne `--one-file-system` überschreitet Mount-Grenzen. Der Build
meldete `exit=0`.

Volle Builds traf es nicht, weil `setdown.sh` PostgreSQL stoppt. Der Teilbuild
enthielt `setdown.sh` nicht.

## Entscheidung

Der Inchroot-Teil läuft in `systemd-nspawn` mit privatem `/dev` und privaten
Mounts. Das echte `/dev` des Rechners, auf dem der Build läuft, wird nicht
eingebunden. Cache-Verzeichnisse kommen nur für die Laufzeit des Containers
per `--bind`. Mit dem Container enden auch übrig gebliebene Prozesse.

`edit/` wird nur über `remove_chroot` gelöscht: aushängen, prüfen, dann
`rm -rf --one-file-system`. Ein gescheitertes `umount` beendet den Build.
Bleibt etwas eingehängt oder läuft noch ein Prozess mit Wurzel im Baum,
bricht der Build vor dem Packen ab.

`mksquashfs` läuft nur, wenn unter `edit/` nichts mehr eingehängt ist, und
mit `-one-file-system`.

Ein Teilbuild (`local/inchroot.list`), der einen Dienst startet, endet mit
`setdown.sh`. Nach dem Inchroot-Teil darf kein Prozess aus dem Chroot mehr
laufen.

## Konsequenzen

Löschen und Packen können das `/dev` des Rechners nicht mehr über eine
Bindung erreichen. Das gilt in der Build-VM genauso wie es auf dem Host
hätte gelten müssen. Siehe
[build-only-in-a-vm.md](build-only-in-a-vm.md).

Teilbuilds, die Dienste starten und `setdown.sh` vergessen, werden rot,
bevor ein Image entsteht.

`fossgis/tools/tests/test_build_safety.sh` prüft die Regeln an einer Attrappe.
Ein bestandener Test der Attrappe sagt nichts über einen konkreten
Build-Lauf. Dafür gilt
[treat-critical-log-lines-as-build-failure.md](treat-critical-log-lines-as-build-failure.md).
