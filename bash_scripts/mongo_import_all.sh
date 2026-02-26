#!/usr/bin/env bash
# Restore all databases/collections exported by export_all_collections.sh
# Supports .json and .json.gz files, parallel imports and dry-run

set -euo pipefail

URI="${MONGO_URI:-}"
INDIR=""
PARALLEL=4
DRY_RUN=false
DROP=false

usage() {
  cat <<EOF
Usage: $0 [-u uri] [-i input_dir] [-p parallel] [-n] [-d]

Options:
  -u URI    MongoDB connection URI (or set MONGO_URI env var)
  -i DIR    Input directory created by export_all_collections.sh (default ./mongo_exports_*)
  -p N      Parallel imports (default 4)
  -n        Dry run: show commands without running mongoimport
  -d        Drop collections before importing
  -h        Help

Examples:
  MONGO_URI="mongodb://user:pass@host:27017/?authSource=admin" \ 
    ./mongo_import_all.sh -i ./mongo_exports_2026-02-26_143340 -p 6
  ./mongo_import_all.sh -u "mongodb://127.0.0.1:27017" -i ./mongo_exports -n
EOF
  exit 1
}

while getopts "u:i:p:ndh" opt; do
  case "$opt" in
    u) URI="$OPTARG" ;;
    i) INDIR="$OPTARG" ;;
    p) PARALLEL="$OPTARG" ;;
    n) DRY_RUN=true ;;
    d) DROP=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Find a reasonable default input dir if none given
if [[ -z "$INDIR" ]]; then
  # pick the most recent mongo_exports_* directory in CWD
  recent=$(ls -d ./mongo_exports_* 2>/dev/null | sort -r | head -n1 || true)
  if [[ -n "$recent" ]]; then
    INDIR="$recent"
  else
    echo "No input directory provided and no ./mongo_exports_* found." >&2
    usage
  fi
fi

if [[ -z "$URI" ]]; then
  echo "No URI provided. Set MONGO_URI env var or use -u." >&2
  usage
fi

if ! command -v mongoimport >/dev/null 2>&1; then
  echo "Error: mongoimport is not installed or not in PATH." >&2
  exit 2
fi

INDIR="${INDIR%/}"

echo "Using URI: $URI"
echo "Input Dir: $INDIR"
echo "Parallelism: $PARALLEL"
echo "Dry run: $DRY_RUN"
echo "Drop collections before import: $DROP"

# Iterate databases (subdirectories)
for dbpath in "$INDIR"/*; do
  [ -d "$dbpath" ] || continue
  dbname=$(basename "$dbpath")
  echo "Processing DB: $dbname"

  # find .json and .json.gz files
  shopt -s nullglob
  files=("$dbpath"/*.json "$dbpath"/*.json.gz)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    echo "  No exported collections found in $dbpath"
    continue
  fi

  for file in "${files[@]}"; do
    fname=$(basename "$file")
    # extract collection name (strip .json or .json.gz)
    coll=${fname%%.json*}

    echo "  Found collection file: $fname -> collection: $coll"

    cmd=(mongoimport --uri="$URI" --db="$dbname" --collection="$coll" --jsonArray --file "$file")
    # add --gzip if file ends with .gz
    if [[ "$file" == *.gz ]]; then
      cmd+=(--gzip)
    fi
    if $DROP; then
      cmd+=(--drop)
    fi

    if $DRY_RUN; then
      echo "  DRY: ${cmd[*]}"
    else
      (
        echo "  Importing $dbname.$coll from $file"
        "${cmd[@]}"
        echo "  Done $dbname.$coll"
      ) &

      # simple concurrency control
      while (( $(jobs -rp | wc -l) >= PARALLEL )); do
        sleep 0.3
      done
    fi
  done

  # wait for any background imports for this DB (optional)
  if ! $DRY_RUN; then
    wait
  fi
done

if $DRY_RUN; then
  echo "Dry run complete. No imports were executed."
else
  # wait for any remaining background jobs
  wait
  echo "Import complete."
fi

exit 0
