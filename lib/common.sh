#!/usr/bin/env bash
# common.sh — shared helpers every db-clone adapter sources.
# Provides: consistent PASS/FAIL verification output and a single
# success/failure exit convention, so all adapters behave identically.

VERIFY_OK=true

# check LABEL EXPECTED ACTUAL — record a verification assertion.
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  PASS  %s\n' "$label"
  else
    printf '  FAIL  %s (expected [%s], got [%s])\n' "$label" "$expected" "$actual"
    VERIFY_OK=false
  fi
}

# finish SOURCE TARGET — print the final result and exit accordingly.
finish() {
  echo
  if $VERIFY_OK; then
    echo "RESULT: ✅ clone verified identical to source"
    echo "  source: $1"
    echo "  target: $2"
    exit 0
  else
    echo "RESULT: ❌ verification failed — target left in place for inspection"
    exit 1
  fi
}

# die MSG — fatal error before any clone work happened.
die() { echo "ERROR: $*" >&2; exit 1; }

# sha LABEL — hash stdin, return just the digest.
sha() { shasum | cut -d' ' -f1; }
