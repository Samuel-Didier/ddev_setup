#!/usr/bin/env bash
set -euo pipefail
# ddev-reset.sh — Stop and remove DDEV project config/containers for current project.

FORCE=0
KEEP_DB=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift;;
    --keep-db) KEEP_DB=1; shift;;
    -h|--help) echo "Usage: $(basename "$0") [--force] [--keep-db]"; exit 0;;
    *) echo "Unknown: $1" >&2; exit 1;;
  esac
done

if [[ $FORCE -ne 1 ]]; then
  read -rp "This will delete the DDEV project and its database. Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

ddev stop >/dev/null 2>&1 || true
if [[ $KEEP_DB -eq 1 ]]; then
  ddev delete -Oy >/dev/null 2>&1 || true
else
  ddev delete -y >/dev/null 2>&1 || true
fi
rm -rf .ddev
echo "==> Reset complete."
