#!/usr/bin/env bash
# Safe Docker housekeeping utility
# - default: remove stopped containers and dangling images
# - optional: remove unused images (-a) and dangling volumes (-v)
# - supports dry-run (-n) and confirmation (-y)

set -euo pipefail

DRY_RUN=false
AGGRESSIVE=false
REMOVE_VOLUMES=false
ASSUME_YES=false
SHOW_SUMMARY=false

usage() {
  cat <<EOF
Usage: $0 [-n] [-a] [-v] [-y] [-s] [-h]

Options:
  -n    Dry run: show what would be removed, do not delete
  -a    Aggressive: also remove unused images (docker image prune -a)
  -v    Remove dangling volumes (docker volume prune)
  -y    Assume yes; do not prompt for confirmation
  -s    Show docker system df summary before and after
  -h    Help

Defaults: remove stopped containers and dangling images only.
EOF
  exit 1
}

while getopts "navysh" opt; do
  case "$opt" in
    n) DRY_RUN=true ;;
    a) AGGRESSIVE=true ;;
    v) REMOVE_VOLUMES=true ;;
    y) ASSUME_YES=true ;;
    s) SHOW_SUMMARY=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker CLI not found in PATH." >&2
  exit 2
fi

if [ "$SHOW_SUMMARY" = true ]; then
  echo "Docker usage summary (before):"
  docker system df || true
  echo
fi

# list candidates
list_candidates() {
  echo "Stopped containers (exited):"
  docker ps -a -f status=exited --format '  {{.ID}}\t{{.Names}}\t{{.Image}}' || echo "  (none)"
  echo

  echo "Dangling images (untagged):"
  docker images -f dangling=true --format '  {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}' || echo "  (none)"
  echo

  if [ "$AGGRESSIVE" = true ]; then
    echo "Images not referenced by any container (likely removed by -a):"
    # collect used image IDs
    tmp_used=$(mktemp)
    docker ps -aq >/dev/null 2>&1 || true
    if docker ps -aq >/dev/null 2>&1; then
      docker inspect --format='{{.Image}}' $(docker ps -aq) 2>/dev/null | sort -u > "$tmp_used" || true
    fi
    docker images --no-trunc --format '  {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}' | while IFS=$'\t' read -r id rest; do
      if [ -s "$tmp_used" ]; then
        if ! grep -Fxq "$id" "$tmp_used"; then
          echo "$id\t$rest"
        fi
      else
        # no containers, so all images are candidates
        echo "$id\t$rest"
      fi
    done
    rm -f "$tmp_used" || true
    echo
  fi

  if [ "$REMOVE_VOLUMES" = true ]; then
    echo "Dangling volumes:"
    docker volume ls -f dangling=true --format '  {{.Name}}' || echo "  (none)"
    echo
  fi
}

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN: no changes will be made ***"
  list_candidates
  echo "Dry run complete."
  exit 0
fi

# not dry run: prompt for confirmation unless -y
if [ "$ASSUME_YES" != true ]; then
  echo "The following actions will be performed:"
  echo " - Remove stopped containers (docker container prune)"
  echo " - Remove dangling images (docker image prune)"
  if [ "$AGGRESSIVE" = true ]; then
    echo " - Aggressive: remove unused images (docker image prune -a)"
  fi
  if [ "$REMOVE_VOLUMES" = true ]; then
    echo " - Remove dangling volumes (docker volume prune)"
  fi
  echo
  list_candidates
  read -r -p "Proceed with these actions? [y/N] " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# perform actions
echo "Removing stopped containers..."
docker container prune -f || true

echo "Removing dangling images..."
docker image prune -f || true

if [ "$AGGRESSIVE" = true ]; then
  echo "Removing unused images (aggressive)..."
  docker image prune -a -f || true
fi

if [ "$REMOVE_VOLUMES" = true ]; then
  echo "Removing dangling volumes..."
  docker volume prune -f || true
fi

if [ "$SHOW_SUMMARY" = true ]; then
  echo
  echo "Docker usage summary (after):"
  docker system df || true
fi

echo "Docker cleanup complete."
exit 0
