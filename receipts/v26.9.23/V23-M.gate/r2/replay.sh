#!/bin/sh
# Replay of the committed episodes me-1/me-2 with the repair-2 code (subject d9939a6) into scratch:
# scratch subject clone, --no-pin, no shared ref written.
set -u
S=/private/tmp/claude-501/-Users-sac/1fecd79a-9323-4b57-a949-d7892a3ea283/scratchpad/v23m-r2
R=$S/replay; X=/Users/sac/wt/v26922/v23/V23-M; G=/Users/sac/wt/v26922/fri/ggen_igniter-int
EPS=$X/docs/sjira/v26.9.23/episodes
cd "$X" || exit 2
for v in $(env | cut -d= -f1 | grep -E '^(ANTHROPIC_|CLAUDE|OPENAI_|ZAI_|Z_AI_|GLM_|ZCODE_)'); do unset "$v"; done
export MIX_ENV=test MIX_TEST_PARTITION=_v23m
rm -rf "$R"; mkdir -p "$R/build" "$R/eps" "$R/work"
git clone -q --local --no-checkout /Users/sac/ggen_igniter "$R/subject"
cp -cRp "$G/_build/test" "$R/build/test"
base=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["base"])' "$EPS/me-1/prepare.json")
echo "subject code: $(git rev-parse HEAD); judge $G @ $(git -C $G rev-parse HEAD); episode base $base"
nle() { sh docs/sjira/v26.9.23/courts/no_llm_env.sh -- "$@"; }
last() { grep -E '^\{' "$1" | tail -1; }
for pair in "me-1:lib/ggen_igniter/semantic_jira/reconciler.ex" "me-2:lib/ggen_igniter/semantic_jira/transition_log.ex"; do
  n=${pair%%:*}; d=${pair#*:}
  nle mix xaas.machine_experience --prepare --name "$n" --ggen-igniter-dir "$G" --subject-repo "$R/subject" \
    --base "$base" --drift "$d" --out-root "$R/eps" >"$R/prepare-$n.log" 2>&1; c=$?
  sha=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["subject_sha"])' "$R/eps/$n/prepare.json")
  committed=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["subject_sha"])' "$EPS/$n/prepare.json")
  cmp -s "$R/eps/$n/work.json" "$EPS/$n/work.json"; w=$?
  echo "prepare $n: exit $c; drift commit $sha (committed $committed, equal=$([ "$sha" = "$committed" ] && echo yes || echo no)); work.json byte-identical=$([ $w = 0 ] && echo yes || echo no)"
done
nle mix xaas.machine_experience --name me-1 --ggen-igniter-dir "$G" --subject-repo "$R/subject" \
  --ggen-build-path "$R/build/test" --work-root "$R/work" --out-root "$R/eps" --no-pin >"$R/me1-unknown.log" 2>&1; c=$?
echo "me-1 without exploration: exit $c $(last "$R/me1-unknown.log" | python3 -c 'import json,sys;r=json.loads(sys.stdin.read());print(r["standing"],r["reason"],"considered",len(r["detail"]["experiences_considered"]))')"
cp "$EPS/me-1/exploration.json" "$R/eps/me-1/exploration.json"
nle mix xaas.machine_experience --name me-1 --ggen-igniter-dir "$G" --subject-repo "$R/subject" \
  --ggen-build-path "$R/build/test" --work-root "$R/work" --out-root "$R/eps" --no-pin >"$R/me1-explore.log" 2>&1; c=$?
echo "me-1 with the committed exploration.json: exit $c"
python3 - "$R/eps/me-1/episode.json" "$EPS/me-1/episode.json" <<'PY'
import json, sys
new, old = (json.load(open(p)) for p in sys.argv[1:3])
for label, e in (("replay", new), ("committed", old)):
    o = e["ocel"]
    print(f"  {label}: standing {e['standing']} decision {e['decision']} steps {e['step_count']} events {o['events']} objects {o['objects']} "
          f"llm {o['llm_provider_events']} exploration {o['exploration_events']} equivalent {o['equivalent']} "
          f"used {({k: v for k, v in e['exploration']['used'].items() if k != 'attempts'})} ME {e['machine_experience']['machine_experience']}")
assert new["ocel"]["by_class"] == old["ocel"]["by_class"], (new["ocel"]["by_class"], old["ocel"]["by_class"])
assert new["steps"] == old["steps"] and new["standing"] == old["standing"] == "ALIVE"
print("  by_class equal, steps equal")
PY
nle mix xaas.machine_experience --name me-2 --ggen-igniter-dir "$G" --subject-repo "$R/subject" \
  --ggen-build-path "$R/build/test" --work-root "$R/work" --out-root "$R/eps" --no-pin \
  --experience "$R/eps/me-1/machine_experience.ttl" >"$R/me2.log" 2>&1; c=$?
echo "me-2 KNOWN from the replayed me-1 experience: exit $c"
python3 - "$R/eps/me-2/episode.json" "$EPS/me-2/episode.json" "$R/eps/me-1/episode.json" <<'PY'
import json, sys, os
new, old, me1 = (json.load(open(p)) for p in sys.argv[1:4])
for label, e in (("replay", new), ("committed", old)):
    o = e["ocel"]
    print(f"  {label}: standing {e['standing']} decision {e['decision']} steps {e['step_count']} events {o['events']} "
          f"llm {o['llm_provider_events']} exploration {o['exploration_events']} equivalent {o['equivalent']} route {e['route']['machine_experience']}")
assert new["route"]["machine_experience"] == me1["machine_experience"]["machine_experience"]
assert new["ocel"]["by_class"] == old["ocel"]["by_class"] and new["steps"] == old["steps"]
assert not os.path.exists(os.path.join(os.path.dirname(sys.argv[1]), "exploration.json"))
print("  route cites the replayed me-1 IRI; by_class equal, steps equal; no exploration artifact")
PY
python3 - "$R/eps/me-1/machine_experience.json" "$EPS/me-1/machine_experience.json" <<'PY'
import json, sys
new, old = (json.load(open(p)) for p in sys.argv[1:3])
for label, r in (("replay", new), ("committed", old)):
    refs = r["experience"]["observation_refs"]
    print(f"  {label}: {r['machine_experience']} refs sorted {refs == sorted(refs)} admission {r['admission']['admission_digest'][:23]}...")
diff = sorted(k for k in old["admission"] if old["admission"][k] != new["admission"].get(k))
print(f"  admission fields that differ replay vs committed: {diff}")
PY
nle mix xaas.machine_experience --route --work "$EPS/me-2/work.json" --experience "$R/eps/me-1/machine_experience.ttl" >"$R/route-replayed.log" 2>&1; c=$?
echo "route me-2 over the REPLAYED me-1 graph: exit $c $(last "$R/route-replayed.log" | python3 -c 'import json,sys;r=json.loads(sys.stdin.read());print(r["standing"],r["machine_experience"],r["capability"])')"
nle mix xaas.machine_experience --route --work "$EPS/me-2/work.json" --experience "$EPS/me-1/machine_experience.ttl" >"$R/route.log" 2>&1; c=$?
echo "route me-2 over the COMMITTED me-1 graph: exit $c $(last "$R/route.log" | python3 -c 'import json,sys;r=json.loads(sys.stdin.read());print(r["standing"],r["machine_experience"],r["capability"])')"
git -C /Users/sac/ggen_igniter for-each-ref --format='%(refname:short) %(objectname:short)' 'refs/heads/v23/episode-me-*'
