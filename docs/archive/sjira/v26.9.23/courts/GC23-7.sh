#!/bin/sh
# GC23-7 court: Receipt / OCEL (PRD section 12; ARD sections 12 and 13;
# goal.ttl v23:GC23-7). Machinery: lane V23-D; receipt consistency and
# anti-vacuity: lane R1-X-COURTS.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed reference episode fmt-1:
#   1. the R projection receipt.r.json (the R laws, `r_laws` below):
#      a. ADMITTED by the fleet validator (validate_receipt.py: schema + ALIVE
#         replay exits + subject_sha is a commit of identity.repo);
#      b. its standing is ALIVE and it is bound to the sealed native receipt
#         (same head, same receipt digest, outcome alive);
#      c. it is internally consistent with the order it claims and the real
#         subject repository (GGEN_IGNITER_DIR), `mix xaas.episode
#         --verify-receipt` = `Xaas.Receipt.RProjection.consistency/2`:
#         ALIVE needs every acceptance true (falsifiers survived, required
#         courts passed), consequence.commits inside base_sha..subject_sha,
#         every recorded and observed changed file inside the order's
#         sj:pathScope, and every replay command equal to the command the
#         court binding recorded (the registered suite declaration that still
#         hashes to the bound argv_sha256) -- never a trivial command;
#   2. anti-vacuity: the court-owned receipt mutants (acceptance false under
#      ALIVE, a consequence commit that is not the subject's, files outside
#      the path scope, replay command `true`, a forged native digest, the
#      subject set to its base) are each REFUSED, typed, by the R laws;
#      (the actor mutant belongs to GC23-5);
#   3. ocel.json is valid under `mix xaas.ocel_validate` (the xaas OCEL 2.0
#      court vocabulary);
#   4. ocel2.json (the OCEL 2.0 standard JSON of the SAME observations) is read
#      by pm4py.read_ocel2_json, and the two renderings carry the same events
#      and objects;
#   5. every ARD section 13 class the episode reached is present -- and the
#      reached set covers the nine GC23-7 names (WorkOrderCreated,
#      CapabilityResolved, LeaseAcquired, ActuationStarted, ActuationCompleted,
#      VerificationCompleted, ReceiptSealed, StandingChanged, FrontierChanged).
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
validator=${DFCM_VALIDATOR:-$HOME/.claude/dfcm/validate_receipt.py}
cd "$xaas" || { echo "UNKNOWN: GC23-7 XAAS_DIR $xaas unreadable"; exit 75; }

for f in receipt.json receipt.r.json ocel.json ocel2.json drive.json work.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-7 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done
[ -f "$validator" ] || { echo "UNKNOWN: GC23-7 fleet receipt validator absent at $validator"; exit 75; }
python3 -c 'import pm4py' 2>/dev/null || { echo "UNKNOWN: GC23-7 pm4py not importable by python3"; exit 75; }
git -C "$ggen" rev-parse --git-dir >/dev/null 2>&1 ||
  { echo "UNKNOWN: GC23-7 GGEN_IGNITER_DIR $ggen is not a git checkout (the subject repository)"; exit 75; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-7.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-7 $*"; exit 1; }

# The R laws over one episode directory $1 (logs under $2). Prints one line:
# "ADMITTED ..." (return 0), "REFUSED(<reason>) broken_term=<term> ..."
# (return 1) or "UNKNOWN: ..." (return 75: the court cannot witness).
r_laws() {
  d=$1
  log=$2
  python3 "$validator" "$d/receipt.r.json" >"$log.validate" 2>&1
  if [ $? -ne 0 ] || ! grep -q '^ADMITTED ' "$log.validate"; then
    echo "REFUSED(r_not_admitted) broken_term=admission_vacuous $(sed -n 2p "$log.validate")"
    return 1
  fi
  python3 - "$d" <<'BIND' || return 1
import json, sys
d = sys.argv[1]
r = json.load(open(f"{d}/receipt.r.json")); n = json.load(open(f"{d}/receipt.json"))
def refused(reason, term, detail):
    print(f"REFUSED({reason}) broken_term={term} {detail}")
    sys.exit(1)
if r["standing"]["value"] != "ALIVE":
    refused("r_not_alive", "R_missing_standing", r["standing"]["value"])
if r["identity"]["subject_sha"] != n["final_head"]:
    refused("r_subject_not_sealed_head", "R_missing_identity",
            f"subject_sha={r['identity']['subject_sha']} final_head={n['final_head']}")
if r["native"]["receipt_digest"] != n["receipt_digest"] or r["native"]["outcome"] != "alive":
    refused("r_native_unbound", "R_missing_identity",
            f"native={r['native'].get('receipt_digest')} sealed={n['receipt_digest']}")
if not (r["replay"]["commands"] and all(c["exit"] == 0 for c in r["replay"]["commands"])):
    refused("alive_replay_failed", "admission_vacuous", r["replay"]["commands"])
BIND
  MIX_ENV=test mix xaas.episode --verify-receipt "$d" --ggen-igniter-dir "$ggen" >"$log.consistency" 2>&1
  code=$?
  verdict=$(python3 - "$log.consistency" <<'VERDICT'
import json, sys
for line in reversed(open(sys.argv[1]).read().splitlines()):
    line = line.strip()
    if line.startswith("{"):
        j = json.loads(line)
        if j.get("standing") == "CONSISTENT":
            print(f"ADMITTED consistent: {j['subject']} at {j['subject_sha']}, commits {len(j['commits'])}, "
                  f"files {j['files']} within {j['path_scope']}, replay `{j['replay_command']}`")
        else:
            d = j.get("detail") or {}
            why = d.get("reason") or d.get("field") or ""
            print(f"{j.get('standing')} broken_term={j.get('broken_term')} {why}".strip())
        break
else:
    print("no typed JSON line from mix xaas.episode --verify-receipt")
VERDICT
)
  echo "$verdict"
  case "$code:$verdict" in
    0:ADMITTED*) return 0 ;;
    3:BLOCKED*) return 75 ;;
    *) return 1 ;;
  esac
}

