#!/usr/bin/env bash
set -euo pipefail

# Stage existing NAS assets into the project-owned English directory.
# This script copies files without deleting or moving the original sources.

ROOT="/data2/backups/win11-image-kit"

mkdir -p \
  "$ROOT/docs/legacy" \
  "$ROOT/scripts/legacy" \
  "$ROOT/configs" \
  "$ROOT/hardware" \
  "$ROOT/images" \
  "$ROOT/packages" \
  "$ROOT/deploy"

echo "Project asset root: $ROOT"
echo "Use work/stage-win11-image-kit-assets.sh from the Codex workspace as the captured initial migration script."
