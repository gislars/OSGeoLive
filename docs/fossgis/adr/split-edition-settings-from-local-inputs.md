# Jahreswerte und lokale Eingaben trennen

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Name, Ort, OSM-Relation und Karte ändern sich mit jeder FOSSGIS-Ausgabe.
Zugangsdaten, Artwork, große Daten und die Liste für einen Teilbuild ändern
sich lokal und gehören nicht ins Repository. Beides fest in `bin/` zu
schreiben vermischt Konferenzdaten mit dem Build und würde Secrets
committen.

## Entscheidung

Was sich jedes Jahr ändert, steht in `fossgis/edition.conf` und ist
versioniert.

Secrets und lokale Eingaben liegen unter `local/`, das nicht versioniert
ist: `local.env`, `inchroot.list`, `artwork/`, `data/`. Die Vorlage ist
`fossgis/local.env.example`. `local/docs/` wird nicht kopiert.

`bin/build_chroot.sh` kopiert `edition.conf` und die genannten Einträge aus
`local/` nach `/tmp/fossgis` im Chroot. `local.env` liegt dort mit den
Rechten `600`. `bin/inchroot.sh` lädt beides über `fossgis/load_edition.sh`
und exportiert die Werte. `bin/setdown.sh` und `inchroot.sh` löschen
`/tmp/fossgis` am Ende.

Liegt `local/inchroot.list` vor, führt `inchroot.sh` nur die dort genannten
Skripte aus, in dieser Reihenfolge, statt der normalen Liste. Dienste, die
dabei starten, müssen vor dem Ende gestoppt sein. Siehe
[keep-host-devices-out-of-the-chroot.md](keep-host-devices-out-of-the-chroot.md).

Der Download-Cache liegt in `local/cache/` und wird vor dem Packen
ausgehängt, damit er nicht ins ISO gelangt.

## Konsequenzen

Ein Jahreswechsel ändert `edition.conf`, nicht die Install-Skripte.
`local/local.env` bleibt auf dem Rechner, mit Rechten `600`, und wird nicht
committet. `check_clean.sh` sucht zusätzlich nach Werten daraus.

Teilbuilds hängen an einer unversionierten Liste. Zwei parallele Teilbuilds
teilen sich diese eine Datei.

`/tmp/fossgis` darf den Build nicht überleben. Bleibt es liegen, liegen
Secrets im Chroot, bis aufgeräumt wird.
