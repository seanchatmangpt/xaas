#!/bin/sh
# GC23-11 Bounded Fleet court (lane V23-F). PRD v26.9.23 section 12 GC23-11: every repo
# relevant to the checkpoint has exact-subject standing or an explicit non-required
# classification. Falsifier ARD section 26 F7 (an unclassified repository fails the fleet
# checkpoint); F6 shape (a receipt at a stale subject no longer applies).
#
# Run from the xaas root by `mix xaas.stop_court --checkpoint GC-26.9.23`
# (sj:courtCommand "sh docs/sjira/v26.9.23/courts/GC23-11.sh").
#   XAAS_DIR          xaas checkout under judgement (default: cwd)
#   GGEN_IGNITER_DIR  ggen_igniter checkout under judgement
#                     (default: /Users/sac/wt/v26922/fri/ggen_igniter-int)
#   GC23_FLEET_RECEIPTS_DIR  out-of-subject receipts (a commit cannot carry a receipt of
#                     itself; default: /Users/sac/wt/v26922/v26923/receipts/fleet)
#
# Steps: (1) check-classification (F7 + court-reference guard) -> REFUSED on violation;
# (2) observe (local, no network: nothing fetched during a court run) + emit the matrix
# into a scratch dir; (3) check-standing: every CriticalPath repository needs a
# validator-ADMITTED ALIVE receipt whose subject_sha is its exact head. Gate receipts of
# this checkpoint (subject GC-26.9.23/*) are excluded: they are what is being computed.
#
# Exit codes. The stop court (lib/mix/tasks/xaas.stop_court.ex on friday/gc-fri-0800)
# maps exit 0 -> ALIVE and every other exit -> UNKNOWN. REFUSED_EXIT / UNKNOWN_EXIT are the
# two non-zero codes this court distinguishes; if lane V23-P lands a distinct UNKNOWN code
# in the runner, align UNKNOWN_EXIT with it at integration (same path, both sides merged).
REFUSED_EXIT=1
UNKNOWN_EXIT=3

set -u
XAAS_DIR=${XAAS_DIR:-$(pwd)}
GGEN_IGNITER_DIR=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}
GC23_FLEET_RECEIPTS_DIR=${GC23_FLEET_RECEIPTS_DIR:-/Users/sac/wt/v26922/v26923/receipts/fleet}
FLEET="$XAAS_DIR/docs/sjira/v26.9.23/fleet"
FM="$XAAS_DIR/scripts/sjira/fleet_matrix.py"

if [ ! -f "$FM" ] || [ ! -f "$FLEET/classification.ttl" ] || [ ! -f "$FLEET/universe.json" ]; then
  echo "UNKNOWN: GC23-11 machinery lands in lane V23-F"
  exit $UNKNOWN_EXIT
fi

python3 "$FM" check-classification \
  --classification "$FLEET/classification.ttl" \
  --universe "$FLEET/universe.json" \
  --courts-dir "$XAAS_DIR/docs/sjira/v26.9.23/courts" \
  --expect-critical xaas --expect-critical ggen_igniter
rc=$?
if [ $rc -ne 0 ]; then
  echo "REFUSED: GC23-11 fleet classification (ARD F7) check-classification exit $rc"
  exit $REFUSED_EXIT
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/gc23-11.XXXXXX") || { echo "UNKNOWN: GC23-11 no scratch dir"; exit $UNKNOWN_EXIT; }
trap 'rm -rf "$scratch"' EXIT INT TERM

python3 "$FM" observe --universe "$FLEET/universe.json" --out "$scratch/observations.json" \
  --observed-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --no-network \
  --int xaas="$XAAS_DIR" --int ggen_igniter="$GGEN_IGNITER_DIR" || {
  echo "UNKNOWN: GC23-11 observe could not run"
  exit $UNKNOWN_EXIT
}
python3 "$FM" emit --classification "$FLEET/classification.ttl" --observations "$scratch/observations.json" \
  --out-ttl "$scratch/matrix.ttl" --out-md "$scratch/matrix.md" || {
  echo "REFUSED: GC23-11 matrix emit refused (classification does not cover the observed fleet)"
  exit $REFUSED_EXIT
}
echo "GC23-11 matrix: $(shasum -a 256 "$scratch/matrix.ttl" | cut -d' ' -f1) (scratch; baseline committed in fleet/matrix.ttl)"

python3 "$FM" check-standing --classification "$FLEET/classification.ttl" --universe "$FLEET/universe.json" \
  --receipts-dir "$XAAS_DIR/receipts/v26.9.23" \
  --receipts-dir "$GGEN_IGNITER_DIR/receipts/v26.9.23" \
  --receipts-dir "$GC23_FLEET_RECEIPTS_DIR" \
  --exclude-subject-prefix "GC-26.9.23/" \
  --int xaas="$XAAS_DIR" --int ggen_igniter="$GGEN_IGNITER_DIR"
rc=$?
if [ $rc -ne 0 ]; then
  echo "UNKNOWN: GC23-11 CriticalPath repositories lack exact-head standing (check-standing exit $rc)"
  exit $UNKNOWN_EXIT
fi
echo "ALIVE: GC23-11 every universe repository classified once; every CriticalPath repository ALIVE at its exact head"
exit 0
