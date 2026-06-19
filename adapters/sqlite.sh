#!/usr/bin/env bash
# sqlite.sh — SQLite adapter for /db-clone.
# Contract: clone(SOURCE -> TARGET), verify identical, never overwrite.
#
# Usage: sqlite.sh SOURCE_DB TARGET_DB
#   SOURCE_DB  path to an existing .sqlite/.db file
#   TARGET_DB  path for the new clone (must NOT already exist)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$DIR/../lib/common.sh"

SOURCE="${1:?usage: sqlite.sh SOURCE_DB TARGET_DB}"
TARGET="${2:?usage: sqlite.sh SOURCE_DB TARGET_DB}"

command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 not found on PATH. Install it and retry."

# --- guards --------------------------------------------------------------
[[ -f "$SOURCE" ]] || die "source db not found: $SOURCE"
# Confirm it really is a SQLite file (magic header), not just a name.
head -c 16 "$SOURCE" | grep -q "SQLite format 3" || die "not a SQLite database: $SOURCE"
[[ -e "$TARGET" ]] && die "target already exists, refusing to overwrite: $TARGET"
mkdir -p "$(dirname "$TARGET")"

# --- clone (native online backup; handles WAL/sidecars) ------------------
echo "Cloning (sqlite):"
echo "  source: $SOURCE"
echo "  target: $TARGET"
sqlite3 "$SOURCE" ".backup '$TARGET'"

# --- verify --------------------------------------------------------------
echo "Verifying clone..."
check "integrity_check" "ok" "$(sqlite3 "$TARGET" 'PRAGMA integrity_check;')"
check "schema match" \
  "$(sqlite3 "$SOURCE" '.schema' | sort | sha)" \
  "$(sqlite3 "$TARGET" '.schema' | sort | sha)"
check "data dump match" \
  "$(sqlite3 "$SOURCE" '.dump' | sha)" \
  "$(sqlite3 "$TARGET" '.dump' | sha)"
for t in $(sqlite3 "$SOURCE" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"); do
  check "rows: $t" \
    "$(sqlite3 "$SOURCE" "SELECT count(*) FROM \"$t\";")" \
    "$(sqlite3 "$TARGET" "SELECT count(*) FROM \"$t\";")"
done

finish "$SOURCE" "$TARGET"
