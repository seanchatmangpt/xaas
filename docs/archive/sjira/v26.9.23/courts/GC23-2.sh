#!/bin/sh
# GC23-2 court: First-Mile Compiler (PRD section 12; goal.ttl v23:GC23-2).
# "Accepted prose compiles into a finite sJira delta." Machinery: V23-C
# (ggen_igniter `mix semantic_jira.compile_prose`, PR-002..PR-005, ARD
# sections 5.5 and 17), V23-X (prose_spans.py); court body lane V23-K.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses (every tool runs under the F3 no-LLM env, courts/no_llm_env.sh;
# the compiler is ggen_igniter at GGEN_IGNITER_DIR via courts/gi_mix.sh):
#   1. determinism (ARD 5.5): two fresh compile_prose processes over the
#      committed prose + candidates + goal.ttl write into two temp dirs; their
#      propositions.ttl/orders.ttl are byte-identical to each other and to the
#      committed compiled/*.ttl;
#   2. admission refuses a candidate mutation: one candidate's sj:sourceEnd
#      shifted by one byte is REFUSED(provenance_mismatch) naming it, a
#      smuggled sj:WorkOrder subject is REFUSED(foreign_subject), and nothing
#      is written;
#   3. finiteness and placement law over the committed projection (rdflib,
#      independent of the compiler): every WorkOrder's sj:subject is an
#      admitted required Postcondition/Invariant/Falsifier proposition, its
#      sj:checkpointOf is exactly that proposition's sj:requiredBy (the root
#      GC-26.9.23 or one of its 13 gates), every such proposition has exactly
#      one order, and no not-required proposition yields an order;
#   4. F8 (ARD section 26, PRD PR-017): discovered work is routed to the
#      successor, never under a GC23 gate. Fixture: courts/fixtures/f8/ --
#      discovered.md (improvement prose that is not the accepted revision and
#      falsifies no admitted proposition), extract-attack.json (its one
#      Postcondition claiming sj:requiredBy GC23-8) and extract-routed.json
#      (the same claim for the successor fixture gate GC24-F8), emitted by
#      prose_spans.py.
#      4a. attack: compiling it against goal.ttl is REFUSED(provenance_mismatch)
#          on the root v23:GC-26.9.23 (its sj:sourceSha256 pins the accepted
#          prose) and nothing is written: no order lands under a GC23 gate;
#      4b. route: compiling it against successor-goal.ttl (root
#          v23:GC-26.9.24, sj:successorOf v23:GC-26.9.23) admits it and
#          manufactures one WorkOrder that is sj:checkpointOf+ v23:GC-26.9.24
#          and not sj:checkpointOf+ v23:GC-26.9.23 in goal.ttl + the fixture
#          + the committed orders; the set of orders under GC-26.9.23 is
#          unchanged, and goal.ttl names v23:GC-26.9.24 as the root's
#          sj:successorCheckpoint.
#      Rule locations: ggen_igniter GgenIgniter.SemanticJira.Prose
#      root_refusals/2 (a root sj:sourceSha256 admits only its own prose),
#      priv/ggen/semantic-jira-pack/prose/foreign_requirements.rq (sj:requiredBy
#      only the root or its gates) and prose/delta.construct.rq (sj:checkpointOf
#      = sj:requiredBy); xaas goal.ttl root sj:successorCheckpoint /
#      sj:successorPolicy and stop.rq clause (3) (only sj:checkpointOf+ orders
#      of GC-26.9.23 hold STOP open).
set -u

xaas=${XAAS_DIR:-$(pwd)}
gi=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
GGEN_IGNITER_DIR=$gi
export GGEN_IGNITER_DIR
cd "$xaas" || { echo "UNKNOWN: GC23-2 XAAS_DIR $xaas unreadable"; exit 75; }

v=docs/sjira/v26.9.23
courts="$xaas/$v/courts"
f8="$v/courts/fixtures/f8"

refuse() { echo "REFUSED: GC23-2 $*"; exit 1; }
unknown() { echo "UNKNOWN: GC23-2 $*"; exit 75; }

