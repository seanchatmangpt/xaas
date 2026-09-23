#!/bin/sh
# GC23-0 court: Future Semantics (PRD section 12; goal.ttl v23:GC23-0).
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# stop court's machinery-absent code (standing UNKNOWN); any other exit =
# the court ran and witnessed nothing (standing UNKNOWN).
# Lane V23-P owns the source half of this gate: the accepted prose must be
# committed byte-identical (PR-001, AR-003). A drifted or uncommitted prose
# file fails the court (exit 1) before anything else is judged. The admitted
# semantic projection (candidates V23-X, admission V23-C) lands in lane V23-C,
# which replaces the UNKNOWN tail of this body with the real court.
set -u
XAAS_DIR="${XAAS_DIR:-$PWD}"
prose="docs/sjira/v26.9.23/prd-ard.md"
pinned="7c8797b2bc9130fc4c8fce9138cc8140cb704e0633715807398451c660658212"

if ! git -C "$XAAS_DIR" ls-files --error-unmatch "$prose" >/dev/null 2>&1; then
  echo "REFUSED: GC23-0 accepted prose $prose is not committed in $XAAS_DIR"
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$XAAS_DIR/$prose" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$XAAS_DIR/$prose" | cut -d' ' -f1)
fi

if [ "$actual" != "$pinned" ]; then
  echo "REFUSED: GC23-0 accepted prose drifted: sha256:$actual != sha256:$pinned"
  exit 1
fi

echo "GC23-0 source: $prose sha256:$actual (byte-identical to the accepted prose)"
echo "UNKNOWN: GC23-0 machinery lands in lane V23-C"
exit 75
