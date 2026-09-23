#!/bin/sh
# GC23-9 court: MachineExperience (PRD section 12, PR-014/PR-016; ARD sections
# 13 and 15; goal.ttl v23:GC23-9). Machinery: lane V23-M.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed episodes me-1 (UNKNOWN -> exploration ->
# verified result -> MachineExperience) and me-2 (new subject -> applicability
# match -> KNOWN -> deterministic route), docs/sjira/v26.9.23/episodes/:
#   1. me-1 was UNKNOWN before any exploration: its orders declare no
#      capability (failure_class format_drift only); unknown/route.json is
#      UNKNOWN(no_capability_no_experience) with zero experiences considered
#      and unknown/unknown.json (standing UNKNOWN) is ADMITTED by the fleet
#      validator;
#   2. the exploration was bounded (PR-016): exploration.json carries the five
#      budget fields and its producer; the episode used no more than the
#      budget; its sha256 is the route's and the admission's
#      sourceExploration;
#   3. the explored candidate ran through the no-LLM drive to ALIVE: the R
#      projection is ADMITTED and ALIVE, the independent court passed, the
#      revert falsifier killed;
#   4. the MachineExperience is admitted: machine_experience.ttl holds one
#      sj:MachineExperience (standing CANDIDATE, authority NONE) linked from one
#      xme:AdmittedExperience ADMITTED node carrying every ARD section 15 field;
#      ggen_igniter's SHACL court in GGEN_IGNITER_DIR (private MIX_BUILD_PATH
#      clone) finds it conformant under sj:MachineExperienceShape (one focus
#      node) AND refuses a mutation of it (standing ALIVE) -- the shape judged
#      the node; me-1's OCEL has MachineExperienceAdmitted citing the IRI;
#   5. both OCEL logs are valid under mix xaas.ocel_validate and read by
#      pm4py.read_ocel2_json with the same event and object counts;
#   6. the ratchet, measured from the two OCEL logs: me-2 has 0 LLM-provider
#      events and 0 exploration events (me-1 has >= 1 of each: the detector
#      fires), strictly fewer events and steps than me-1, no exploration
#      artifact, no declared capability and no capability literal in its work
#      graph; its route (route.json, RouteDecided, CapabilityResolved) cites
#      the MachineExperience IRI of me-1's graph and takes the capability from
#      its xme:admittedCapability; rdflib (an independent SPARQL engine)
#      evaluates the admitted applicability predicate over me-2's recorded
#      order.ttl and selects that order;
#   7. live route: mix xaas.machine_experience --route over me-2's work graph
#      and me-1's admitted graph (F3 no-LLM env) is KNOWN from the same IRI;
#      with an LLM credential exposed it is REFUSED(llm_credential_present);
#   8. falsifier: with the sj:MachineExperience node removed from the graph
#      (and, separately, with its admission node removed) the same route is
#      UNKNOWN; with the admitted predicate replaced by one SPARQL cannot
#      evaluate the route is REFUSED(experience_predicate_unevaluable) (exit
#      3: the router fails closed, it never reports "no experience" for one
#      it could not judge); and the episode runner on a copy of me-2 refuses
#      to execute: exit 4, UNKNOWN, no drive, unknown/unknown.json written.
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}
eps=${GC23_EPISODES_DIR:-$xaas/docs/sjira/v26.9.23/episodes}
validator=${DFCM_VALIDATOR:-$HOME/.claude/dfcm/validate_receipt.py}
ep1=$eps/me-1
ep2=$eps/me-2
cd "$xaas" || { echo "UNKNOWN: GC23-9 XAAS_DIR $xaas unreadable"; exit 75; }

for f in work.json exploration.json route.json episode.json ocel.json ocel2.json order.ttl \
  machine_experience.ttl machine_experience.json unknown/route.json unknown/unknown.json \
  drive/receipt.r.json drive/verification.json; do
  [ -f "$ep1/$f" ] || { echo "UNKNOWN: GC23-9 episode me-1 has no $f (episode not driven)"; exit 75; }
done
for f in work.json route.json episode.json ocel.json ocel2.json order.ttl drive/receipt.r.json; do
  [ -f "$ep2/$f" ] || { echo "UNKNOWN: GC23-9 episode me-2 has no $f (episode not driven)"; exit 75; }