for f in "$v/prd-ard.md" "$v/candidates/prd-ard.ttl" "$v/goal.ttl" "$v/compiled/propositions.ttl" \
  "$v/compiled/orders.ttl" "$f8/discovered.md" "$f8/extract-attack.json" "$f8/extract-routed.json" \
  "$f8/successor-goal.ttl"; do
  git -C "$xaas" ls-files --error-unmatch "$f" >/dev/null 2>&1 || refuse "$f is not committed in $xaas"
done

if [ ! -f "$gi/lib/mix/tasks/semantic_jira.compile_prose.ex" ]; then
  unknown "compiler machinery (lane V23-C) absent: no mix semantic_jira.compile_prose in $gi"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-2.XXXXXX") || unknown "cannot create a temp dir"
trap 'rm -rf "$tmp"' EXIT INT TERM

pyuser=$(python3 -m site --user-base 2>/dev/null) || pyuser=""
py() { sh "$courts/no_llm_env.sh" PYTHONUSERBASE="$pyuser" -- python3 "$@"; }

# compile OUT-DIR SOURCE CANDIDATES GOAL > LOG  (absolute paths; mix cwd is the ggen_igniter root)
compile() {
  sh "$courts/gi_mix.sh" semantic_jira.compile_prose --source "$xaas/$2" --candidates "$3" \
    --goal "$xaas/$4" --out-dir "$1"
}

# the exit of a compile that must succeed: 75 -> UNKNOWN, else refuse
must_admit() {
  if [ "$1" = "75" ]; then tail -1 "$2"; unknown "no-LLM env or ggen_igniter checkout unusable"; fi
  [ "$1" = "0" ] || { grep -E '^REFUSED' "$2" | head -20; tail -3 "$2"; refuse "$3 exited $1"; }
}

# 1. two fresh compiles, byte-identical to each other and to the committed projection
compile "$tmp/run1" "$v/prd-ard.md" "$xaas/$v/candidates/prd-ard.ttl" "$v/goal.ttl" >"$tmp/run1.log" 2>&1 &
pid1=$!
compile "$tmp/run2" "$v/prd-ard.md" "$xaas/$v/candidates/prd-ard.ttl" "$v/goal.ttl" >"$tmp/run2.log" 2>&1 &
pid2=$!
wait "$pid1"
code1=$?
wait "$pid2"
code2=$?
must_admit "$code1" "$tmp/run1.log" "fresh compile 1"
must_admit "$code2" "$tmp/run2.log" "fresh compile 2"
for f in propositions.ttl orders.ttl; do
  cmp -s "$tmp/run1/$f" "$tmp/run2/$f" || refuse "determinism: the two fresh compiles differ in $f"
  cmp -s "$tmp/run1/$f" "$xaas/$v/compiled/$f" || refuse "determinism: fresh $f differs from the committed $v/compiled/$f"
done
echo "determinism: 2 fresh compiles byte-identical to $v/compiled/*.ttl ($(grep -E '^orders.ttl ' "$tmp/run1.log"))"

# 2. a candidate mutation is refused and nothing is written
py - "$xaas/$v/candidates/prd-ard.ttl" "$tmp/mutated.nt" <<'PY' >"$tmp/mutation.txt" || refuse "cannot build the candidate mutation"
import sys
from rdflib import Graph, Literal, URIRef
from rdflib.namespace import RDF, XSD
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
g = Graph().parse(sys.argv[1], format="turtle")
props = sorted(g.subjects(RDF.type, URIRef(SJ + "Proposition")), key=str)
target = props[0]
end = g.value(target, URIRef(SJ + "sourceEnd"))
g.set((target, URIRef(SJ + "sourceEnd"), Literal(int(end) + 1, datatype=XSD.integer)))
smuggled = URIRef("https://ggen-igniter.dev/sjira/v26.9.23#WO-SMUGGLED")
g.add((smuggled, RDF.type, URIRef(SJ + "WorkOrder")))
g.serialize(sys.argv[2], format="nt", encoding="utf-8")
print(target, smuggled)
PY
read -r mutated smuggled <"$tmp/mutation.txt"
compile "$tmp/mut" "$v/prd-ard.md" "$tmp/mutated.nt" "$v/goal.ttl" >"$tmp/mut.log" 2>&1
code=$?
[ "$code" = "75" ] && { tail -1 "$tmp/mut.log"; unknown "no-LLM env unusable for the mutation run"; }
[ "$code" = "1" ] || { tail -3 "$tmp/mut.log"; refuse "mutation: compile of the mutated candidates exited $code, expected 1"; }
grep -q "^REFUSED(provenance_mismatch) $mutated: " "$tmp/mut.log" ||
  refuse "mutation: no REFUSED(provenance_mismatch) for the shifted span of $mutated"
