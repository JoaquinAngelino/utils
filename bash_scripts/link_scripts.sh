#!/usr/bin/env bash

set -e

# Source directory
SOURCE_DIR="${1:-$(pwd)}"

# symlinks destination
TARGET_DIR="$HOME/.local/bin"

# Create directory if it doesn't exist
mkdir -p "$TARGET_DIR"

echo "🔎 Searching scripts .sh in: $SOURCE_DIR"

# Search for firs level .sh files
for SCRIPT in "$SOURCE_DIR"/*.sh; do
  [ -e "$SCRIPT" ] || continue

  SCRIPT_NAME=$(basename "$SCRIPT")       # eg: build_apk.sh
  CMD_NAME="${SCRIPT_NAME%.sh}"           # eg: build_apk
  LINK_PATH="$TARGET_DIR/$CMD_NAME"       # ~/.local/bin/build_apk

  # Create symlink (overwrite if exists)
  ln -sf "$SCRIPT" "$LINK_PATH"
  chmod +x "$SCRIPT"

  echo "🔗 Link created: $LINK_PATH -> $SCRIPT"
done

echo "✅ Done."
