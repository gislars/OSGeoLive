# FOSSGIS Branding: VM-Experimente

Diese Ideen sind **nicht** im Default-ISO aktiv. Nach einem QEMU-/Laptop-Test
entscheiden, ob sie in einen Folge-Branch wandern.

## LXQt-Akzentfarbe `#ee7f00`

Ziel: Panel- und UI-Highlights in FOSSGIS-Orange statt Standardfarbe.

Beispiel (nur zum Ausprobieren, nicht committen als Default):

```ini
# ~/.config/lxqt/lxqt.conf  (Ausschnitt, Theme-Abhaengig)
[General]
icon_follow_color_scheme=true
```

Je nach LXQt-/Lubuntu-Version liegt die Akzentfarbe in:

- `~/.config/lxqt/lxqt.conf`
- oder unter `~/.config/lxqt/` Theme-/Palette-Dateien
- oder systemweit unter `/etc/xdg/xdg-Lubuntu/`

Vorgehen in der VM:

1. ISO booten, Farbe in den LXQt-Erscheinungsbild-Einstellungen setzen (`#ee7f00`).
2. Geaenderte Dateien unter `~/.config/lxqt/` sichern.
3. Wenn es gut aussieht: Snippet nach `app-conf/fossgis/` bzw. `install_desktop.sh`
   uebernehmen (neuer Branch).

## Wanderndes Konferenz-Logo (Lockscreen / Screensaver)

Ziel: rundes FOSSGIS-2027-Logo bewegt sich ueber den Bildschirm (DVD-Stil),
nicht als fester Default.

Moeglicher Weg mit `xscreensaver` (Paket ggf. nachinstallieren):

1. Logo als PNG mit transparentem Hintergrund bereitstellen
   (z. B. aus `fossgis/tools/build_wallpaper.sh` Zwischenprodukt
   `local/artwork/drafts/logo-heidelberg-tr.png`).
2. In der VM: `xscreensaver-demo` oeffnen, Hack waehlen der ein Bild
   verschiebt/bounce't (je nach verfuegbaren Hacks, z. B. Image oder GL).
3. LXQt-Lock so konfigurieren, dass der Screensaver greift
   (`lxqt-config-session` / Power Management).
4. Wenn es stabil und nicht ablenkend ist: Install-Skript und Abhaengigkeit
   in einem eigenen Feature-Branch vorschlagen.

Wenn `xscreensaver` auf Lubuntu 26.04 fehlt oder mit SDDM kollidiert:
Experiment dokumentieren und verwerfen; der Lock zeigt dann weiter das
Edition-Wallpaper (bereits ueber SDDM/`install_desktop.sh`).

## Entscheidung nach dem Test

| Experiment | Ergebnis | Naechster Schritt |
|---|---|---|
| LXQt-Akzent | offen | ship / skip |
| Lockscreen-Logo | offen | ship / skip |