grep -q "^REFUSED(foreign_subject) $smuggled: " "$tmp/mut.log" ||
  refuse "mutation: no REFUSED(foreign_subject) for the smuggled $smuggled"
[ ! -e "$tmp/mut" ] || refuse "mutation: a refused compile wrote $tmp/mut"
echo "mutation: shifted span of $mutated and smuggled WorkOrder refused; nothing written"

# 3. finiteness and placement law over the committed projection
py - "$xaas/$v/goal.ttl" "$xaas/$v/compiled/propositions.ttl" "$xaas/$v/compiled/orders.ttl" <<'PY' ||
import sys
from collections import Counter
from rdflib import Graph, URIRef, Literal
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"
sj = lambda n: URIRef(SJ + n)
goal = Graph().parse(sys.argv[1], format="turtle")
props = Graph().parse(sys.argv[2], format="turtle")
orders = Graph().parse(sys.argv[3], format="turtle")
root = URIRef(V23 + "GC-26.9.23")
gates = {g for g in goal.subjects(sj("checkpointOf"), root) if (g, RDF.type, sj("GoalCheckpoint")) in goal}
assert len(gates) == 13, len(gates)
allowed = gates | {root}
delta_kinds = {"Postcondition", "Invariant", "Falsifier"}
admitted = set(props.subjects(RDF.type, sj("Proposition")))
required_delta = {p for p in admitted
                  if str(props.value(p, sj("propositionKind"))) in delta_kinds
                  and props.value(p, sj("requiredBy")) is not None}
not_required = {p for p in admitted if props.value(p, sj("requiredBy")) is None}
work_orders = set(orders.subjects(RDF.type, sj("WorkOrder")))
subjects = Counter()
for wo in work_orders:
    subject = URIRef(str(orders.value(wo, sj("subject"))))
    assert subject in admitted, f"{wo}: sj:subject {subject} is not an admitted proposition"
    assert subject in required_delta, f"{wo}: {subject} is not a required Postcondition/Invariant/Falsifier"
    parents = set(orders.objects(wo, sj("checkpointOf")))
    required_by = props.value(subject, sj("requiredBy"))
    assert parents == {required_by}, f"{wo}: sj:checkpointOf {parents} != sj:requiredBy {required_by}"
    assert required_by in allowed, f"{wo}: placed under {required_by}, outside GC-26.9.23 and its gates"
    subjects[subject] += 1
assert set(subjects) == required_delta, sorted(map(str, required_delta - set(subjects)))[:5]
assert all(n == 1 for n in subjects.values()), [s for s, n in subjects.items() if n > 1][:5]
assert not (set(subjects) & not_required)
print(f"placement: {len(work_orders)} WorkOrders = {len(required_delta)} required Postcondition/Invariant/Falsifier "
      f"propositions (1:1, sj:checkpointOf = sj:requiredBy within GC-26.9.23 + 13 gates); "
      f"{len(not_required)} not-required propositions yield 0 orders")
PY
  refuse "the committed projection breaks the finiteness/placement law"

