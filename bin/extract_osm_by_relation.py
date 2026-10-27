#!/usr/bin/env python3
"""
Extract OSM data for a region defined by an OSM relation (e.g. administrative boundary)
from a PBF file, and output as PBF or OSM.BZ2.

Requires: osmium-tool, gdal-bin (ogr2ogr).
Usage:
  python3 extract_osm_by_relation.py --relation 191361 --pbf niedersachsen-latest.osm.pbf \\
    --format osm.bz2 --output goettingen.osm.bz2
"""

import argparse
import bz2
import os
import shutil
import subprocess
import sys
import tempfile


def run(cmd, check=True):
    """Run command; if check=True, raise on non-zero exit."""
    r = subprocess.run(cmd, shell=False)
    if check and r.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {r.returncode}: {cmd}")
    return r.returncode


def main():
    parser = argparse.ArgumentParser(
        description="Extract OSM data by relation boundary from a PBF file."
    )
    parser.add_argument(
        "--relation",
        type=int,
        required=True,
        help="OSM relation ID (e.g. 191361 for Göttingen)",
    )
    parser.add_argument(
        "--pbf",
        type=str,
        required=True,
        help="Path to input PBF file (e.g. niedersachsen-latest.osm.pbf)",
    )
    parser.add_argument(
        "--format",
        type=str,
        required=True,
        choices=["pbf", "osm.bz2"],
        help="Output format: pbf or osm.bz2",
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Path to output file (e.g. goettingen.osm.bz2)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.pbf):
        print(f"Error: input PBF file not found: {args.pbf}", file=sys.stderr)
        sys.exit(1)

    tmpdir = tempfile.mkdtemp(prefix="osm_extract_")
    try:
        rel_pbf = os.path.join(tmpdir, f"rel{args.relation}.osm.pbf")
        geojson = os.path.join(tmpdir, "boundary.geojson")
        extracted_pbf = os.path.join(tmpdir, "extracted.osm.pbf")

        # 1. Get relation with members from PBF
        run([
            "osmium", "getid", "-r", args.pbf, f"r{args.relation}",
            "-o", rel_pbf,
        ])

        # 2. Export relation geometry to GeoJSON (multipolygons layer)
        run([
            "ogr2ogr", "-f", "GeoJSON", geojson, rel_pbf, "multipolygons",
        ])

        if not os.path.isfile(geojson):
            print("Error: ogr2ogr did not produce GeoJSON", file=sys.stderr)
            sys.exit(1)

        # 3. Extract region from full PBF using polygon
        run([
            "osmium", "extract", "-p", geojson, args.pbf, "-o", extracted_pbf,
        ])

        if args.format == "pbf":
            shutil.copy2(extracted_pbf, args.output)
            print(f"Written: {args.output}")
            return

        # 4. osm.bz2: convert PBF to OSM XML then bzip2
        osm_xml = os.path.join(tmpdir, "extracted.osm")
        run([
            "osmium", "cat", extracted_pbf, "-o", osm_xml, "-f", "xml",
        ])

        with open(osm_xml, "rb") as f_in:
            with bz2.open(args.output, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)

        print(f"Written: {args.output}")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    main()