# 1. R projection laws on the committed episode
line=$(r_laws "$ep" "$tmp/r")
code=$?
case "$code" in
  0) echo "R: $line" ;;
  75) echo "UNKNOWN: GC23-7 the R laws cannot be witnessed: $line"; exit 75 ;;
  *) tail -5 "$tmp/r.consistency" 2>/dev/null; refuse "receipt.r.json: $line" ;;
esac
echo "validator: $(head -1 "$tmp/r.validate")"

# 2. anti-vacuity: every court-owned receipt mutant is refused by the R laws
python3 - "$ep" "$tmp/mutants" <<'MUT' || refuse "could not build the receipt mutants"
import copy, json, os, shutil, sys
ep, out = sys.argv[1], sys.argv[2]
r0 = json.load(open(f"{ep}/receipt.r.json"))
def m(fn):
    r = copy.deepcopy(r0); fn(r); return r
muts = {
  "court_acceptance_false_but_alive": m(lambda r: r["court"]["acceptance_results"].update(
      {k: False for k in r["court"]["acceptance_results"]})),
  "consequence_commit_not_subject": m(lambda r: r["consequence"].__setitem__(
      "commits", [r["identity"]["base_sha"]])),
  "files_changed_outside_scope": m(lambda r: r["consequence"].__setitem__(
      "files_changed", ["mix.lock", "priv/secret.key"])),
  "replay_cmd_swapped": m(lambda r: r["replay"]["commands"][0].__setitem__("cmd", "true")),
  "native_digest_forged": m(lambda r: r["native"].__setitem__("receipt_digest", "sha256:" + "0" * 64)),
  "subject_sha_is_base": m(lambda r: r["identity"].__setitem__("subject_sha", r["identity"]["base_sha"])),
}
for name, rec in muts.items():
    d = f"{out}/{name}"
    os.makedirs(d)
    for f in ("receipt.json", "work.json", "drive.json"):
        shutil.copy(f"{ep}/{f}", f"{d}/{f}")
    json.dump(rec, open(f"{d}/receipt.r.json", "w"), indent=1)
print(" ".join(muts))
MUT
for m in court_acceptance_false_but_alive consequence_commit_not_subject files_changed_outside_scope \
  replay_cmd_swapped native_digest_forged subject_sha_is_base; do
  line=$(r_laws "$tmp/mutants/$m" "$tmp/mutants/$m.log")
  code=$?
  case "$code:$line" in
    1:REFUSED\(*) echo "mutant $m: $line" ;;
    75:*) echo "UNKNOWN: GC23-7 mutant $m cannot be judged: $line"; exit 75 ;;
    *) refuse "anti-vacuity: mutant $m escaped the R laws ($line)" ;;
  esac
done

# 3. xaas OCEL court
if ! MIX_ENV=test mix xaas.ocel_validate "$ep/ocel.json" >"$tmp/ocel.log" 2>&1; then
  tail -20 "$tmp/ocel.log"
  refuse "ocel.json refused by mix xaas.ocel_validate"
fi
echo "ocel_validate: $(tail -1 "$tmp/ocel.log")"

# 4 + 5. pm4py + equivalence + reached classes
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

echo "ALIVE: GC23-7 receipt ADMITTED and consistent with its order and subject (6 receipt mutants refused), OCEL conformant (xaas court + pm4py) on episode fmt-1"
exit 0