# 4. F8: discovered work routes to the successor, never under a GC23 gate
for x in attack routed; do
  py scripts/sjira/prose_spans.py emit --source "$f8/discovered.md" --extract "$f8/extract-$x.json" \
    --out "$tmp/f8-$x.ttl" --source-path "$f8/discovered.md" --extracted-by "fixture:GC23-2-F8" \
    >"$tmp/f8-$x-emit.log" 2>&1 || { tail -3 "$tmp/f8-$x-emit.log"; refuse "F8: prose_spans.py emit of extract-$x.json failed"; }
done

compile "$tmp/f8a" "$f8/discovered.md" "$tmp/f8-attack.ttl" "$v/goal.ttl" >"$tmp/f8a.log" 2>&1
code=$?
[ "$code" = "75" ] && { tail -1 "$tmp/f8a.log"; unknown "no-LLM env unusable for F8"; }
[ "$code" = "1" ] || { tail -3 "$tmp/f8a.log"; refuse "F8 attack: compile against goal.ttl exited $code, expected 1"; }
grep -q '^REFUSED(provenance_mismatch) https://ggen-igniter.dev/sjira/v26.9.23#GC-26.9.23: root sj:sourceSha256 ' "$tmp/f8a.log" ||
  refuse "F8 attack: no REFUSED(provenance_mismatch) on the root GC-26.9.23"
[ ! -e "$tmp/f8a" ] || refuse "F8 attack: the refused compile wrote output"
echo "F8 attack: discovered prose claiming sj:requiredBy GC23-8 refused against GC-26.9.23 (provenance_mismatch on the root); nothing written"

compile "$tmp/f8b" "$f8/discovered.md" "$tmp/f8-routed.ttl" "$f8/successor-goal.ttl" >"$tmp/f8b.log" 2>&1
must_admit "$?" "$tmp/f8b.log" "F8 route: compile against the successor fixture"
py - "$xaas/$v/goal.ttl" "$xaas/$f8/successor-goal.ttl" "$tmp/f8b/orders.ttl" "$xaas/$v/compiled/orders.ttl" \
  "$tmp/f8b/propositions.ttl" <<'PY' ||
import sys
from rdflib import Graph, URIRef
from rdflib.namespace import RDF
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"
sj = lambda n: URIRef(SJ + n)
goal_path, successor_path, routed_path, committed_path, routed_props_path = sys.argv[1:6]
goal = Graph().parse(goal_path, format="turtle")
root, successor = URIRef(V23 + "GC-26.9.23"), URIRef(V23 + "GC-26.9.24")
assert goal.value(root, sj("successorCheckpoint")) == successor, "goal.ttl root names no successor checkpoint"
assert (successor, sj("boundaryClass"), sj("Successor")) in goal
routed = Graph().parse(routed_path, format="turtle")
new_orders = sorted(routed.subjects(RDF.type, sj("WorkOrder")), key=str)
assert len(new_orders) == 1, new_orders
order = new_orders[0]
proposition = next(Graph().parse(routed_props_path, format="turtle").subjects(RDF.type, sj("Proposition")))
assert str(routed.value(order, sj("subject"))) == str(proposition)
merged = Graph()
for path in (goal_path, successor_path, committed_path):
    merged.parse(path, format="turtle")
under = lambda g, top: {row[0] for row in g.query(
    "PREFIX sj: <%s> SELECT ?o WHERE { ?o a sj:WorkOrder ; sj:checkpointOf+ <%s> . }" % (SJ, top))}
before = under(merged, root)
merged += routed
after = under(merged, root)
assert order in under(merged, successor), f"{order} is not sj:checkpointOf+ GC-26.9.24"
assert order not in after, f"{order} landed under GC-26.9.23"
assert after == before, sorted(map(str, after ^ before))
print(f"F8 route: {order.split('#')[1]} admitted under GC-26.9.24 (checkpointOf {routed.value(order, sj('checkpointOf')).split('#')[1]}), "
      f"not under GC-26.9.23; orders under GC-26.9.23 unchanged ({len(before)})")
PY
  refuse "F8 route: the discovered order is not placed under GC-26.9.24 only"

echo "ALIVE: GC23-2 accepted prose compiles deterministically into a finite sJira delta; candidate mutation refused; F8 routes discovered work to GC-26.9.24"
exit 0
