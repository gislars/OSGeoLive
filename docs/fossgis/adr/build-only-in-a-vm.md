# Build nur in einer VM

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

`bin/build_chroot.sh` läuft mit root. Der Rechner, auf dem gebaut wird, ist
der Arbeitsrechner. Am 27.10.2026 hat ein Teilbuild über ein eingehängtes
`/dev` Gerätedateien dieses Rechners gelöscht. Ein anschließender
Reparaturversuch hat die grafische Sitzung beendet. Hintergrund:
[build-safety.md](../build-safety.md).

Root auf dem Host und ein Chroot, der Dateien des Hosts sehen kann, reichen
als Grenze nicht. Ein Kommentar im Skript hat den Schaden nicht verhindert.

## Entscheidung

Gebaut wird nur über `fossgis/tools/builder_vm.sh` in einer QEMU/KVM-VM.
Auf dem Host startet die VM als normaler Benutzer. root gilt nur in der VM.

Die VM teilt keine Verzeichnisse mit dem Host. Hinein gehen ein Git-Bundle
des committeten Stands (`HEAD`) und `local/` per rsync. Zurück kommen ISO,
Log und neue Dateien für `local/cache/`. Verbindungen der VM zum Host
(10.0.2.2) werden in der VM verworfen, ssh lauscht nur auf 127.0.0.1.
CPU, Arbeitsspeicher und Platte sind begrenzt.

`fossgis/tools/host_guard.sh` vergleicht vor und nach jedem Build `/dev`,
Mounts und freien Platz auf dem Host. Hotplug-Knoten (Input, Sound, USB)
werden aus dem `/dev`-Vergleich ausgenommen, damit Headset und Stick während
eines langen Builds kommen und gehen dürfen. `builder_vm.sh fetch` bricht ab,
wenn dieser Vergleich scheitert.

`sudo ./bin/build_chroot.sh` auf dem Host ist untersagt, auch für Teilbuilds
und kurze Läufe.

## Konsequenzen

Ein Fehler im Chroot bleibt in der VM, solange die VM keine Verzeichnisse
teilt und `host_guard.sh` nach dem Zurückkopieren besteht. Diese Grenze
wird nicht gelockert.

Gebaut werden kann nur, was committet ist. Lokale, uncommittete Skriptänderungen
laufen nicht mit.

Die VM ersetzt die Vorsicht im Chroot nicht. Weiterhin gelten
[keep-host-devices-out-of-the-chroot.md](keep-host-devices-out-of-the-chroot.md)
und
[treat-critical-log-lines-as-build-failure.md](treat-critical-log-lines-as-build-failure.md).
Ein grünes Log aus einer kaputten VM ist kein erfolgreicher Build.
`host_guard.sh` prüft den Host. Er prüft nicht, ob das ISO in sich stimmt.
