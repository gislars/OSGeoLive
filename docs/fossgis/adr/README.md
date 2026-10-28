# Architekturentscheidungen

Ein Architecture Decision Record (ADR) hält eine Architekturentscheidung fest:
den Kontext, die getroffene Wahl und die Folgen. Sammlung und Vorlage:
[architecture-decision-record](https://github.com/architecture-decision-record/architecture-decision-record).
Die Texte folgen der kurzen Vorlage von Michael Nygard (Status, Kontext,
Entscheidung, Konsequenzen).

`upstream-diff.md` listet Dateiänderungen gegenüber OSGeo. `build-safety.md`
hält die Vorfälle und die daraus folgenden Regeln fest. Ein ADR beantwortet
die Frage, warum eine Richtung gewählt wurde, und bleibt stehen, wenn sich
die Umsetzung in den anderen Dokumenten weiterbewegt.

## Wann eine Datei entsteht

Eine neue Datei, wenn die Entscheidung den Build-Rechner, die Grenze zwischen
Host und Image, das, was ins ISO gelangt, oder das Veröffentlichungsziel
betrifft und später jemand das Warum brauchen wird.

Keine Datei für Paketversionswechsel, einmalige Workarounds oder etwas, das
`upstream-diff.md` schon vollständig erklärt. Jede Datei behandelt genau eine
Entscheidung.

## Dateiname

Gegenwart, Befehlsform, Englisch, Kleinbuchstaben, Bindestriche, Endung
`.md`. Beispiel: `build-only-in-a-vm.md`.

## Status

- **vorgeschlagen:** noch nicht umgesetzt und nicht freigegeben.
- **akzeptiert:** gilt. Die Umsetzung kann schon auf `master` liegen; das
  Datum in der Datei ist der Tag, an dem die Entscheidung festgehalten wurde.
- **abgelehnt:** geprüft und verworfen. Die Datei bleibt.
- **ersetzt durch** `andere-datei.md`: gilt nicht mehr. Der alte Text bleibt
  unverändert, der neue ADR verweist darauf.

Vorhandener Text wird nicht umgeschrieben. Spätere Erkenntnisse kommen als
datierten Nachtrag ans Ende, oder eine neue Datei ersetzt die alte.

## Verzeichnis

| Datei | Entscheidung |
|---|---|
| [build-only-in-a-vm.md](build-only-in-a-vm.md) | Builds laufen nur in der Build-VM |
| [keep-host-devices-out-of-the-chroot.md](keep-host-devices-out-of-the-chroot.md) | Host-`/dev` kommt nicht in den Chroot |
| [treat-critical-log-lines-as-build-failure.md](treat-critical-log-lines-as-build-failure.md) | Kritische Logzeilen machen den Build rot |
| [copy-only-versioned-files-into-the-chroot.md](copy-only-versioned-files-into-the-chroot.md) | In den Chroot kommen nur versionierte Dateien |
| [split-edition-settings-from-local-inputs.md](split-edition-settings-from-local-inputs.md) | Jahreswerte und lokale Eingaben sind getrennt |
| [merge-lubuntu-layers-into-one-squashfs.md](merge-lubuntu-layers-into-one-squashfs.md) | Lubuntu-26.04-Schichten werden ein Squashfs |
| [publish-only-to-the-fork.md](publish-only-to-the-fork.md) | Veröffentlicht wird nur der Fork |
