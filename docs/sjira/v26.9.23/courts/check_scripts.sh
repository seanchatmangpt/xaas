#!/bin/sh
# Court-script contract check for GC-26.9.23 (lane V23-P).
#
# Exit 0 iff:
#   1. docs/sjira/v26.9.23/courts/GC23-0.sh .. GC23-12.sh all exist and are
#      `sh -n` clean, and no other GC23-*.sh script sits beside them;
#   2. goal.ttl declares exactly 13 gates v23:GC23-0 .. v23:GC23-12, and each
#      gate's sj:courtCommand is exactly
#      "sh docs/sjira/v26.9.23/courts/GC23-<n>.sh" (its own script);
#   3. when python3 with rdflib is available, an independent RDF parse of
#      goal.ttl agrees: the gates with sj:checkpointOf v23:GC-26.9.23 are
#      exactly GC23-0 .. GC23-12 and each names its own script.
# Runs from any cwd; paths resolve from this script's location.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
goal="$here/../goal.ttl"
fail=0

refuse() {
  echo "REFUSED: $*"
  fail=1
}

[ -f "$goal" ] || { echo "REFUSED: missing $goal"; exit 1; }

n=0
while [ "$n" -le 12 ]; do
  rel="docs/sjira/v26.9.23/courts/GC23-$n.sh"
  if [ ! -f "$root/$rel" ]; then
    refuse "missing court script $rel"
  elif ! sh -n "$root/$rel" 2>/dev/null; then
    refuse "court script $rel is not sh -n clean"
  fi
  n=$((n + 1))
done

for script in "$here"/GC23-*.sh; do
  [ -e "$script" ] || continue
  id=$(basename "$script" .sh)
  case "$id" in
    GC23-0 | GC23-1 | GC23-2 | GC23-3 | GC23-4 | GC23-5 | GC23-6 | GC23-7 | GC23-8 | GC23-9 | GC23-10 | GC23-11 | GC23-12) ;;
    *) refuse "court script $id.sh names no gate of goal.ttl" ;;
  esac
done

# Gate -> court command pairs from goal.ttl (one Turtle subject block per gate).
pairs=$(awk '
  /^v23:GC23-[0-9]+ a sj:GoalCheckpoint/ { cur = $1; sub(/^v23:/, "", cur); next }
  /^[^ \t#]/ { cur = "" }
  cur != "" && /^[ \t]*sj:courtCommand / {
    line = $0
    sub(/^[ \t]*sj:courtCommand "/, "", line)
    sub(/"[ \t]*[;.][ \t]*$/, "", line)
    print cur "\t" line
  }
' "$goal")

gates=$(printf '%s\n' "$pairs" | awk -F '\t' 'NF == 2 { print $1 }' | sort -u | wc -l | tr -d ' ')
[ "$gates" = "13" ] || refuse "goal.ttl declares $gates gates with a court command (expected 13)"

n=0
while [ "$n" -le 12 ]; do
  want="sh docs/sjira/v26.9.23/courts/GC23-$n.sh"
  got=$(printf '%s\n' "$pairs" | awk -F '\t' -v g="GC23-$n" '$1 == g { print $2 }')
  count=$(printf '%s\n' "$pairs" | awk -F '\t' -v g="GC23-$n" '$1 == g' | wc -l | tr -d ' ')
  if [ "$count" != "1" ]; then
    refuse "gate GC23-$n has $count court commands in goal.ttl (expected 1)"
  elif [ "$got" != "$want" ]; then
    refuse "gate GC23-$n court command is '$got', expected '$want'"
  fi
  n=$((n + 1))
done

if command -v python3 >/dev/null 2>&1 && python3 -c 'import rdflib' >/dev/null 2>&1; then
  python3 - "$goal" <<'PY' || fail=1
import sys
import rdflib

SJ = rdflib.Namespace("https://ggen-igniter.dev/ontology/semantic-jira#")
DCT = rdflib.Namespace("http://purl.org/dc/terms/")
root = rdflib.URIRef("https://ggen-igniter.dev/sjira/v26.9.23#GC-26.9.23")
g = rdflib.Graph()
g.parse(sys.argv[1], format="turtle")
got = {}
for gate in g.subjects(SJ.checkpointOf, root):
    if (gate, rdflib.RDF.type, SJ.GoalCheckpoint) not in g:
        continue
    ident = str(g.value(gate, DCT.identifier))
    got[ident] = sorted(str(c) for c in g.objects(gate, SJ.courtCommand))
want = {f"GC23-{n}": [f"sh docs/sjira/v26.9.23/courts/GC23-{n}.sh"] for n in range(13)}
if got != want:
    for gid in sorted(set(got) | set(want)):
        if got.get(gid) != want.get(gid):
            print(f"REFUSED: rdflib parse: gate {gid} court commands {got.get(gid)} != {want.get(gid)}")
    sys.exit(1)
print("rdflib parse: 13 gates of v23:GC-26.9.23, each naming its own court script")
PY
else
  echo "SKIP: independent rdflib parse (python3 with rdflib not available)"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "OK: 13 court scripts GC23-0..GC23-12 exist, are sh -n clean, and goal.ttl points each gate at its own script"
