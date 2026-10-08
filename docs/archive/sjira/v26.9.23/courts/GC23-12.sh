#!/bin/sh
# GC23-12 court: Semantic Self-Hosting (PRD section 12; ARD section 24 M9;
# goal.ttl v23:GC23-12). Machinery: lane V23-H.
# "A new bounded improvement to this architecture can itself originate as
# accepted prose and enter the same pipeline without manually manufacturing a
# bespoke backlog."
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit contract (V23-P, stop court):
#   0  ALIVE: every witness holds AND the operator accepted the successor prose;
#   77 BLOCKED(operator_acceptance): every witness holds and the one open item
#      is the operator-acceptance edge (typed last line, broken_term
#      R_missing_authority; the stop court's blocked_exit);
#   75 UNKNOWN: the court cannot witness (no-LLM env, ggen_igniter checkout or
#      graph-side build unusable);
#   1  REFUSED: a witness failed.
#
# The successor is docs/sjira/v26.9.23/successor/ (lane V23-H): the DRAFT
# working-backwards press release v26.9.24-wbpr.md (ggen projection-drift
# repair), the recorded LLM extraction candidates.extract.json (the only LLM
# edge, sj:extractedBy llm:claude-opus-5-5@wave-B1c/V23-H), candidates.ttl
# (prose_spans.py emit), goal.ttl (root v23:GC-26.9.24 + gates GC24-*, no
# WorkOrder), compiled/{propositions,orders}.ttl (compile_prose output) and
# intake/{work,frontier,descriptor,resolution}.json (mix xaas.successor).
#
# Witnesses (every tool runs under the F3 no-LLM env, courts/no_llm_env.sh;
# the compiler is ggen_igniter at GGEN_IGNITER_DIR via courts/gi_mix.sh):
#   0. the successor artifacts and their machinery are committed and
#      unmodified at HEAD;
#   1. the candidates re-verify against the prose bytes and re-emit
#      byte-equal from the recorded extraction (prose_spans.py check
#      --extract), every successor gate GC24-* covered;
#   2. the committed compiled/*.ttl recompute byte-identically from prose +
#      candidates + successor goal (compile_prose --check): the orders exist
#      only as compiler output;
#   3. the successor law (courts/successor_law.py, rdflib): no WorkOrder in
#      the successor goal, every order IRI recomputes from its proposition
#      IRI, full tuple, placement under GC-26.9.24 only, predecessor
#      inventory listed; plus two anti-vacuity mutations the law must refuse
#      (a smuggled WorkOrder in the goal graph, a forged order in orders.ttl);
#   4. the intake recomputes byte-identically (mix xaas.successor --check):
#      frontier -> first eligible order -> mix semantic_jira.descriptor
#      --provider recipe -> Xaas.Sa2a.Route.resolve, the unregistered
#      capability typed UNSUPPORTED(provider_capability), not an error;
#   5. F3: the intake with ANTHROPIC_API_KEY set is
#      REFUSED(llm_credential_present), broken_term mu_on_O;
#   6. the acceptance probe fires both ways on a scratch git repo (committed
#      ACCEPTED naming the digest -> accepted; a stale digest -> BLOCKED),
#      then courts/successor_acceptance.sh judges this checkout: the only
#      open item until the operator commits docs/sjira/v26.9.23/successor/ACCEPTED.
set -u

xaas=${XAAS_DIR:-$(pwd)}
gi=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
GGEN_IGNITER_DIR=$gi
export GGEN_IGNITER_DIR
cd "$xaas" || { echo "UNKNOWN: GC23-12 XAAS_DIR $xaas unreadable"; exit 75; }

v=docs/sjira/v26.9.23
s=$v/successor
courts="$xaas/$v/courts"
BLOCKED_EXIT=77

refuse() { echo "REFUSED: GC23-12 $*"; exit 1; }
unknown() { echo "UNKNOWN: GC23-12 $*"; exit 75; }

# 0. committed, unmodified inputs and machinery
for f in "$s/v26.9.24-wbpr.md" "$s/candidates.extract.json" "$s/candidates.ttl" "$s/goal.ttl" \
  "$s/compiled/propositions.ttl" "$s/compiled/orders.ttl" "$s/intake/work.json" "$s/intake/frontier.json" \
  "$s/intake/descriptor.json" "$s/intake/resolution.json" scripts/successor_work_graph.exs \
  scripts/sjira/prose_spans.py lib/xaas/sjira/successor.ex lib/mix/tasks/xaas.successor.ex \
  "$v/courts/successor_law.py" "$v/courts/successor_acceptance.sh"; do
  git -C "$xaas" ls-files --error-unmatch "$f" >/dev/null 2>&1 || refuse "$f is not committed in $xaas"
done
git -C "$xaas" diff --quiet HEAD -- "$s" scripts/successor_work_graph.exs lib/xaas/sjira/successor.ex \
  lib/mix/tasks/xaas.successor.ex "$v/courts/successor_law.py" "$v/courts/successor_acceptance.sh" ||
  refuse "tracked successor artifacts or machinery differ from HEAD in $xaas"