done
[ -f "$validator" ] || { echo "UNKNOWN: GC23-9 fleet receipt validator absent at $validator"; exit 75; }
python3 -c 'import pm4py, rdflib' 2>/dev/null || { echo "UNKNOWN: GC23-9 pm4py/rdflib not importable by python3"; exit 75; }
[ -f "$xaas/scripts/machine_experience.exs" ] || { echo "UNKNOWN: GC23-9 scripts/machine_experience.exs absent"; exit 75; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-9.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-9 $*"; exit 1; }
env_sh="$xaas/docs/sjira/v26.9.23/courts/no_llm_env.sh"

# 1 + 3: receipts (fleet validator)
for r in "$ep1/unknown/unknown.json" "$ep1/drive/receipt.r.json" "$ep2/drive/receipt.r.json"; do
  python3 "$validator" "$r" >"$tmp/validate.log" 2>&1 || { cat "$tmp/validate.log"; refuse "$r is not ADMITTED"; }
  echo "validator: $(head -1 "$tmp/validate.log")"
done

# 1..6: the recorded episodes
python3 - "$ep1" "$ep2" "$tmp" <<'PY' || refuse "the recorded episodes do not witness the ratchet"
import hashlib, json, sys
import pm4py, rdflib

ep1, ep2, tmp = sys.argv[1:4]
load = lambda d, n: json.load(open(f"{d}/{n}", encoding="utf-8"))
sha = lambda path: "sha256:" + hashlib.sha256(open(path, "rb").read()).hexdigest()
SJ = rdflib.Namespace("https://ggen-igniter.dev/ontology/semantic-jira#")
XME = rdflib.Namespace("https://xaas.dev/ontology/machine-experience#")
LLM = ("llm", "claude", "anthropic", "openai", "zcode", "glm", "zai")

# 1. me-1 was UNKNOWN before exploration; neither episode declares a capability
for ep in (ep1, ep2):
    rows = load(ep, "work.json")["work_orders"]
    assert rows and all("requires_capability" not in r for r in rows), f"{ep}: an order declares a capability"
    assert all(r.get("failure_class") == "format_drift" for r in rows), f"{ep}: failure_class"
assert "recipe:mix-format" not in open(f"{ep2}/work.json", encoding="utf-8").read(), "me-2 work graph names the capability literally"
first = load(ep1, "unknown/route.json")
assert first["decision"] == "UNKNOWN" and first["route"]["reason"] == "no_capability_no_experience", first
assert first["route"]["detail"]["experiences_considered"] == [], first["route"]["detail"]
unknown = load(ep1, "unknown/unknown.json")
assert unknown["standing"]["value"] == "UNKNOWN" and unknown["consequence"]["commits"] == []

# 2. bounded exploration
exploration = load(ep1, "exploration.json")
budget = exploration["budget"]
for k in ("time_s", "drive_runs", "candidates", "consequence_ceiling", "evidence_requirement"):
    assert k in budget, f"exploration budget lacks {k}"
assert exploration["producer"].strip(), "exploration producer"
e1 = load(ep1, "episode.json"); e2 = load(ep2, "episode.json")
used = e1["exploration"]["used"]
assert used["drive_runs"] <= budget["drive_runs"] and used["candidates"] <= budget["candidates"], used
assert used["elapsed_s"] <= budget["time_s"], used
xdigest = sha(f"{ep1}/exploration.json")
assert e1["route"]["source"] == "exploration" and e1["route"]["exploration_digest"] == xdigest, e1["route"]
assert e1["decision"] == "UNKNOWN" and e1["standing"] == "ALIVE"

# 3. the candidate's drive
v = load(ep1, "drive/verification.json")
assert v["independent"]["status"] == "pass" and v["revert_falsifier"]["verdict"] == "killed", v.keys()
for ep in (ep1, ep2):
    assert load(ep, "drive/receipt.r.json")["standing"]["value"] == "ALIVE"

# 4. the admitted MachineExperience graph
g = rdflib.Graph(); g.parse(f"{ep1}/machine_experience.ttl", format="turtle")
mes = list(g.subjects(rdflib.RDF.type, SJ.MachineExperience))
adms = list(g.subjects(rdflib.RDF.type, XME.AdmittedExperience))
assert len(mes) == 1 and len(adms) == 1, (mes, adms)
me, adm = mes[0], adms[0]
assert (adm, XME.experience, me) in g and str(g.value(adm, XME.admission)) == "ADMITTED"
assert str(g.value(me, SJ.standing)) == "CANDIDATE" and str(g.value(me, SJ.authorityClaim)) == "NONE"
for f in ("problemClass", "applicabilityPredicate", "admittedCapability", "providerClass",
          "requiredEvidence", "falsifier", "successfulVerification", "consequenceBounds", "sourceEpisode"):
    assert list(g.objects(adm, XME[f])), f"ARD section 15 field {f} missing"
assert str(g.value(adm, XME.sourceExploration)) == xdigest
capability = str(g.value(adm, XME.admittedCapability))
assert e1["machine_experience"]["machine_experience"] == str(me)
o1 = load(ep1, "ocel.json"); o2 = load(ep2, "ocel.json")
admitted = [e for e in o1["ocel:events"] if e["type"] == "MachineExperienceAdmitted"]
assert len(admitted) == 1 and admitted[0]["attributes"]["machine_experience"] == str(me)

# 5. OCEL: pm4py reads both standard logs, same counts as the court logs
for ep, court in ((ep1, o1), (ep2, o2)):
    log = pm4py.read_ocel2_json(f"{ep}/ocel2.json")
    assert len(log.events) == len(court["ocel:events"]) and len(log.objects) == len(court["ocel:objects"]), ep

# 6. the ratchet, measured from OCEL
def measure(o):
    nondet = {x["id"] for x in o["ocel:objects"]
              if x["type"] == "Provider" and (x["attributes"].get("deterministic") == "false"
                                             or any(w in x["id"].lower() for w in LLM))}
    llm = [e["id"] for e in o["ocel:events"]
           if any(r["objectId"] in nondet for r in e["relationships"])
           or any(w in str(e["attributes"].get(k, "")).lower() for k in ("provider", "producer", "candidate_producer") for w in LLM)]
    explore = [e["id"] for e in o["ocel:events"] if e["type"].startswith("Exploration")]
    return llm, explore
llm1, x1 = measure(o1); llm2, x2 = measure(o2)
assert llm1 and x1, f"anti-vacuity: the detectors do not fire on me-1 (llm {llm1}, exploration {x1})"
assert llm2 == [] and x2 == [], f"me-2 LLM-provider events {llm2}, exploration events {x2}"
import os
assert not os.path.exists(f"{ep2}/exploration.json"), "me-2 has an exploration artifact"
n1, n2 = len(o1["ocel:events"]), len(o2["ocel:events"])
assert n2 < n1, f"me-2 has {n2} events, me-1 {n1}"
assert e2["step_count"] < e1["step_count"] == len(e1["steps"]), (e1["step_count"], e2["step_count"])
route2 = load(ep2, "route.json")
r = route2["route"]
assert route2["decision"] == "KNOWN" and r["source"] == "machine_experience", route2
assert r["machine_experience"] == str(me) and r["capability"] == capability, r
assert r["experience_digest"] == str(g.value(me, SJ.experienceDigest))
assert e2["route"] == {**e2["route"], "machine_experience": str(me)} and e2["decision"] == "KNOWN"
cited = f"machine-experience:{me}"
for kind in ("RouteDecided", "CapabilityResolved"):
    ev = [e for e in o2["ocel:events"] if e["type"] == kind]
    assert len(ev) == 1 and any(x["objectId"] == cited for x in ev[0]["relationships"]), f"me-2 {kind} does not cite {me}"
    assert ev[0]["attributes"].get("machine_experience") == str(me)
assert sha(f"{ep2}/order.ttl") == route2["order_turtle_sha256"], "order.ttl is not the routed rendering"
og = rdflib.Graph(); og.parse(f"{ep2}/order.ttl", format="turtle")
rows = [str(x[0]) for x in og.query(str(g.value(adm, XME.applicabilityPredicate)))]
assert rows == [route2["order_iri"]], f"rdflib predicate selects {rows}, route order {route2['order_iri']}"

# the falsifier graphs for step 8
no_me = rdflib.Graph(); no_me.parse(f"{ep1}/machine_experience.ttl", format="turtle")
no_me.remove((me, None, None)); no_me.serialize(f"{tmp}/no-me.ttl", format="turtle")
no_adm = rdflib.Graph(); no_adm.parse(f"{ep1}/machine_experience.ttl", format="turtle")
no_adm.remove((adm, None, None)); no_adm.serialize(f"{tmp}/no-admission.ttl", format="turtle")
promoted = rdflib.Graph(); promoted.parse(f"{ep1}/machine_experience.ttl", format="turtle")
promoted.set((me, SJ.standing, rdflib.Literal("ALIVE"))); promoted.serialize(f"{tmp}/promoted.ttl", format="turtle")
unevaluable = rdflib.Graph(); unevaluable.parse(f"{ep1}/machine_experience.ttl", format="turtle")
unevaluable.set((adm, XME.applicabilityPredicate, rdflib.Literal("SELECT nonsense")))
unevaluable.serialize(f"{tmp}/unevaluable.ttl", format="turtle")
open(f"{tmp}/me.iri", "w").write(str(me))
print(f"recorded: me-1 {n1} events / {e1['step_count']} steps (LLM-provider {len(llm1)}, exploration {len(x1)}); "
      f"me-2 {n2} events / {e2['step_count']} steps (LLM-provider 0, exploration 0); route cites {me} -> {capability}")
PY

# 4 (live): ggen_igniter's SHACL court in GGEN_IGNITER_DIR, private build clone
[ -f "$ggen/lib/ggen_igniter/semantic_jira/shacl.ex" ] || { echo "UNKNOWN: GC23-9 GGEN_IGNITER_DIR $ggen has no SemanticJira.Shacl"; exit 75; }
mkdir -p "$tmp/build"
if [ -d "$ggen/_build/test" ]; then cp -cRp "$ggen/_build/test" "$tmp/build/test" 2>/dev/null || cp -Rp "$ggen/_build/test" "$tmp/build/test"; fi
MIX_ENV=test mix xaas.episode --graph-toolchain --ggen-igniter-dir "$ggen" \
  --ggen-build-path "$tmp/build/test" >"$tmp/toolchain.log" 2>&1 || {
  tail -5 "$tmp/toolchain.log"; echo "UNKNOWN: GC23-9 no graph-side toolchain resolves for $ggen"; exit 75; }
python3 - "$tmp/toolchain.log" "$tmp" <<'PY' || { echo "UNKNOWN: GC23-9 unreadable graph-side toolchain"; exit 75; }
import json, sys
log, tmp = sys.argv[1], sys.argv[2]
for line in reversed(open(log).read().splitlines()):
    if line.strip().startswith("{"):
        t = json.loads(line.strip()); break
else:
    raise SystemExit("no toolchain JSON")
open(f"{tmp}/toolchain.mix", "w").write(t["mix"]); open(f"{tmp}/toolchain.path", "w").write(t["path"])
PY
tmix=$(cat "$tmp/toolchain.mix"); tpath=$(cat "$tmp/toolchain.path")
shacl() {
  (cd "$ggen" && env PATH="$tpath" MIX_ENV=test MIX_BUILD_PATH="$tmp/build/test" "$tmix" run --no-start \
    "$xaas/scripts/machine_experience.exs" validate "$1" </dev/null) >"$2" 2>&1
}
shacl "$ep1/machine_experience.ttl" "$tmp/shacl.out"; code=$?
if grep -q -e '== Compilation error' -e 'could not compile dependency' "$tmp/shacl.out"; then
  tail -5 "$tmp/shacl.out"; echo "UNKNOWN: GC23-9 the graph side in $ggen does not compile (BUILD_BROKEN)"; exit 75
fi
[ "$code" = "0" ] || { tail -5 "$tmp/shacl.out"; refuse "machine_experience.ttl refused by the ggen_igniter SHACL court (exit $code)"; }
python3 - "$tmp/shacl.out" <<'PY' || refuse "the SHACL report does not judge the MachineExperience node"
import json, sys
line = [l for l in open(sys.argv[1]).read().splitlines() if l.strip().startswith("{")][-1]
r = json.loads(line)
assert r["conforms"] and "machine_experience_shape" in r["shapes_checked"] and r["focus_node_count"] >= 1, r
print(f"shacl: conforms, machine_experience_shape, focus nodes {r['focus_node_count']}, shapes {r['shapes_sha256'][:19]}")
PY
shacl "$tmp/promoted.ttl" "$tmp/promoted.out"; code=$?
[ "$code" = "1" ] || { tail -5 "$tmp/promoted.out"; refuse "anti-vacuity: the shape court admitted a MachineExperience promoted to ALIVE (exit $code)"; }
grep -q '"conforms":false' "$tmp/promoted.out" || refuse "anti-vacuity: no conforms=false report for the promoted mutation"
echo "shacl anti-vacuity: standing ALIVE mutation refused"

# 5 (live): the xaas OCEL court on both logs
for ep in "$ep1" "$ep2"; do
  MIX_ENV=test mix xaas.ocel_validate "$ep/ocel.json" >"$tmp/ocel.log" 2>&1 || { tail -20 "$tmp/ocel.log"; refuse "$ep/ocel.json refused by mix xaas.ocel_validate"; }
  echo "ocel_validate $(basename "$ep"): $(tail -1 "$tmp/ocel.log")"
done

# 7. live route (no-LLM env) + F3 on the ratchet path
me_iri=$(cat "$tmp/me.iri")
MIX_ENV=test sh "$env_sh" -- mix xaas.machine_experience --route --work "$ep2/work.json" \
  --experience "$ep1/machine_experience.ttl" >"$tmp/route.log" 2>&1
code=$?
if [ "$code" = "75" ]; then tail -1 "$tmp/route.log"; echo "UNKNOWN: GC23-9 no-LLM env unbuildable"; exit 75; fi
[ "$code" = "0" ] || { tail -3 "$tmp/route.log"; refuse "live route over the admitted graph exited $code, expected 0 (KNOWN)"; }
tail -1 "$tmp/route.log" | python3 -c '
import json, sys
r = json.loads(sys.stdin.read()); iri = sys.argv[1]
assert r["standing"] == "KNOWN" and r["source"] == "machine_experience" and r["machine_experience"] == iri, r
' "$me_iri" || refuse "live route is not KNOWN from $me_iri"
echo "live route: KNOWN from $me_iri"
MIX_ENV=test sh "$env_sh" ANTHROPIC_API_KEY=x -- mix xaas.machine_experience --route --work "$ep2/work.json" \
  --experience "$ep1/machine_experience.ttl" >"$tmp/f3.log" 2>&1
code=$?
[ "$code" = "3" ] && tail -1 "$tmp/f3.log" | grep -q 'REFUSED(llm_credential_present)' ||
  { tail -3 "$tmp/f3.log"; refuse "F3: route with ANTHROPIC_API_KEY=x exited $code, expected REFUSED(llm_credential_present)"; }
echo "F3: route refused with an exposed credential"

# 8. falsifier: no admitted experience -> UNKNOWN, nothing executes
for g in no-me no-admission; do
  MIX_ENV=test sh "$env_sh" -- mix xaas.machine_experience --route --work "$ep2/work.json" \
    --experience "$tmp/$g.ttl" >"$tmp/$g.log" 2>&1
  code=$?
  [ "$code" = "4" ] && tail -1 "$tmp/$g.log" | grep -q '"reason":"no_capability_no_experience"' ||
    { tail -3 "$tmp/$g.log"; refuse "falsifier: route over the $g graph exited $code, expected 4 UNKNOWN"; }
  echo "falsifier ($g): UNKNOWN"
done
MIX_ENV=test sh "$env_sh" -- mix xaas.machine_experience --route --work "$ep2/work.json" \
  --experience "$tmp/unevaluable.ttl" >"$tmp/unevaluable.log" 2>&1
code=$?
[ "$code" = "3" ] && tail -1 "$tmp/unevaluable.log" | grep -q '"reason":"experience_predicate_unevaluable"' ||
  { tail -3 "$tmp/unevaluable.log"; refuse "falsifier: route over an admitted experience with an unevaluable predicate exited $code, expected 3 REFUSED(experience_predicate_unevaluable) (fail closed, never 'no experience')"; }
echo "falsifier (unevaluable predicate): REFUSED(experience_predicate_unevaluable)"
mkdir -p "$tmp/eps/me-2"
cp "$ep2/work.json" "$tmp/eps/me-2/work.json"
: >"$tmp/eps/me-2/ledger.ndjson"
MIX_ENV=test sh "$env_sh" -- mix xaas.machine_experience --name me-2 --ggen-igniter-dir "$ggen" \
  --out-root "$tmp/eps" --experience "$tmp/no-me.ttl" --no-pin >"$tmp/run.log" 2>&1
code=$?
[ "$code" = "4" ] || { tail -3 "$tmp/run.log"; refuse "falsifier: the episode runner without the experience exited $code, expected 4 (UNKNOWN, refused to execute)"; }
[ ! -e "$tmp/eps/me-2/drive" ] && [ ! -e "$tmp/eps/me-2/episode.json" ] || refuse "falsifier: the runner executed a drive without an admitted experience"
python3 -c '
import json, sys
u = json.load(open(sys.argv[1]))
assert u["standing"]["value"] == "UNKNOWN" and u["consequence"]["commits"] == [], u["standing"]
' "$tmp/eps/me-2/unknown/unknown.json" || refuse "falsifier: no receipted UNKNOWN"
echo "falsifier (runner): UNKNOWN, no drive, unknown/unknown.json receipted"

echo "ALIVE: GC23-9 episode 1 UNKNOWN -> bounded exploration -> admitted MachineExperience; episode 2 KNOWN from $me_iri with 0 LLM-provider and 0 exploration events and fewer events/steps"
exit 0
