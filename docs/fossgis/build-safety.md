# Sicherheit des Build-Rechners

Der Build läuft mit root-Rechten auf dem Rechner, auf dem auch gearbeitet wird. Ein
Fehler im Build oder in einer Empfehlung kann diesen Rechner beschädigen. Dieses
Dokument hält zwei Vorfälle fest, die daraus folgenden Regeln und den Stand der
Schutzmaßnahmen. Die Regeln für KI-Assistenten stehen zusätzlich in
[`AGENTS.md`](../../AGENTS.md).

## Vorfall 1: `/dev` des Build-Rechners gelöscht

Erster Teilbuild auf Lubuntu 26.04.1, 27.10.2026, Branch `build/resolute-base`.

1. `bin/build_chroot.sh` bindet das echte `/dev` in den Chroot ein
   (`mount --bind /dev/ edit/dev`, von Upstream). `edit/dev` und `/dev` sind dasselbe
   Dateisystem.
2. `bin/service_postgresql.sh` startet PostgreSQL im Chroot, gestoppt wird es erst in
   `bin/setdown.sh`. Die Teilbuild-Liste enthielt `setdown.sh` nicht.
3. PostgreSQL hielt Dateien unter `edit/dev` offen, `umount edit/dev` scheiterte mit
   „target is busy“.
4. Das Skript prüfte den Exit-Code nicht und lief weiter. `mksquashfs` packte das
   `/dev` des Rechners ins Image, danach löschte `sudo rm -rf edit` über die Bindung
   fast alle Gerätedateien des Rechners. `rm -rf` überschreitet ohne
   `--one-file-system` Mount-Grenzen.
5. Der Build meldete trotzdem `exit=0`.

Frühere Builds lösten das nicht aus: Volle Builds stoppen PostgreSQL in
`setdown.sh`, frühere Teilbuilds starteten keinen Dienst.

## Vorfall 2: Sitzung durch einen Reparaturbefehl beendet

Um einen Neustart zu vermeiden, empfahl der KI-Assistent ein Skript, das die
Gerätedateien aus `/sys` neu anlegt und danach `systemd-tmpfiles --boot` und
`udevadm trigger --action=add` ausführt. Geprüft war nur der lesende Teil. Der
Assistent behauptete, laufende Programme liefen weiter. Nach dem Ausführen wurde die
grafische Sitzung beendet, alle Programme wurden ohne Möglichkeit zum Speichern
geschlossen. Wahrscheinliche Ursache: `udevadm trigger --action=add` meldet Grafik,
Eingabegeräte und Terminals des laufenden Systems als neu angeschlossen.

Ein geplanter Neustart nach dem Speichern wäre der richtige Weg gewesen.

## Warum die vorhandenen Sicherungen versagt haben

| Sicherung | Warum sie nicht griff |
|---|---|
| Kommentar in `build_chroot.sh`, vor dem Löschen auszuhängen | nur Text, keine Prüfung |
| Aufräumen am Anfang mit `umount -l` | betraf nur Reste früherer Läufe, nicht das Löschen nach `mksquashfs` |
| Prüfung der Cache-Mounts vor dem Löschen | nur für den Download-Cache gebaut, `/dev` nicht bedacht |
| `check_clean`, `sh -n`, `shellcheck` | prüfen Syntax und Stil, nicht die Wirkung zur Laufzeit |
| Build-Log mit Exit-Code | `exit=0` trotz „target is busy“ und „cannot remove“ |
| Teilbuild-Liste | startete einen Dienst ohne ihn zu stoppen |
| Auswertung durch den Assistenten | Meldungen „/dev/null: Permission denied“ der Sandbox zugeschrieben statt anzuhalten |
| Probelauf des Reparaturskripts | deckte die eingreifenden Schritte nicht ab; trotzdem als sicher dargestellt |

## Regeln

### Für Build-Skripte

- Nichts vom Build-Rechner in den Chroot einbinden, das beim Löschen oder Packen
  Schaden anrichten kann, vor allem nicht das echte `/dev`.
