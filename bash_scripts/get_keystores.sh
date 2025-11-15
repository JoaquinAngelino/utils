#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <base-folder>"
  exit 1
fi

BASE_DIR="$1"
TARGET_DIR="$BASE_DIR/dots-keystore"

mkdir -p "$TARGET_DIR"

# Search first-level folders containing "-app"
find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name "*-app*" | while read -r APP_DIR; do
  KEYSTORE_PATH="$APP_DIR/android/app"

  # Check if android/app exists
  if [ -d "$KEYSTORE_PATH" ]; then
    # Search files .keystore or .jks that do NOT contain "debug" in the name
    find "$KEYSTORE_PATH" -type f \( -name "*.keystore" -o -name "*.jks" \) ! -iname "*debug*" | while read -r KEY_FILE; do
      FILE_NAME=$(basename "$KEY_FILE")
      DEST_FILE="$TARGET_DIR/$FILE_NAME"

      cp "$KEY_FILE" "$DEST_FILE"
      echo "Copied: $KEY_FILE -> $DEST_FILE"
    done
  fi
done

echo "✅ Files .keystore and .jks copied to: $TARGET_DIR"
