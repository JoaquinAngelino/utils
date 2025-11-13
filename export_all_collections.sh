#!/usr/bin/env bash
# Exporta todas las bases de datos y todas las colecciones usando mongoexport (Linux)
# Uso:
#   MONGO_URI="mongodb://user:pass@host:27017/?authSource=admin" ./export_all_collections.sh
# Opciones:
#   -u URI      URI de conexión (también se puede usar la variable de entorno MONGO_URI)
#   -o DIR      directorio de salida (por defecto ./mongo_exports_TIMESTAMP)
#   -p N        paralelismo (por defecto 4)
#   -g          comprimir cada archivo .json -> .json.gz
#   -h          ayuda

set -euo pipefail

OUTDIR=""
PARALLEL=4
GZIP=false
URI="${MONGO_URI:-}"

usage() {
  cat <<EOF
Usage: $0 [-u mongodb_uri] [-o outdir] [-p parallel] [-g]
Example:
  MONGO_URI="mongodb://user:pass@host:27017/?authSource=admin" $0 -o ./exports -p 6 -g
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
  echo "No se proporcionó URI. Exporta con MONGO_URI env var o usa -u."
  read -r -p "Mongo URI: " URI
fi

# Normalizar: quitar barra final si existe para evitar "//db" al concatenar
URI="${URI%/}"

if ! command -v mongosh >/dev/null 2>&1; then
  echo "Error: mongosh no está instalado o no está en PATH." >&2
  exit 2
fi
if ! command -v mongoexport >/dev/null 2>&1; then
  echo "Error: mongoexport no está instalado o no está en PATH." >&2
  exit 2
fi

OUTDIR="${OUTDIR:-./mongo_exports_$(date +%F_%H%M%S)}"
mkdir -p "$OUTDIR"

echo "Usando URI: $URI"
echo "Salida: $OUTDIR"
echo "Paralelismo: $PARALLEL"
echo "Gzip: $GZIP"

# Obtener lista de bases de datos
DBS=$(mongosh "$URI" --quiet --eval 'db.getMongo().getDBs().databases.forEach(d => print(d.name))')
if [[ -z "$DBS" ]]; then
  echo "No se encontraron bases de datos o fallo al conectar." >&2
  exit 3
fi

for db in $DBS; do
  echo "Procesando DB: $db"

  # Obtener colecciones de la DB actual usando getSiblingDB para evitar problemas con la URI
  COLLECTIONS=$(mongosh "$URI" --quiet --eval "db.getSiblingDB('$db').getCollectionNames().forEach(c => print(c))")

  if [[ -z "$COLLECTIONS" ]]; then
    echo "  No se encontraron colecciones en $db (o fallo al listar)."
    continue
  fi

  mkdir -p "$OUTDIR/$db"

  for coll in $COLLECTIONS; do
    # saltar collections del sistema
    if [[ "$coll" == system.* ]]; then
      echo "  Saltando system collection: $coll"
      continue
    fi

    outfile="$OUTDIR/$db/$coll.json"
    (
      echo "  Exportando $db.$coll -> $outfile"
      mongoexport --uri="$URI" --db="$db" --collection="$coll" --jsonArray --out="$outfile"
      if $GZIP; then
        gzip -f "$outfile"
        echo "  Comprimido -> ${outfile}.gz"
      fi
      echo "  Hecho $db.$coll"
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
