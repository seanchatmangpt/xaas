#!/bin/sh
# GC23-4 court: SA2A Conservation (PRD section 12, PR-008; ARD section 8;
# goal.ttl v23:GC23-4). Machinery: lane V23-D (Xaas.Ultracode.SemanticDrive).
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed reference episode fmt-1
# (docs/sjira/v26.9.23/episodes/fmt-1):
#   1. the FRI-T4 route conservation table (test/xaas/sa2a/route_test.exs);
#   2. an independent python3 recompute of BOTH digests at every hop of
#      hops.json -- the Route contract tuple digest and the ARD section 8
#      SemanticExecutionRequest digest (work_order, subject, postcondition,
#      capability, evidence_horizon, authority_ceiling, consequence_class,
#      exclusions, graph_digest) -- all equal across sJira -> SA2A -> XaaS ->
#      provider -> receipt, and each hop's values re-derived from the
#      committed carrier artifacts (work.json + frontier_before.json,
#      sa2a_task.json, contract.json, receipt.json), so hops.json does not
#      certify itself;
#   3. the Elixir replay `mix xaas.episode --verify-hops` admits the hops;
#   4. F2: a mutated-hop replay is REFUSED(tuple_digest_mismatch) -- both a
#      tuple field changed under its recorded digest and a consistent forgery
#      (field + both digests rewritten at one hop).
set -u

xaas=${XAAS_DIR:-$(pwd)}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
cd "$xaas" || { echo "UNKNOWN: GC23-4 XAAS_DIR $xaas unreadable"; exit 75; }

for f in hops.json work.json frontier_before.json sa2a_task.json contract.json receipt.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-4 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-4.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-4 $*"; exit 1; }

# 1. route conservation table
if ! MIX_ENV=test mix test test/xaas/sa2a/route_test.exs >"$tmp/route.log" 2>&1; then
  tail -30 "$tmp/route.log"
  refuse "route_test failed"
fi
grep -Eq '[0-9]+ tests?, 0 failures' "$tmp/route.log" || refuse "route_test reported no clean summary"
echo "route_test: $(grep -E '[0-9]+ tests?, 0 failures' "$tmp/route.log" | tail -1)"

# 2. independent recompute + carrier re-derivation
python3 - "$ep" <<'PY' || refuse "hop digests do not recompute, disagree, or do not match their carriers"
import hashlib, json, sys
ep = sys.argv[1]
load = lambda n: json.load(open(f"{ep}/{n}", encoding="utf-8"))
TUPLE = ["subject", "postcondition", "capability", "evidence_ceiling", "authority_ceiling",
         "consequence_class", "exclusions"]
REQUEST = ["work_order", "subject", "postcondition", "capability", "evidence_horizon",
           "authority_ceiling", "consequence_class", "exclusions", "graph_digest"]
HOPS = ["sjira", "sa2a", "xaas", "provider", "receipt"]

def digest(value, fields):
    assert sorted(value) == sorted(fields), f"fields {sorted(value)} != {sorted(fields)}"
    t = dict(value)
    t["exclusions"] = sorted(t["exclusions"])
    b = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(b.encode("utf-8")).hexdigest()

hops = load("hops.json")["hops"]
names = [h["hop"] for h in hops]
assert names == HOPS, f"hops {names} != {HOPS}"
for h in hops:
    assert digest(h["tuple"], TUPLE) == h["digest"], f"{h['hop']}: tuple digest does not recompute"
    assert digest(h["request"], REQUEST) == h["request_digest"], f"{h['hop']}: request digest does not recompute"
assert len({h["digest"] for h in hops}) == 1, "tuple digests differ across hops"
assert len({h["request_digest"] for h in hops}) == 1, "request digests differ across hops"
by = {h["hop"]: h for h in hops}

