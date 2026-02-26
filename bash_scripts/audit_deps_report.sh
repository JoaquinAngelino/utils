#!/usr/bin/env bash
# Run `npm audit --json` across projects, save per-project JSON and produce a CSV summary.

set -euo pipefail

OUTDIR=""
PARALLEL=4
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [-o outdir] [-p parallel] [-n]

Options:
  -o DIR   Output directory for audit JSON files and summary (default ./audit_reports_TIMESTAMP)
  -p N     Parallelism (default 4)
  -n       Dry run: show which projects would be audited
  -h       Help

This script finds all package.json files under the current directory, and for each
project runs `npm audit --json` (requires `npm` available). Results are stored as JSON
in the output directory. If `jq` is available, a CSV summary is generated.
EOF
  exit 1
}

while getopts "o:p:nh" opt; do
  case "$opt" in
    o) OUTDIR="$OPTARG" ;;
    p) PARALLEL="$OPTARG" ;;
    n) DRY_RUN=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$OUTDIR" ]]; then
  OUTDIR="./audit_reports_$(date +%F_%H%M%S)"
fi
mkdir -p "$OUTDIR"

if ! command -v npm >/dev/null 2>&1; then
  echo "Warning: npm not found; this script requires npm to run audits." >&2
fi

echo "Output dir: $OUTDIR"
echo "Parallelism: $PARALLEL"
echo "Dry run: $DRY_RUN"

# Find all package.json files (skip node_modules)
mapfile -t pkgs < <(find . -type f -name package.json -not -path "*/node_modules/*")

if [ ${#pkgs[@]} -eq 0 ]; then
  echo "No package.json files found." >&2
  exit 0
fi

echo "Found ${#pkgs[@]} projects to consider."

# For each package.json, run npm audit --json in that directory
run_audit() {
  pkgfile="$1"
  projdir=$(dirname "$pkgfile")
  # sanitize project path for filename
  safe=$(echo "$projdir" | sed 's|^\./||; s|/|__|g')
  outjson="$OUTDIR/${safe}_audit.json"

  if $DRY_RUN; then
    echo "DRY: would run npm audit in $projdir -> $outjson"
    return
  fi

  echo "Running npm audit in $projdir"
  # run npm audit with prefix so we don't change cwd permanently
  if command -v npm >/dev/null 2>&1; then
    # --prefix runs command in the given folder
    if npm --prefix "$projdir" audit --json > "$outjson" 2>/dev/null; then
      echo "  Saved audit to $outjson"
    else
      echo "  npm audit failed for $projdir; saving stderr/info to $outjson"
      # attempt to capture output even on failure
      npm --prefix "$projdir" audit --json > "$outjson" 2>&1 || true
    fi
  else
    echo "  Skipping $projdir: npm not available" >&2
  fi
}

# run audits with simple background concurrency
for pkg in "${pkgs[@]}"; do
  run_audit "$pkg" &
  while (( $(jobs -rp | wc -l) >= PARALLEL )); do
    sleep 0.2
  done
done

wait

# If jq is available, produce a CSV summary: project,low,moderate,high,critical,total
if command -v jq >/dev/null 2>&1; then
  summary_csv="$OUTDIR/audit_summary.csv"
  echo "project,low,moderate,high,critical,total" > "$summary_csv"
  for f in "$OUTDIR"/*_audit.json; do
    [ -f "$f" ] || continue
    projname=$(basename "$f" | sed 's/_audit.json$//; s|__|/|g')
    low=$(jq '.metadata.vulnerabilities.low // 0' "$f" 2>/dev/null || echo 0)
    moderate=$(jq '.metadata.vulnerabilities.moderate // 0' "$f" 2>/dev/null || echo 0)
    high=$(jq '.metadata.vulnerabilities.high // 0' "$f" 2>/dev/null || echo 0)
    critical=$(jq '.metadata.vulnerabilities.critical // 0' "$f" 2>/dev/null || echo 0)
    total=$((low + moderate + high + critical))
    echo "\"$projname\",$low,$moderate,$high,$critical,$total" >> "$summary_csv"
  done
  echo "Summary written to $summary_csv"
else
  echo "jq not found; skipping CSV summary. Install jq to get aggregated CSV." >&2
fi

echo "Done. Per-project JSON files are in: $OUTDIR"

exit 0
