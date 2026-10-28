# Kritische Logzeilen sind ein Fehlschlag

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Der Vorfall vom 27.10.2026 endete mit `exit=0`, obwohl das Log „target is
busy“ und „cannot remove“ enthielt und `/dev` des Build-Rechners beschädigt
war. Exit-Code und grüne Meldung haben den Schaden nicht angezeigt.
`check_clean.sh` und `shellcheck` prüfen den Lauf nicht.

## Entscheidung

`fossgis/tools/check_build_log.sh` wertet das Build-Log aus. Treffer wie
„target is busy“, „Device or resource busy“, „cannot remove“ unter `edit/`
oder Dateien, die sich während `mksquashfs` ändern, setzen einen Lauf mit
`exit=0` auf Fehlschlag.

`fossgis/tools/record_full_build.sh green` und `builder_vm.sh fetch` lehnen
solche Logs ab. Ein Build mit diesen Meldungen ist nicht grün, auch wenn
das Skript `exit=0` meldet.

Unerklärte Fehler dieser Art stoppen die weitere Arbeit, bis die Ursache
klar ist. Sie werden nicht als Eigenheit der Sandbox oder als harmlos
abgetan, solange das nicht belegt ist.

## Konsequenzen

Ein erfolgreicher Build braucht ein Log ohne diese Muster, nicht nur einen
Exit-Code. `record_full_build.sh` kann einen solchen Lauf nicht als
Vollbuild-Nachweis speichern.

Die Musterliste ist endlich. Ein neues Schadensbild braucht einen neuen
Eintrag in `check_build_log.sh` und einen Nachtrag hier oder eine neue
Entscheidung. Die Liste ersetzt nicht die Grenze in
[build-only-in-a-vm.md](build-only-in-a-vm.md) und nicht das private `/dev`
aus
[keep-host-devices-out-of-the-chroot.md](keep-host-devices-out-of-the-chroot.md).
