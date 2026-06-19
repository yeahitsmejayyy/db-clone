#!/usr/bin/env bash
# postgres.sh — PostgreSQL adapter for /db-clone.
# Contract: clone(SOURCE -> TARGET), verify identical, never overwrite.
# Method: pg_dump (source) | psql (new target db). Works same-server AND
# cross-server, because both endpoints are full connection URIs.
#
# Usage: postgres.sh SOURCE_URL TARGET_URL
#   SOURCE_URL  conn URI to the EXISTING source db
#               e.g. postgresql://user@host:5432/app_src
#   TARGET_URL  conn URI to the NEW clone db (db name must NOT exist yet)
#               e.g. postgresql://user@host:5432/app_clone
#
# Note: clones schema + data. Object ownership and GRANT/privileges are
# intentionally NOT copied (--no-owner --no-privileges) so the clone is
# portable across servers/roles. That's the right call for a clone skill.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$DIR/../lib/common.sh"

SOURCE="${1:?usage: postgres.sh SOURCE_URL TARGET_URL}"
TARGET="${2:?usage: postgres.sh SOURCE_URL TARGET_URL}"

for bin in psql pg_dump; do
  command -v "$bin" >/dev/null 2>&1 || die "$bin not found on PATH. Install the PostgreSQL client tools."
done

# --- parse target URI: db name + a maintenance URL (db swapped to postgres)
strip_query() { printf '%s' "${1%%\?*}"; }
url_query()   { [[ "$1" == *\?* ]] && printf '?%s' "${1#*\?}" || printf ''; }

TDB="$(strip_query "$TARGET")"; TDB="${TDB##*/}"
[[ -n "$TDB" && "$TDB" != "$TARGET" ]] || die "could not parse a database name from TARGET_URL: $TARGET"
TARGET_BASE="$(strip_query "$TARGET")"; TARGET_BASE="${TARGET_BASE%/*}"
MAINT="${TARGET_BASE}/postgres$(url_query "$TARGET")"

# --- guards --------------------------------------------------------------
psql "$SOURCE" -tAc 'SELECT 1' >/dev/null 2>&1 || die "cannot reach source db: $SOURCE"
psql "$MAINT"  -tAc 'SELECT 1' >/dev/null 2>&1 || die "cannot reach target server (maintenance db 'postgres'): $MAINT"
exists="$(psql "$MAINT" -tAc "SELECT 1 FROM pg_database WHERE datname='${TDB//\'/\'\'}'")"
[[ "$exists" == "1" ]] && die "target database '$TDB' already exists, refusing to overwrite."

# --- clone ---------------------------------------------------------------
echo "Cloning (postgres):"
echo "  source: $SOURCE"
echo "  target: $TARGET  (new db: $TDB)"
psql "$MAINT" -v ON_ERROR_STOP=1 -qc "CREATE DATABASE \"$TDB\";"
# On any failure during restore, drop the half-built db so we never leave junk.
trap 'echo "restore failed — dropping partial target db $TDB" >&2; psql "$MAINT" -qc "DROP DATABASE IF EXISTS \"$TDB\";" >/dev/null 2>&1 || true' ERR
pg_dump --no-owner --no-privileges "$SOURCE" | psql "$TARGET" -v ON_ERROR_STOP=1 -q >/dev/null
trap - ERR

# --- verify --------------------------------------------------------------
echo "Verifying clone..."

# fingerprints are db-name agnostic (built from information_schema), so an
# identical schema in two differently-named databases hashes the same.
col_fp() {
  psql "$1" -tAc "
    SELECT table_name||'|'||column_name||'|'||data_type||'|'||is_nullable||'|'||coalesce(column_default,'')
    FROM information_schema.columns
    WHERE table_schema='public'
    ORDER BY table_name, ordinal_position;" | sha
}
con_fp() {
  psql "$1" -tAc "
    SELECT tc.constraint_type||'|'||tc.table_name||'|'||coalesce(kcu.column_name,'')
    FROM information_schema.table_constraints tc
    LEFT JOIN information_schema.key_column_usage kcu
      USING (constraint_name, table_schema)
    WHERE tc.table_schema='public'
    ORDER BY 1;" | sha
}

check "target reachable" "1" "$(psql "$TARGET" -tAc 'SELECT 1')"
check "column schema match"   "$(col_fp "$SOURCE")" "$(col_fp "$TARGET")"
check "constraint match"      "$(con_fp "$SOURCE")" "$(con_fp "$TARGET")"

for t in $(psql "$SOURCE" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"); do
  check "rows: $t" \
    "$(psql "$SOURCE" -tAc "SELECT count(*) FROM \"$t\"")" \
    "$(psql "$TARGET" -tAc "SELECT count(*) FROM \"$t\"")"
done

finish "$SOURCE" "$TARGET"