- Verzeichnisse mit Mounts darunter nie direkt löschen: aushängen, prüfen, dann
  `rm -rf --one-file-system`. Bleibt etwas eingehängt, bricht der Build ab.
- Ein gescheitertes `umount` beendet den Build.
- `mksquashfs` nur, wenn unter `edit/` nichts mehr eingehängt ist, und mit
  `-one-file-system`.
- Nach dem Chroot-Teil darf kein Prozess aus dem Chroot mehr laufen, auch bei
  Teilbuilds.
- Meldungen wie „target is busy“, „cannot remove 'edit/“ oder „Device or resource
  busy“ machen einen Build rot, unabhängig vom Exit-Code.

### Für die Arbeit am Build-Rechner

- Keine Eingriffe in das laufende System als Reparatur (udev, systemd, `mknod`,
  Mounts außerhalb von `build/`). Ist der Rechner beschädigt: Arbeit speichern, dann
  geplanter Neustart.
- Jeder `sudo`-Befehl wird mit seiner Wirkung, dem schlimmsten Fall und dem, was
  vorher zu sichern ist, angekündigt.
- Kein Befehl gilt als harmlos, solange nicht genau seine Wirkung geprüft ist.
- Unerklärte Fehler stoppen die Arbeit, bis die Ursache geklärt ist.

## Schutzmaßnahmen

Die wichtigste Grenze ist die Build-VM: `build_chroot.sh` läuft nur noch in einer
QEMU/KVM-VM (`fossgis/tools/builder_vm.sh`), die als normaler Benutzer startet.
root gilt nur in der VM. Die VM teilt kein Verzeichnis mit dem Host; Quellen gehen
als Git-Bundle des committeten Stands hinein, `local/` per rsync. Zurück kommen nur
ISO, Log und neue Dateien für `local/cache/`. Verbindungen der VM zum Host
(10.0.2.2) werden in der VM verworfen, ssh lauscht nur auf 127.0.0.1. CPU,
Arbeitsspeicher und Plattengröße der VM sind begrenzt, vor dem Start und vor dem
Zurückkopieren wird der freie Platz geprüft. `host_guard.sh` vergleicht vor und nach
jedem Build `/dev`, Mounts und freien Platz auf dem Host.

Die übrigen Maßnahmen schützen innerhalb der VM davor, dass ein fehlerhafter Build
als grün gilt.

| Maßnahme | Stand |
|---|---|
| Build-VM `fossgis/tools/builder_vm.sh` | getestet 27.10.2026 (create/start, Host-Ports gesperrt, Teilbuilds) |
| `fossgis/tools/host_guard.sh` snapshot/check auf dem Host | getestet 27.10.2026 (positiv und negativ) |
| `remove_chroot`: aushängen, prüfen, `rm -rf --one-file-system` | in `build/resolute-base`, im VM-Teilbuild genutzt |
| belegtes `edit/dev`: lazy aushängen; Prozesse im Chroot brechen den Build ab | getestet: Teilbuild ohne `setdown.sh` -> `exit=1` vor dem Packen |
| Abbruch vor `mksquashfs`, wenn unter `edit/` etwas eingehängt ist | in `build/resolute-base` |
| Chroot-Teil in `systemd-nspawn` (eigenes `/dev`, eigene Mounts, alle Prozesse enden mit dem Container) | geplant |
| `mksquashfs -one-file-system`, gescheitertes `umount` bricht ab | geplant |
| Log-Wächter: kritische Meldungen machen den Build rot, `record_full_build.sh` lehnt ab | geplant |
| `fossgis/tools/tests/test_build_safety.sh` mit einer Attrappe statt `/dev`: belegter Mount beim Aufräumen, `mksquashfs` über Mount-Grenzen, Mounts nach dem Container, übrig gebliebene Prozesse, statische Prüfung von `build_chroot.sh` | geplant; Vorprüfung vor jedem Build, statischer Teil in `check_clean` |

Direkte Builds auf dem Host gibt es nicht mehr. Builds laufen nur über
`fossgis/tools/builder_vm.sh`.
