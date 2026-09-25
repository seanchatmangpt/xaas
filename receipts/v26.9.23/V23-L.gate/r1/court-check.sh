#!/bin/sh
# Real stop court at the lane HEAD; exit 0 iff it ran to a verdict (exit 1 = STOP=false, 12 gates not run)
# and V23-B and V23-C link ADMITTED ALIVE from the ggen_igniter order-receipts dir, committed at its HEAD.
set -u
out="$1"
GGEN_IGNITER_DIR=/Users/sac/wt/v26922/fri/ggen_igniter-int MIX_ENV=test mix xaas.stop_court --checkpoint GC-26.9.23 --only GC23-0 --receipts-dir "$out" > "$out/court.log" 2>&1
code=$?
cat "$out/court.log"
[ "$code" -eq 1 ] || { echo "court exit $code (want 1: ran, STOP=false)"; exit 1; }
for o in V23-B V23-C; do
  grep -Eq "^order $o standing=ALIVE receipt=ADMITTED .* from=ggen_igniter:/Users/sac/wt/v26922/fri/ggen_igniter-int/receipts/v26.9.23@[0-9a-f]{40}$" "$out/court.log" || { echo "$o not linked from ggen_igniter"; exit 1; }
  python3 -c 'import json,sys; o={x["order"]:x for x in json.load(open(sys.argv[1]))["stop"]["orders"]}[sys.argv[2]]; sys.exit(0 if o["linked"] and o["committed_at_head"] is True else 1)' "$out/STOP-GC-26.9.23.json" "$o" || { echo "$o STOP receipt entry not linked+committed"; exit 1; }
done
python3 /Users/sac/.claude/dfcm/validate_receipt.py "$out/STOP-GC-26.9.23.json" "$out/GC23-0.json"
