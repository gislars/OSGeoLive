# Anweisungen für KI-Assistenten

Diese Regeln sind verbindlich für jede KI, die in diesem Repository arbeitet. Sie
stammen aus zwei Vorfällen am 27.10.2026, bei denen ein KI-Assistent den
Build-Rechner des Nutzers beschädigt und danach seine laufende Sitzung beendet hat;
offene Arbeit ging verloren. Hintergrund: [docs/fossgis/build-safety.md](docs/fossgis/build-safety.md).

Der Build-Rechner ist der persönliche Rechner des Nutzers. Ein Neustart, ein
Ausloggen oder beendete Programme sind ein schwerer Schaden, kein kleiner Preis.

## Grundsatz

Vorsicht geht vor Tempo. Im Zweifel nicht ausführen und nicht empfehlen, sondern
fragen. Lieber eine Aufgabe unerledigt lassen als den Rechner des Nutzers gefährden.

## Befehle

1. Vor jedem Befehl auf der Kommandozeile fragen, auch bei rein lesenden.
2. Keine Befehle ausführen oder empfehlen, die in das laufende System eingreifen:
   udev (`udevadm trigger`, `udevadm control`), systemd (`systemctl`,
   `systemd-tmpfiles`, `loginctl`), Mounts außerhalb von `build/`, `mknod`,
   Kernelmodule, Netzwerk- oder Sitzungsdienste. Auch nicht als „Reparatur“.
3. Ist der Rechner beschädigt: Der Nutzer speichert zuerst seine Arbeit, dann folgt
   ein geplanter Neustart. Keine eigenen Reparaturversuche am laufenden System.
4. Jeder Befehl, den der Nutzer mit `sudo` ausführen soll, kommt mit:
   was er verändert, was im schlimmsten Fall passiert, was vorher zu sichern ist.
   Ist die Wirkung nicht sicher abschätzbar, das genau so sagen und den Befehl
   nicht empfehlen.
5. Nie behaupten, ein Befehl sei harmlos oder Programme liefen weiter, ohne dass
   genau dieser Befehl mit genau dieser Wirkung geprüft wurde. Ein Probelauf, der
   nur einen Teil abdeckt, beweist nichts über den Rest; den ungeprüften Teil nennen.

## Build

6. Kein Build-Befehl an den Nutzer, bevor die Sicherheitstests bestanden sind
   (`fossgis/tools/tests/test_build_safety.sh`, sobald vorhanden; bis dahin keine
   Builds mit Änderungen an Mounts, Chroot oder Aufräumen).
7. Jede Änderung an `mount`, `umount`, `rm`, `chroot`, `systemd-nspawn` oder `sudo`
   in Build-Skripten ausdrücklich benennen, mit Risiko für den Build-Rechner.
8. Nichts vom Build-Rechner in den Chroot einbinden, das beim Löschen oder Packen
   Schaden anrichten kann, insbesondere nicht das echte `/dev`.
9. Verzeichnisse mit Mounts darunter nie mit `rm -rf` löschen; immer erst aushängen,
   prüfen, dann `rm -rf --one-file-system`.
10. Teilbuilds (`local/inchroot.list`) dürfen keine Dienste im Chroot laufen lassen;
    gestartete Dienste müssen vor Ende des Chroot-Teils gestoppt sein.

## Auffälligkeiten

11. Unerwartete Fehler in eigenen Werkzeugen oder im Log (zum Beispiel
    „/dev/null: Permission denied“, „target is busy“, „cannot remove“) sofort melden
    und die Arbeit anhalten. Nie ohne Beleg der Sandbox oder einem harmlosen Grund
    zuschreiben.
12. Ein Build mit solchen Meldungen ist nicht grün, auch wenn er `exit=0` meldet.

## Repository

13. Nie zu `https://github.com/OSGeo/OSGeoLive` committen oder pushen. Einziges
    Ziel ist `https://github.com/gislars/OSGeoLive`; lesen ist erlaubt.
14. Kein Push ohne ausdrückliche Freigabe des Nutzers. Lokale Commits sind erlaubt,
    nur saubere und getestete (`fossgis/tools/check_clean.sh`).
