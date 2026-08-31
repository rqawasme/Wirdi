#!/usr/bin/env bash
# Copy the built content database into the Flutter asset bundle.
#
#   python3 content/scripts/build_content.py   # -> content/build/content.db
#   tool/sync_content_asset.sh                 # -> assets/content.db
#
# assets/content.db is gitignored: it is a build artifact, reproducible from
# content/sources/ at any time.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$root/content/build/content.db"
dst="$root/assets/content.db"

if [[ ! -f "$src" ]]; then
  echo "no $src — run: python3 content/scripts/build_content.py" >&2
  exit 1
fi

python3 "$root/content/scripts/verify_content.py" --db "$src"
python3 "$root/tool/check_schema_parity.py" --db "$src"

cp "$src" "$dst"
echo "copied $(basename "$src") -> assets/content.db ($(du -h "$dst" | cut -f1))"