if [ ! -f "$gi/lib/mix/tasks/semantic_jira.compile_prose.ex" ]; then
  unknown "compiler machinery (lane V23-C) absent: no mix semantic_jira.compile_prose in $gi"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-12.XXXXXX") || unknown "cannot create a temp dir"
trap 'rm -rf "$tmp"' EXIT INT TERM

pyuser=$(python3 -m site --user-base 2>/dev/null) || pyuser=""
py() { sh "$courts/no_llm_env.sh" PYTHONUSERBASE="$pyuser" -- python3 "$@"; }

gates=$(py - "$xaas/$s/goal.ttl" <<'PY'
import sys
from rdflib import Graph, URIRef
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
g = Graph().parse(sys.argv[1], format="turtle")
root = URIRef("https://ggen-igniter.dev/sjira/v26.9.23#GC-26.9.24")
print(len({x for x in g.subjects(URIRef(SJ + "checkpointOf"), root) if (x, RDF.type, URIRef(SJ + "GoalCheckpoint")) in g}))
PY
) || unknown "cannot read the successor goal graph (python3 + rdflib under the no-LLM env)"

# 1. candidates bound to the prose bytes; re-emitted byte-equal from the recorded extraction
py scripts/sjira/prose_spans.py check --source "$s/v26.9.24-wbpr.md" --candidates "$s/candidates.ttl" \
  --require-gates "$gates" --gate-prefix GC24- --extract "$s/candidates.extract.json" >"$tmp/spans.log" 2>&1 ||
  { tail -5 "$tmp/spans.log"; refuse "prose_spans.py check refused the successor candidates"; }
echo "candidates: $(grep -E '^CHECK OK' "$tmp/spans.log")"

# 2. the committed projection is compiler output (byte-identical recompute)
sh "$courts/gi_mix.sh" semantic_jira.compile_prose --source "$xaas/$s/v26.9.24-wbpr.md" \
  --candidates "$xaas/$s/candidates.ttl" --goal "$xaas/$s/goal.ttl" --out-dir "$xaas/$s/compiled" --check \
  >"$tmp/compile.log" 2>&1
code=$?
[ "$code" = "75" ] && { tail -1 "$tmp/compile.log"; unknown "no-LLM env or ggen_igniter checkout unusable for compile_prose"; }
[ "$code" = "0" ] || { grep -E '^REFUSED' "$tmp/compile.log" | head -20; tail -3 "$tmp/compile.log"; refuse "compile_prose --check exited $code"; }
grep -q '^CHECK: ' "$tmp/compile.log" || refuse "compile_prose --check printed no CHECK line"
echo "compile: $(grep -E '^DELTA: ' "$tmp/compile.log"); $(grep -E '^CHECK: ' "$tmp/compile.log" | sed "s#$xaas/##")"

# 3. the successor law + two mutations it must refuse
py "$courts/successor_law.py" --xaas "$xaas" >"$tmp/law.log" 2>&1 || { tail -3 "$tmp/law.log"; refuse "successor law broken"; }
cat "$tmp/law.log"

py - "$xaas/$s/goal.ttl" "$xaas/$s/compiled/orders.ttl" "$tmp/goal-smuggled.ttl" "$tmp/orders-forged.ttl" <<'PY' ||
import sys
from rdflib import Graph, Literal, URIRef
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"
goal = Graph().parse(sys.argv[1], format="turtle")
smuggled = URIRef(V23 + "WO-HAND-AUTHORED")
goal.add((smuggled, RDF.type, URIRef(SJ + "WorkOrder")))
goal.add((smuggled, URIRef(SJ + "checkpointOf"), URIRef(V23 + "GC24-2")))
goal.serialize(sys.argv[3], format="turtle")
orders = Graph().parse(sys.argv[2], format="turtle")
victim = sorted(orders.subjects(RDF.type, URIRef(SJ + "WorkOrder")), key=str)[0]
forged = URIRef(V23 + "WO-0000000000000000")
for p, o in list(orders.predicate_objects(victim)):
    orders.add((forged, p, o))
orders.serialize(sys.argv[4], format="turtle")
PY
  refuse "cannot build the law mutations"

py "$courts/successor_law.py" --xaas "$xaas" --successor-goal "$tmp/goal-smuggled.ttl" >"$tmp/mut1.log" 2>&1 &&
  refuse "mutation: the law admitted a hand-authored WorkOrder in the successor goal graph"
grep -q '^REFUSED: GC23-12 L1 hand-authored WorkOrder in the successor goal graph' "$tmp/mut1.log" ||
  { cat "$tmp/mut1.log"; refuse "mutation: no L1 refusal for the smuggled WorkOrder"; }
py "$courts/successor_law.py" --xaas "$xaas" --orders "$tmp/orders-forged.ttl" >"$tmp/mut2.log" 2>&1 &&
  refuse "mutation: the law admitted a forged order that recomputes from no proposition"
grep -q '^REFUSED: GC23-12 L5 .*WO-0000000000000000 does not recompute from its subject' "$tmp/mut2.log" ||
  { cat "$tmp/mut2.log"; refuse "mutation: no L5 refusal for the forged order"; }
