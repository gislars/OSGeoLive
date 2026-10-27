# OSM-Extrakt nach Relation (Boundary)

Dieser Sub-Task beschreibt, wie aus einer regionalen PBF-Datei (z.B. Geofabrik Niedersachsen) ein Ausschnitt für eine bestimmte OSM-Relation (z.B. Stadtgrenze Göttingen) erzeugt wird. Das Ergebnis kann als **osm.bz2** oder **pbf** ausgegeben werden.

## Voraussetzungen

- **osmium-tool** – für `osmium getid`, `osmium extract`, `osmium cat`
- **gdal-bin** – für `ogr2ogr` (Export der Relation als GeoJSON-Polygon)

Installation (Debian/Ubuntu):

```bash
sudo apt install osmium-tool gdal-bin
```

## Skript: extract_osm_by_relation.py

Das Skript `extract_osm_by_relation.py` kapselt den Ablauf: Relation aus PBF holen → Boundary als GeoJSON erzeugen → mit dieser Boundary aus der PBF ausstanzen → Ausgabe im gewünschten Format.

### Parameter

| Parameter   | Bedeutung                                              | Beispiel                    |
| ---------- | ------------------------------------------------------ | --------------------------- |
| `--relation` | OSM-Relation-ID der administrativen Grenze (z.B. Stadt) | `191361` (Göttingen)        |
| `--pbf`      | Pfad zur Eingabe-PBF (Regional-Extrakt)                 | `niedersachsen-latest.osm.pbf` |
| `--format`   | Zielformat                                              | `osm.bz2` oder `pbf`       |
| `--output`   | Pfad/Name der erzeugten Datei                           | `goettingen.osm.bz2`        |

### Nutzung

**Beispiel: Göttingen als osm.bz2 (für install_osm.sh):**

```bash
wget https://download.geofabrik.de/europe/germany/niedersachsen-latest.osm.pbf -O niedersachsen-latest.osm.pbf

python3 bin/extract_osm_by_relation.py \
  --relation 191361 \
  --pbf niedersachsen-latest.osm.pbf \
  --format osm.bz2 \
  --output goettingen.osm.bz2
```

**Beispiel: Göttingen als PBF:**

```bash
python3 bin/extract_osm_by_relation.py \
  --relation 191361 \
  --pbf niedersachsen-latest.osm.pbf \
  --format pbf \
  --output goettingen.osm.pbf
```

### Ablauf im Skript

1. `osmium getid -r <pbf> r<id> -o <temp>.osm.pbf` – Relation inkl. Member aus der PBF extrahieren
2. `ogr2ogr -f GeoJSON <temp>.geojson <temp>.osm.pbf multipolygons` – Boundary als GeoJSON erzeugen
3. `osmium extract -p <temp>.geojson <pbf> -o <temp>.osm.pbf` – Ausschnitt aus der großen PBF mit exakter Grenze
4. Bei **pbf:** Ausgabedatei = dieser Ausschnitt. Bei **osm.bz2:** `osmium cat` nach OSM-XML, dann bzip2-Kompression.

### OSM-Relation-ID

Die Relation-ID ist die numerische ID der administrativen Grenze in OpenStreetMap, z.B.:

- **Göttingen:** [Relation 191361](https://www.openstreetmap.org/relation/191361)

Weitere IDs findest du auf [openstreetmap.org](https://www.openstreetmap.org) unter der jeweiligen Stadt/Gemeinde (Relation, administrative Grenze).

### Geofabrik-PBF

Regionale Ausschnitte (z.B. Bundesländer) gibt es bei [Geofabrik](https://download.geofabrik.de/), z.B.:

- [Niedersachsen](https://download.geofabrik.de/europe/germany/niedersachsen-latest.osm.pbf)

Die Relation muss in der gewählten PBF enthalten sein (Göttingen liegt in Niedersachsen).
