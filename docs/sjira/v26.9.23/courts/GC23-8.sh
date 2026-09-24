#!/bin/sh
# GC23-8 court: Closed Frontier (PRD section 12, PR-012; ARD section 14;
# goal.ttl v23:GC23-8). Machinery: lane V23-D.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed reference episode fmt-1:
#   1. recorded diff: frontier_before has EP-A eligible and EP-B fenced
#      (blocked on EP-A); frontier_after has EP-A off the frontier with
#      derived standing ALIVE and EP-B eligible; the ledger holds exactly the
#      one EP-A UNKNOWN -> ALIVE transition;
#   2. live recompute: the graph side's own `mix semantic_jira.frontier`
#      (run in GGEN_IGNITER_DIR, private MIX_BUILD_PATH clone, nothing of
#      that checkout's build is written) over the committed work graph
#      reproduces frontier_before from an empty ledger and frontier_after
#      from the committed ledger (eligible, blocked, standings, events,
#      ledger_tail). The graph-side toolchain is the drive's own resolution
#      (`mix xaas.episode --graph-toolchain`: the Elixir that compiled the
#      build under judgement, else the .tool-versions pin), so the court
#      and the drive cannot judge one checkout with two compilers. A graph
#      side that does not compile under it is UNKNOWN (the court cannot
#      witness), never a refusal of the frontier.
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
cd "$xaas" || { echo "UNKNOWN: GC23-8 XAAS_DIR $xaas unreadable"; exit 75; }

for f in work.json ledger.ndjson frontier_before.json frontier_after.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-8 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-8.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-8 $*"; exit 1; }

# 1. recorded diff
python3 - "$ep" <<'PY' || refuse "the recorded frontier diff does not close EP-A and open EP-B"
import json, sys
ep = sys.argv[1]
load = lambda n: json.load(open(f"{ep}/{n}"))
ids = lambda entries: [e["identity"] for e in entries]
before, after = load("frontier_before.json"), load("frontier_after.json")
assert "EP-A" in ids(before["eligible"]) and "EP-B" not in ids(before["eligible"])
fenced = next(e for e in before["blocked"] if e["identity"] == "EP-B")
assert "EP-A" in json.dumps(fenced), fenced
assert before["standings"] == {"EP-A": "UNKNOWN", "EP-B": "UNKNOWN"}, before["standings"]
assert "EP-A" not in ids(after["eligible"]) and "EP-B" in ids(after["eligible"])
assert after["standings"] == {"EP-A": "ALIVE", "EP-B": "UNKNOWN"}, after["standings"]
events = [json.loads(l) for l in open(f"{ep}/ledger.ndjson") if l.strip()]
assert len(events) == 1 and events[0]["identity"] == "EP-A", events
assert (events[0]["from"], events[0]["to"]) == ("UNKNOWN", "ALIVE")
assert after["events"] == 1 and after["ledger_tail"] == events[0]["event_digest"]
print(f"recorded: EP-A left ({before['ledger_tail'][:19]} -> {after['ledger_tail'][:19]}), EP-B entered")
PY

# 2. live recompute by the graph side
[ -f "$ggen/lib/mix/tasks/semantic_jira.frontier.ex" ] || {
  echo "UNKNOWN: GC23-8 live recompute needs mix semantic_jira.frontier in GGEN_IGNITER_DIR $ggen (the restored mix semantic_jira.* surface, FRI-T6 via lane V23-T6R, not merged there)"
  exit 75
}
mkdir -p "$tmp/build"
if [ -d "$ggen/_build/test" ]; then cp -cRp "$ggen/_build/test" "$tmp/build/test" 2>/dev/null || cp -Rp "$ggen/_build/test" "$tmp/build/test"; fi
cp "$ep/work.json" "$tmp/work.json"
cp "$ep/ledger.ndjson" "$tmp/ledger.ndjson"
: >"$tmp/empty.ndjson"

MIX_ENV=test mix xaas.episode --graph-toolchain --ggen-igniter-dir "$ggen" \
  --ggen-build-path "$tmp/build/test" >"$tmp/toolchain.log" 2>&1 || {
  tail -5 "$tmp/toolchain.log"
  echo "UNKNOWN: GC23-8 no graph-side toolchain resolves for $ggen"
  exit 75
}
python3 - "$tmp/toolchain.log" "$tmp" <<'PY' || { echo "UNKNOWN: GC23-8 unreadable graph-side toolchain"; exit 75; }
import json, sys
log, tmp = sys.argv[1], sys.argv[2]
for line in reversed(open(log).read().splitlines()):
    line = line.strip()
    if line.startswith("{"):
        t = json.loads(line)
        break
else:
    raise SystemExit("no toolchain JSON")
for name, value in (("mix", t["mix"]), ("path", t["path"]), ("what", f"{t['source']} elixir {t['elixir']}")):
    open(f"{tmp}/toolchain.{name}", "w").write(value)
PY
tmix=$(cat "$tmp/toolchain.mix")
tpath=$(cat "$tmp/toolchain.path")
echo "graph-side toolchain: $(cat "$tmp/toolchain.what") ($tmix)"

frontier() {
  (cd "$ggen" && env PATH="$tpath" MIX_ENV=test \
    MIX_BUILD_PATH="$tmp/build/test" "$tmix" semantic_jira.frontier \
    --work-orders "$tmp/work.json" --ledger "$1" </dev/null) >"$2" 2>&1
}
failed() {
  tail -20 "$1"
  if grep -q -e '== Compilation error' -e 'could not compile dependency' "$1"; then
    echo "UNKNOWN: GC23-8 the graph side in $ggen does not compile under the resolved toolchain (BUILD_BROKEN; the court cannot witness)"
    exit 75
  fi
  refuse "$2"
}
frontier "$tmp/empty.ndjson" "$tmp/before.out" || failed "$tmp/before.out" "live frontier (empty ledger) failed"
frontier "$tmp/ledger.ndjson" "$tmp/after.out" || failed "$tmp/after.out" "live frontier (committed ledger) failed"

python3 - "$ep" "$tmp" <<'PY' || refuse "the live recompute disagrees with the recorded frontier"
import json, sys
ep, tmp = sys.argv[1], sys.argv[2]
def last_json(path):
    for line in reversed(open(path).read().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            return json.loads(line)
    raise SystemExit(f"no JSON in {path}")
keys = ["eligible", "blocked", "standings", "events", "ledger_tail"]
for live, recorded in (("before.out", "frontier_before.json"), ("after.out", "frontier_after.json")):
    a = last_json(f"{tmp}/{live}"); b = json.load(open(f"{ep}/{recorded}"))
    for k in keys:
        assert a[k] == b[k], f"{recorded}: {k} live {a[k]!r} != recorded {b[k]!r}"
print("live: frontier_before and frontier_after recomputed identically from the ledger")
PY

echo "ALIVE: GC23-8 closed frontier on episode fmt-1 (EP-A left ALIVE, EP-B entered, recomputed live)"
exit 0
