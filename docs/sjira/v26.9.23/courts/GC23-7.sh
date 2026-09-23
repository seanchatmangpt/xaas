#!/bin/sh
# GC23-7 court: Receipt / OCEL (PRD section 12; ARD sections 12 and 13;
# goal.ttl v23:GC23-7). Machinery: lane V23-D.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed reference episode fmt-1:
#   1. the R projection receipt.r.json is ADMITTED by the fleet validator
#      (validate_receipt.py: schema + ALIVE replay exits + subject_sha is a
#      commit of identity.repo), its standing is ALIVE, and it is bound to the
#      sealed native receipt (same head, same receipt digest);
#   2. ocel.json is valid under `mix xaas.ocel_validate` (the xaas OCEL 2.0
#      court vocabulary);
#   3. ocel2.json (the OCEL 2.0 standard JSON of the SAME observations) is read
#      by pm4py.read_ocel2_json, and the two renderings carry the same events
#      and objects;
#   4. every ARD section 13 class the episode reached is present -- and the
#      reached set covers the nine GC23-7 names (WorkOrderCreated,
#      CapabilityResolved, LeaseAcquired, ActuationStarted, ActuationCompleted,
#      VerificationCompleted, ReceiptSealed, StandingChanged, FrontierChanged).
set -u

xaas=${XAAS_DIR:-$(pwd)}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
validator=${DFCM_VALIDATOR:-$HOME/.claude/dfcm/validate_receipt.py}
cd "$xaas" || { echo "UNKNOWN: GC23-7 XAAS_DIR $xaas unreadable"; exit 75; }

for f in receipt.json receipt.r.json ocel.json ocel2.json drive.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-7 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done
[ -f "$validator" ] || { echo "UNKNOWN: GC23-7 fleet receipt validator absent at $validator"; exit 75; }
python3 -c 'import pm4py' 2>/dev/null || { echo "UNKNOWN: GC23-7 pm4py not importable by python3"; exit 75; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-7.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-7 $*"; exit 1; }

# 1. R projection
python3 "$validator" "$ep/receipt.r.json" >"$tmp/validate.log" 2>&1 ||
  { cat "$tmp/validate.log"; refuse "receipt.r.json is not ADMITTED"; }
grep -q '^ADMITTED ' "$tmp/validate.log" || refuse "validator printed no ADMITTED line"
echo "validator: $(head -1 "$tmp/validate.log")"
python3 - "$ep" <<'PY' || refuse "the R projection is not ALIVE or not bound to the sealed receipt"
import json, sys
ep = sys.argv[1]
r = json.load(open(f"{ep}/receipt.r.json")); n = json.load(open(f"{ep}/receipt.json"))
assert r["standing"]["value"] == "ALIVE", r["standing"]
assert r["identity"]["subject_sha"] == n["final_head"]
assert r["native"]["receipt_digest"] == n["receipt_digest"] and r["native"]["outcome"] == "alive"
assert r["replay"]["commands"] and all(c["exit"] == 0 for c in r["replay"]["commands"])
print(f"R: ALIVE at {n['final_head']}, native {n['receipt_digest']}")
PY

# 2. xaas OCEL court
if ! MIX_ENV=test mix xaas.ocel_validate "$ep/ocel.json" >"$tmp/ocel.log" 2>&1; then
  tail -20 "$tmp/ocel.log"
  refuse "ocel.json refused by mix xaas.ocel_validate"
fi
echo "ocel_validate: $(tail -1 "$tmp/ocel.log")"

# 3 + 4. pm4py + equivalence + reached classes
python3 - "$ep" <<'PY' || refuse "pm4py, equivalence or reached-class check failed"
import json, sys
import pm4py
ep = sys.argv[1]
court = json.load(open(f"{ep}/ocel.json")); std = json.load(open(f"{ep}/ocel2.json"))
drive = json.load(open(f"{ep}/drive.json"))
log = pm4py.read_ocel2_json(f"{ep}/ocel2.json")
assert len(log.events) == len(court["ocel:events"]) == len(std["events"]), "event counts differ"
assert len(log.objects) == len(court["ocel:objects"]) == len(std["objects"]), "object counts differ"
ce = [(e["id"], e["type"], e["time"], e["attributes"], e["relationships"]) for e in court["ocel:events"]]
se = [(e["id"], e["type"], e["time"], {a["name"]: a["value"] for a in e["attributes"]}, e["relationships"])
      for e in std["events"]]
assert ce == se, "ocel.json and ocel2.json carry different events"
co = [(o["id"], o["type"], o["attributes"], o["relationships"]) for o in court["ocel:objects"]]
so = [(o["id"], o["type"], {a["name"]: a["value"] for a in o["attributes"]}, o["relationships"])
      for o in std["objects"]]
assert co == so, "ocel.json and ocel2.json carry different objects"
classes = set(log.events["ocel:activity"].unique())
reached = drive["ocel"]["reached"]
missing = [c for c in reached if c not in classes]
assert not missing, f"reached classes absent from the log: {missing}"
required = ["WorkOrderCreated", "CapabilityResolved", "LeaseAcquired", "ActuationStarted",
            "ActuationCompleted", "VerificationCompleted", "ReceiptSealed", "StandingChanged",
            "FrontierChanged"]
assert all(c in reached for c in required), f"episode did not reach {set(required) - set(reached)}"
types = set(log.objects["ocel:type"].unique())
print(f"pm4py: {len(log.events)} events, {len(log.objects)} objects, classes {sorted(classes)}, object types {sorted(types)}")
PY

echo "ALIVE: GC23-7 receipt ADMITTED and OCEL conformant (xaas court + pm4py) on episode fmt-1"
exit 0
