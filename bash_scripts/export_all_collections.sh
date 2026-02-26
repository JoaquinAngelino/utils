#!/usr/bin/env bash
# Export all databases and collections using mongoexport (Linux)
# Usage:
#    ./export_all_collections.sh -u "mongodb://user:pass@host:27017/?authSource=admin"
#    ./export_all_collections.sh -u "mongodb://127.0.0.1:27017"
# Options:
#   -u URI      connection URI (or use the MONGO_URI environment variable)
#   -o DIR      output directory (default ./mongo_exports_TIMESTAMP)
#   -p N        parallelism (default 4)
#   -g          compress each .json -> .json.gz
#   -h          help

set -euo pipefail

OUTDIR=""
PARALLEL=4
GZIP=false
URI="${MONGO_URI:-}"

usage() {
  cat <<EOF
Usage: $0 [-u mongodb_uri] [-o outdir] [-p parallel] [-g]
Example:
 ./export_all_collections.sh -u "mongodb://user:pass@host:27017/?authSource=admin" -o ./exports
 ./export_all_collections.sh -u "mongodb://127.0.0.1:27017"
EOF
  exit 1
}

while getopts "u:o:p:gh" opt; do
  case $opt in
    u) URI="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    p) PARALLEL="$OPTARG" ;;
    g) GZIP=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$URI" ]]; then
  echo "No URI provided. Set MONGO_URI env var or use -u."
  read -r -p "Mongo URI: " URI
fi

# Normalizar: quitar barra final si existe para evitar "//db" al concatenar
URI="${URI%/}"

if ! command -v mongosh >/dev/null 2>&1; then
  echo "Error: mongosh is not installed or not in PATH." >&2
  exit 2
fi
if ! command -v mongoexport >/dev/null 2>&1; then
  echo "Error: mongoexport is not installed or not in PATH." >&2
  exit 2
fi

OUTDIR="${OUTDIR:-./mongo_exports_$(date +%F_%H%M%S)}"
mkdir -p "$OUTDIR"

echo "Using URI: $URI"
echo "Output: $OUTDIR"
echo "Parallelism: $PARALLEL"
echo "Gzip: $GZIP"

# Obtener lista de bases de datos
DBS=$(mongosh "$URI" --quiet --eval 'db.getMongo().getDBs().databases.forEach(d => print(d.name))')
if [[ -z "$DBS" ]]; then
  echo "No databases found or failed to connect." >&2
  exit 3
fi

for db in $DBS; do
  echo "Processing DB: $db"

  # Obtener colecciones de la DB actual usando getSiblingDB para evitar problemas con la URI
  COLLECTIONS=$(mongosh "$URI" --quiet --eval "db.getSiblingDB('$db').getCollectionNames().forEach(c => print(c))")

  if [[ -z "$COLLECTIONS" ]]; then
    echo "  No collections found in $db (or failed to list)."
    continue
  fi

  mkdir -p "$OUTDIR/$db"

  for coll in $COLLECTIONS; do
    # skip system collections
    if [[ "$coll" == system.* ]]; then
      echo "  Skipping system collection: $coll"
      continue
    fi

    outfile="$OUTDIR/$db/$coll.json"
    (
      echo "  Exporting $db.$coll -> $outfile"
      mongoexport --uri="$URI" --db="$db" --collection="$coll" --jsonArray --out="$outfile"
      if $GZIP; then
        gzip -f "$outfile"
        echo "  Compressed -> ${outfile}.gz"
      fi
      echo "  Done $db.$coll"
    ) &

    # Control simple de concurrencia
    while (( $(jobs -rp | wc -l) >= PARALLEL )); do
      sleep 0.3
    done
  done
done

# Esperar jobs en background
wait

echo "Export completo en: $OUTDIR"
