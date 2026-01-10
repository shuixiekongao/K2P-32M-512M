#!/usr/bin/env bash
# Add kenzo feeds to feeds.conf.default (idempotent, with backups)
#
# Usage:
#   ./scripts/add_kenzo_feeds.sh              # will try current dir then openwrt/
#   OPENWRT_DIR=path/to/openwrt ./scripts/add_kenzo_feeds.sh

set -euo pipefail

# Third-party feed lines to add
FEEDS_TO_ADD=(
  "src-git kenzo https://github.com/kenzok8/openwrt-packages"
  "src-git small https://github.com/kenzok8/small-package"
)

# Locate feeds.conf.default (prefer explicit env var OPENWRT_DIR, then current, then openwrt/)
FEEDS_FILE="${OPENWRT_DIR:-}/feeds.conf.default"
if [ -z "${OPENWRT_DIR:-}" ]; then
  if [ -f "./feeds.conf.default" ]; then
    FEEDS_FILE="./feeds.conf.default"
  elif [ -f "./openwrt/feeds.conf.default" ]; then
    FEEDS_FILE="./openwrt/feeds.conf.default"
  else
    echo "Error: feeds.conf.default not found in current directory or ./openwrt/"
    exit 1
  fi
fi

# Normalize path
FEEDS_FILE="$(realpath "$FEEDS_FILE")"
echo "Using feeds file: $FEEDS_FILE"

# Backup
BACKUP="${FEEDS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$FEEDS_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

# Append if not present
for line in "${FEEDS_TO_ADD[@]}"; do
  # Use fixed-string exact match to avoid duplicates
  if grep -Fxq "$line" "$FEEDS_FILE"; then
    echo "Already present, skipping: $line"
  else
    echo "$line" >> "$FEEDS_FILE"
    echo "Appended: $line"
  fi
done

echo "Done. To refresh and install feeds run (inside the openwrt tree):"
echo "  ./scripts/feeds update -a"
echo "  ./scripts/feeds install -a"
