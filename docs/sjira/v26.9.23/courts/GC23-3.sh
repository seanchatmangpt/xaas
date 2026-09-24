#!/bin/sh
# GC23-3 court: Finite Work Graph (PRD section 12; goal.ttl v23:GC23-3).
# "Every required WorkOrder carries the full semantic tuple." Machinery: FRI-T1
# (pack shapes sj:WorkOrderShape + sj:FridayWorkOrderShape +
# sj:GoalCheckpointShape), V23-C (ggen_igniter `mix
# semantic_jira.compile_prose --admit-goal`), V23-P (goal.ttl); court body lane
# V23-K (PR-005, ARD sections 6 and 26 F1).
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses (every tool runs under the F3 no-LLM env, courts/no_llm_env.sh;
# the shapes court is ggen_igniter at GGEN_IGNITER_DIR via courts/gi_mix.sh):
#   1. goal.ttl admits under the pack shapes (context: the predecessor Friday
#      goal, which defines the fri: nodes it references), and the admitted
#      WorkOrder / GoalCheckpoint counts equal an independent rdflib count;
#   2. compiled/orders.ttl (the manufactured delta) admits the same way
#      (context: goal.ttl), with the same count cross-check;
#   3. every WorkOrder of both graphs names its checkpoint (sj:checkpointOf),
#      so sj:FridayWorkOrderShape targets it -- no order escapes the tuple;
#   4. F1 (ARD section 26): for one order of each graph (the first WorkOrder
#      by IRI that carries an sj:exclusion) a control copy admits, and one
#      copy per mandatory tuple field with that field deleted
#      (sj:postcondition, sj:requiresCapability, sj:evidenceHorizon,
#      sj:consequenceClass, sj:successorPolicy, sj:subject,
#      sj:evidenceCeiling, sj:authorityCeiling, sj:repository, sj:baseSha,
#      sj:pathScope) is REFUSED(goal_inadmissible) naming that copy and that
#      field, and nothing else; a copy with every sj:exclusion deleted still
#      admits (sj:exclusion is 0..n by the shared vocabulary contract).
set -u

xaas=${XAAS_DIR:-$(pwd)}
gi=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
GGEN_IGNITER_DIR=$gi
export GGEN_IGNITER_DIR
cd "$xaas" || { echo "UNKNOWN: GC23-3 XAAS_DIR $xaas unreadable"; exit 75; }

v=docs/sjira/v26.9.23
courts="$xaas/$v/courts"
friday="docs/sjira/v26.9.22/friday/goal.ttl"

refuse() { echo "REFUSED: GC23-3 $*"; exit 1; }
unknown() { echo "UNKNOWN: GC23-3 $*"; exit 75; }

for f in "$v/goal.ttl" "$v/compiled/orders.ttl" "$friday"; do
  git -C "$xaas" ls-files --error-unmatch "$f" >/dev/null 2>&1 || refuse "$f is not committed in $xaas"
done

if ! grep -q 'admit_goal' "$gi/lib/mix/tasks/semantic_jira.compile_prose.ex" 2>/dev/null; then
  unknown "shapes court machinery (lane V23-C) absent: no mix semantic_jira.compile_prose --admit-goal in $gi"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-3.XXXXXX") || unknown "cannot create a temp dir"
trap 'rm -rf "$tmp"' EXIT INT TERM

pyuser=$(python3 -m site --user-base 2>/dev/null) || pyuser=""
py() { sh "$courts/no_llm_env.sh" PYTHONUSERBASE="$pyuser" -- python3 "$@"; }

# admit GRAPH CONTEXT... > LOG  (absolute paths; context graphs only resolve references)
admit() {
  admit_graph=$1
  shift
  set -- $(for c in "$@"; do printf ' --context %s' "$c"; done)
  sh "$courts/gi_mix.sh" semantic_jira.compile_prose --admit-goal --goal "$admit_graph" "$@"
}

# 1 + 2. both graphs admit; counts cross-checked; 3. every order names its checkpoint
for pair in "goal:$v/goal.ttl:$friday" "orders:$v/compiled/orders.ttl:$v/goal.ttl"; do
  name=${pair%%:*}
  rest=${pair#*:}
  graph=${rest%%:*}
  context=${rest#*:}
  admit "$xaas/$graph" "$xaas/$context" >"$tmp/$name.log" 2>&1
  code=$?
  if [ "$code" = "75" ]; then tail -1 "$tmp/$name.log"; unknown "no-LLM env or ggen_igniter checkout unusable"; fi
  [ "$code" = "0" ] || { grep -E '^REFUSED' "$tmp/$name.log" | head -20; refuse "$graph is not admitted under the pack shapes (exit $code)"; }
  py - "$xaas/$graph" "$tmp/$name.log" <<'PY' || refuse "$graph: admitted counts or checkpoint links do not hold"
import re, sys
from rdflib import Graph, URIRef
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
g = Graph().parse(sys.argv[1], format="turtle")
log = open(sys.argv[2], encoding="utf-8").read()
m = re.search(r"^GOAL ADMITTED: \S+ (sha256:[0-9a-f]{64}) \((\d+) triples, (\d+) GoalCheckpoints, (\d+) WorkOrders\)$", log, re.M)
assert m, "no GOAL ADMITTED line"
digest, triples, checkpoints, orders = m.group(1), *map(int, m.groups()[1:])
work_orders = set(g.subjects(RDF.type, URIRef(SJ + "WorkOrder")))
goal_checkpoints = set(g.subjects(RDF.type, URIRef(SJ + "GoalCheckpoint")))
assert (triples, checkpoints, orders) == (len(g), len(goal_checkpoints), len(work_orders)), \
    ((triples, checkpoints, orders), (len(g), len(goal_checkpoints), len(work_orders)))
unlinked = sorted(str(o) for o in work_orders if g.value(o, URIRef(SJ + "checkpointOf")) is None)
assert not unlinked, f"WorkOrders without sj:checkpointOf (outside the tuple shape): {unlinked[:5]}"
print(f"{sys.argv[1].rsplit('/', 1)[1]}: ADMITTED {digest} ({orders} WorkOrders, {checkpoints} GoalCheckpoints, "
      f"{triples} triples = rdflib), every WorkOrder sj:checkpointOf-linked")
PY
done

# 4. F1: one order of each graph; field deletions refused, exclusion deletion admitted
fields="postcondition requiresCapability evidenceHorizon consequenceClass successorPolicy subject evidenceCeiling authorityCeiling repository baseSha pathScope"
# (the goal.ttl order's references resolve in goal.ttl + the Friday goal; the
# compiled order's court/action/acceptance/falsifier/capability nodes are
# copied with it, its gate resolves in goal.ttl)
for pair in "goal:$v/goal.ttl:$v/goal.ttl $xaas/$friday" "orders:$v/compiled/orders.ttl:$v/goal.ttl"; do
  name=${pair%%:*}
  rest=${pair#*:}
  graph=${rest%%:*}
  context=${rest#*:}
  py - "$xaas/$graph" "$tmp/f1-$name.nt" "$tmp/f1-$name.order" $fields <<'PY' || refuse "F1: cannot build the $name mutation graph"
import sys
from rdflib import Graph, Literal, URIRef
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
DCTERMS = "http://purl.org/dc/terms/"
source, out, order_file, fields = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
g = Graph().parse(source, format="turtle")
# the first WorkOrder by IRI that carries at least one sj:exclusion, so the
# 0..n exclusion check deletes something
with_exclusion = [o for o in sorted(g.subjects(RDF.type, URIRef(SJ + "WorkOrder")), key=str)
                  if g.value(o, URIRef(SJ + "exclusion")) is not None]
assert with_exclusion, f"{source}: no WorkOrder carries an sj:exclusion"
order = with_exclusion[0]
body = list(g.predicate_objects(order))
present = {str(p) for p, _ in body}
missing = [f for f in fields if SJ + f not in present]
assert not missing, f"{order} lacks {missing} before mutation"
m = Graph()
# the control copy is the order itself, with every non-checkpoint node it
# references (checkpoints belong to the goal graph, passed as context)
for p, o in body:
    m.add((order, p, o))
    if (o, RDF.type, URIRef(SJ + "GoalCheckpoint")) not in g:
        for t in g.triples((o, None, None)):
            m.add(t)
# each copy keeps the order's tuple but gets its own dcterms:identifier and
# sj:replayIdentity (both must be unique across WorkOrders)
identifier, replay = URIRef(DCTERMS + "identifier"), URIRef(SJ + "replayIdentity")
copies = [(f, SJ + f) for f in fields] + [("exclusion", SJ + "exclusion")]
for label, dropped in copies:
    copy = URIRef(f"{order}-F1-{label}")
    for p, o in body:
        if str(p) == dropped:
            continue
        if p in (identifier, replay):
            o = Literal(f"{o}-F1-{label.upper()}")
        m.add((copy, p, o))
m.serialize(out, format="nt", encoding="utf-8")
open(order_file, "w", encoding="utf-8").write(str(order) + "\n")
PY
  order=$(cat "$tmp/f1-$name.order")
  # shellcheck disable=SC2086
  admit "$tmp/f1-$name.nt" "$xaas/"$context >"$tmp/f1-$name.log" 2>&1
  code=$?
  if [ "$code" = "75" ]; then tail -1 "$tmp/f1-$name.log"; unknown "no-LLM env unusable for F1"; fi
  [ "$code" = "1" ] || { tail -3 "$tmp/f1-$name.log"; refuse "F1: the $name mutation graph exited $code, expected 1 (refused)"; }
  py - "$tmp/f1-$name.log" "$order" $fields <<'PY' || refuse "F1: a deleted tuple field of $order was not refused, or a lawful copy was"
import re, sys
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
log, order, fields = sys.argv[1], sys.argv[2], sys.argv[3:]
lines = [l for l in open(log, encoding="utf-8").read().splitlines() if l.startswith("REFUSED(")]
by_subject = {}
for line in lines:
    m = re.match(r"^REFUSED\((\w+)\) (\S+): (.*)$", line)
    if m and m.group(1) == "goal_inadmissible":
        by_subject.setdefault(m.group(2), []).append(m.group(3))
for field in fields:
    copy = f"{order}-F1-{field}"
    details = by_subject.get(copy, [])
    assert any(SJ + field in d for d in details), f"{copy}: no refusal naming sj:{field}: {details}"
    extra = [d for d in details if SJ + field not in d]
    assert not extra, f"{copy}: refused for more than the deleted field: {extra}"
for lawful in (order, f"{order}-F1-exclusion"):
    assert lawful not in by_subject, f"{lawful} refused: {by_subject[lawful]}"
unexpected = sorted(set(by_subject) - {f"{order}-F1-{f}" for f in fields})
assert not unexpected, f"refusals for unexpected subjects: {unexpected}"
print(f"F1 {order.split('#')[-1]}: {len(fields)}/{len(fields)} field deletions REFUSED(goal_inadmissible) naming the field; "
      f"control and no-exclusion copies admitted")
PY
done

echo "ALIVE: GC23-3 every WorkOrder of goal.ttl and compiled/orders.ttl carries the full tuple under the pack shapes; F1 refused"
exit 0
