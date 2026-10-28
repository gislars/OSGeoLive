# Nur den Fork veröffentlichen

- Status: akzeptiert
- Datum: 2026-10-27

## Kontext

Dieses Repository ist der FOSSGIS-Fork von OSGeoLive. Es enthält
Konferenzdaten, lokale Werkzeuge und Änderungen, die zum Teil an OSGeo
gehören und zum Teil nicht. Ein Push an `OSGeo/OSGeoLive` würde die
Upstream-Historie mit Fork-Commits vermischen. Ein Push ohne Prüfung kann
Secrets aus `local/` oder einen ungetesteten Build-Stand veröffentlichen.

## Entscheidung

Einziges Push-Ziel ist `https://github.com/gislars/OSGeoLive`.
`https://github.com/OSGeo/OSGeoLive` wird nicht beschrieben. Lesen und
Übernehmen von Upstream ist erlaubt.

Ein Push braucht eine ausdrückliche Freigabe. `fossgis/tools/check_clean.sh`
muss bestehen: keine Secrets, keine lokalen Pfade, keine Datendateien, die
Merge-Regeln für `master`, und der Nachweis des letzten Vollbuilds.
`fossgis/tools/pre-push.hook` ist die Vorlage dafür und verlangt zusätzlich
`FOSSGIS_PUSH_APPROVED=1`.

Änderungen, die für alle OSGeoLive-Nutzer taugen, können als Pull Request
an OSGeo gehen. Den stellt nur der Maintainer, von Hand. Kein Skript und
kein Assistent öffnet ihn.

Ohne Angabe eines GitHub-Benutzers klont der Build
`gislars/OSGeoLive`, nicht `OSGeo/OSGeoLive`.

## Konsequenzen

Fork-Branches und Archiv-Branches (`fossgis2025`, `fossgis2026`) bleiben
auf diesem Remote. Archiv-Branches werden nicht nach `master` gemergt.

Was upstream-tauglich ist, steht je Eintrag in `upstream-diff.md`. Diese
Kennzeichnung ist kein Auftrag, einen Pull Request zu öffnen.

Ein Assistent committet lokal nur auf Wunsch und nur nach grünem
`check_clean.sh`. Pushen tut er nur nach ausdrücklicher Freigabe, und nur
zum Fork.