# carriers: the recorded hop values are the committed artifacts' values
work = load("work.json")
row = next(r for r in work["work_orders"] if r["identity"] == "EP-A")
admitted = next(e for e in load("frontier_before.json")["eligible"] if e["identity"] == "EP-A")
sj = by["sjira"]["request"]
assert sj["work_order"] == row["identity"] and sj["subject"] == row["subject"]
assert sj["capability"] == row["requires_capability"] and sj["postcondition"] == row["postcondition"]
assert sj["evidence_horizon"] == row["evidence_horizon"] and sorted(sj["exclusions"]) == sorted(row["exclusions"])
assert sj["authority_ceiling"] == row["authority_ceiling"] and sj["consequence_class"] == row["consequence_class"]
assert sj["graph_digest"] == admitted["work_order_digest"], "sJira graph_digest is not the frontier's admitted digest"

task = load("sa2a_task.json")
carrier = next(p["data"] for p in task["input"] if p.get("kind") == "data"
               and p["data"].get("schema") == "semantic-jira/route-tuple/v1")
sa = by["sa2a"]["request"]
assert sa["work_order"] == carrier["tuple"]["workOrder"] and sa["graph_digest"] == carrier["workOrderDigest"]
assert sa["capability"] == carrier["tuple"]["requiresCapability"] and sa["subject"] == carrier["tuple"]["subject"]
assert task["contextId"] == carrier["workOrderDigest"]

bridge = load("contract.json")["bridge"]
xa = by["xaas"]["request"]
assert xa["work_order"] == bridge["identity"] and xa["graph_digest"] == bridge["source_snapshot_digest"]
assert xa["capability"] == load("contract.json")["capability"] == bridge["requires_capability"]

rb = load("receipt.json")["bridge"]
re_ = by["receipt"]["request"]
assert re_["work_order"] == rb["identity"] and re_["graph_digest"] == rb["source_snapshot_digest"]
assert re_["capability"] == rb["requires_capability"] and re_["subject"] == rb["subject"]
assert by["provider"]["executor"] == "recipe-worker"
print(f"hops: 5 hops, tuple {hops[0]['digest']}, request {hops[0]['request_digest']}, carriers re-derived")
PY

# 3. Elixir replay admits the recorded hops
if ! MIX_ENV=test mix xaas.episode --verify-hops "$ep/hops.json" >"$tmp/verify.log" 2>&1; then
  tail -5 "$tmp/verify.log"
  refuse "mix xaas.episode --verify-hops refused the committed hops"
fi
echo "verify-hops: $(tail -1 "$tmp/verify.log")"

# 4. F2: mutated-hop replays are refused
python3 - "$ep/hops.json" "$tmp" <<'PY' || refuse "could not build the F2 mutations"
import hashlib, json, sys
src, tmp = sys.argv[1], sys.argv[2]
def digest(value):
    t = dict(value); t["exclusions"] = sorted(t["exclusions"])
    b = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(b.encode("utf-8")).hexdigest()
doc = json.load(open(src, encoding="utf-8"))
a = json.loads(json.dumps(doc))
a["hops"][1]["tuple"]["postcondition"] += " (mutated)"
json.dump(a, open(f"{tmp}/f2-underneath.json", "w"))
b = json.loads(json.dumps(doc))
hop = b["hops"][3]
hop["tuple"]["postcondition"] += " (forged)"
hop["request"]["postcondition"] += " (forged)"
hop["digest"] = digest(hop["tuple"])
hop["request_digest"] = digest(hop["request"])
json.dump(b, open(f"{tmp}/f2-forged.json", "w"))
PY
for m in f2-underneath f2-forged; do
  MIX_ENV=test mix xaas.episode --verify-hops "$tmp/$m.json" >"$tmp/$m.log" 2>&1
  code=$?
  [ "$code" = "3" ] || { tail -3 "$tmp/$m.log"; refuse "F2 $m: verify-hops exited $code, expected 3 (refused)"; }
  grep -q 'REFUSED(tuple_digest_mismatch)' "$tmp/$m.log" || refuse "F2 $m: refusal is not tuple_digest_mismatch"
  echo "F2 $m: $(tail -1 "$tmp/$m.log")"
done

echo "ALIVE: GC23-4 SA2A conservation witnessed on episode fmt-1 (5 equal hop digests, F2 refused)"
exit 0
