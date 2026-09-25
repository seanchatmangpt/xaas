#!/bin/sh
# Court anti-vacuity over the committed episode fmt-1 (lane V23-D, B1b):
# each court runs on a scratch copy of the episode with ONE artifact
# tampered and must refuse (exit 1). GGEN_IGNITER_DIR = ggen_igniter-int.
set -u
xaas=/Users/sac/wt/v26922/v23/V23-D
S=/private/tmp/claude-501/v23-scratch/B1b-V23-D
ggen=/Users/sac/wt/v26922/fri/ggen_igniter-int
src=$xaas/docs/sjira/v26.9.23/episodes/fmt-1
fail=0

run() {
  gate=$1; label=$2; py=$3
  d=$S/tamper-$gate-$label
  rm -rf "$d"; cp -R "$src" "$d"
  python3 - "$d" <<PY || { echo "TAMPER-SETUP-FAILED $gate $label"; fail=1; return; }
import json, sys
d = sys.argv[1]
load = lambda n: json.load(open(f"{d}/{n}"))
def save(n, v): json.dump(v, open(f"{d}/{n}", "w"), indent=2)
$py
PY
  (cd "$xaas" && XAAS_DIR=$xaas GGEN_IGNITER_DIR=$ggen MIX_TEST_PARTITION=_v23d TMPDIR=$S GC23_EPISODE_DIR=$d \
    sh docs/sjira/v26.9.23/courts/$gate.sh) >"$d.log" 2>&1
  code=$?
  last=$(grep -E '^(REFUSED|ALIVE|UNKNOWN):' "$d.log" | tail -1)
  if [ "$code" = "1" ]; then echo "HELD $gate [$label] exit=1 :: $last"; else echo "NOT-HELD $gate [$label] exit=$code :: $last"; fail=1; fi
  rm -rf "$d"
}

run GC23-4 provider-subject-mutated 'h = load("hops.json"); p = [x for x in h["hops"] if x["hop"] == "provider"][0]; p["tuple"]["subject"] = p["tuple"]["subject"] + "-forged"; save("hops.json", h)'
run GC23-5 actor-zcode 'r = load("receipt.r.json"); r["authority"]["actor"] = "zcode"; save("receipt.r.json", r)'
run GC23-6 consequence-removed 'r = load("receipt.json"); r["final_head"] = "80a8a4c71b331a39771ad65d1149eb835645d17c"; save("receipt.json", r)'
run GC23-7 ocel2-event-dropped 'o = load("ocel2.json"); o["events"] = o["events"][:-1]; save("ocel2.json", o)'
run GC23-8 ep-b-not-entered 'f = load("frontier_after.json"); f["eligible"] = [e for e in f["eligible"] if e["identity"] != "EP-B"]; save("frontier_after.json", f)'
run GC23-8 live-digest-disagrees 'f = load("frontier_before.json"); f["eligible"][0]["work_order_digest"] = "sha256:" + "0" * 64; save("frontier_before.json", f)'
echo "TAMPER_FAIL=$fail"
exit $fail
