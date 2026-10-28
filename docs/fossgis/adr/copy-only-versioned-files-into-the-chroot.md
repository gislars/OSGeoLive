# Nur versionierte Dateien in den Chroot

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Früher packte der Build den ganzen Checkout per `tar` in den Chroot. Darin
liegen lokale Daten, Zugangsdaten, ISOs, der Referenz-Checkout
`osgeolive_old/` und das Build-Verzeichnis. All das wäre im ISO gelandet.
Upstream klont außerdem nach `/usr/local/share/gisvm` und setzt einen
Host-Benutzer `user` voraus. Beides haben wir nicht.

## Entscheidung

`bin/build_chroot.sh` kopiert nur versionierte und nicht ignorierte Dateien
(`git ls-files --cached --others --exclude-standard`) nach
`/usr/local/share/gisvm` im Chroot. Der Build bricht ab, wenn in dieser Kopie
`osgeolive_old`, `local`, `osgeolive-doc`, `local.env`, `build`,
`*.nmconnection`, `*.pbf` oder `*.iso` auftauchen.

`bootstrap.sh` überspringt den Klon auch dann, wenn die Kopie kein `.git`
hat. Im Chroot gilt `USER_NAME=user`. Das vom Host durchgereichte
`SUDO_USER` wird entfernt.

Jahreswerte und die erlaubten lokalen Eingaben kommen auf einem eigenen Weg
nach `/tmp/fossgis`, nicht über diese Kopie. Siehe
[split-edition-settings-from-local-inputs.md](split-edition-settings-from-local-inputs.md).

## Konsequenzen

Secrets, Kartendaten und alte Checkouts bleiben außerhalb des Images, solange
sie nicht versioniert sind und die Abbruchliste sie erkennt. Eine neue
sensible Dateiart muss auf diese Liste, sonst schützt sie nur `.gitignore`.

Der Build sieht unversionierte Skriptänderungen nicht. Das passt zur VM, die
den committeten Stand schickt. Siehe
[build-only-in-a-vm.md](build-only-in-a-vm.md).