echo "mutations: smuggled goal WorkOrder refused (L1); forged order WO-0000000000000000 refused (L5)"

# 4. the intake recomputes byte-identically: frontier -> descriptor --provider recipe -> Route.resolve
MIX_ENV=test sh "$courts/no_llm_env.sh" TMPDIR="$tmp/" -- mix xaas.successor --dir "$s" \
  --ggen-igniter-dir "$gi" --check >"$tmp/intake.log" 2>&1
code=$?
[ "$code" = "75" ] && { tail -1 "$tmp/intake.log"; unknown "the graph side in $gi has no usable build (BUILD_BROKEN)"; }
[ "$code" = "0" ] || { tail -3 "$tmp/intake.log"; refuse "mix xaas.successor --check exited $code"; }
py - "$tmp/intake.log" <<'PY' || refuse "the intake summary is not a typed successor item"
import json, sys
line = [l for l in open(sys.argv[1], encoding="utf-8").read().splitlines() if l.startswith("{")][-1]
s = json.loads(line)
assert s["check"] == "outputs recompute byte-identically", s
assert s["standing"] in ("UNSUPPORTED(provider_capability)", "UNKNOWN"), s
assert s["eligible"] >= 1 and s["work_orders"] >= s["eligible"], s
print(f"intake: {s['work_orders']} orders, {s['eligible']} eligible; first {s['first']} ({s['capability']}) -> "
      f"{s['standing']} ({s['reason']}); outputs recompute byte-identically")
PY

# 5. F3: an exposed model credential is refused before anything runs
MIX_ENV=test sh "$courts/no_llm_env.sh" ANTHROPIC_API_KEY=x -- mix xaas.successor --dir "$s" \
  --ggen-igniter-dir "$gi" --check >"$tmp/f3.log" 2>&1
code=$?
[ "$code" = "3" ] || { tail -3 "$tmp/f3.log"; refuse "F3: intake with ANTHROPIC_API_KEY exited $code, expected 3"; }
tail -1 "$tmp/f3.log" | grep -q '"broken_term":"mu_on_O".*"standing":"REFUSED(llm_credential_present)"' ||
  { tail -1 "$tmp/f3.log"; refuse "F3: no REFUSED(llm_credential_present) with broken_term mu_on_O"; }
echo "F3: intake with ANTHROPIC_API_KEY=x refused REFUSED(llm_credential_present), broken_term mu_on_O"

# 6. the acceptance probe fires both ways on a scratch repository, then judges this checkout
probe="$tmp/probe"
mkdir -p "$probe/$s" && cp "$xaas/$s/v26.9.24-wbpr.md" "$probe/$s/" || refuse "cannot build the acceptance probe"
sha=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$probe/$s/v26.9.24-wbpr.md")
pgit() {
  git -C "$probe" -c user.email=gc23-12@court.invalid -c user.name=gc23-12-court -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null "$@" >/dev/null 2>&1
}
pgit init -q && pgit add -A && pgit commit -q -m prose || refuse "cannot commit the acceptance probe"
echo "sha256:0000000000000000000000000000000000000000000000000000000000000000" >"$probe/$s/ACCEPTED"
pgit add -A && pgit commit -q -m stale || refuse "cannot commit the stale acceptance probe"
sh "$courts/successor_acceptance.sh" "$probe" >"$tmp/probe-stale.log" 2>&1
[ "$?" = "$BLOCKED_EXIT" ] && grep -q '^BLOCKED(operator_acceptance): .*(stale acceptance) (broken_term R_missing_authority)$' "$tmp/probe-stale.log" ||
  { cat "$tmp/probe-stale.log"; refuse "acceptance probe: a stale ACCEPTED was not BLOCKED"; }
echo "sha256:$sha" >"$probe/$s/ACCEPTED"
pgit add -A && pgit commit -q -m accept || refuse "cannot commit the acceptance probe"
sh "$courts/successor_acceptance.sh" "$probe" >"$tmp/probe-ok.log" 2>&1 ||
  { cat "$tmp/probe-ok.log"; refuse "acceptance probe: a committed ACCEPTED naming the digest was not accepted"; }
echo "acceptance probe: stale digest -> BLOCKED; committed digest -> ACCEPTED"

sh "$courts/successor_acceptance.sh" "$xaas" >"$tmp/accept.log" 2>&1
code=$?
case "$code" in
  0)
    tail -1 "$tmp/accept.log"
    echo "ALIVE: GC23-12 accepted successor prose sha256:$sha enters the same pipeline: compiled orders only, full tuple, non-empty frontier, typed successor items"
    exit 0
    ;;
  "$BLOCKED_EXIT")
    echo "GC23-12 witnesses 0-6 hold; the only open item is the operator-acceptance edge of the successor prose"
    tail -1 "$tmp/accept.log"
    exit "$BLOCKED_EXIT"
    ;;
  *)
    tail -3 "$tmp/accept.log"
    refuse "the acceptance edge could not be judged (exit $code)"
    ;;
esac
