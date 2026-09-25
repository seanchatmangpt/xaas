#!/bin/sh
# Regenerates the committed episodes me-1/me-2 with the repair-2 code (V23-M; GC23-9):
# the admission digest now binds the whole record (v2) and the record's refs are a sorted set,
# so episodes produced by the earlier code no longer verify at routing (by design).
# Subject repo: /Users/sac/ggen_igniter (the drift branches v23/episode-me-{1,2} already exist
# at the recorded drift commits; work.json/prepare.json are kept byte-identical). New receipt
# heads are pinned under NEW create-only refs v23/episode-me-{1,2}-r2-receipt; the earlier
# refs (bd84b3e, 48ae4ad) are left untouched.
set -u
X=/Users/sac/wt/v26922/v23/V23-M
G=/Users/sac/wt/v26922/fri/ggen_igniter-int
S=/private/tmp/claude-501/-Users-sac/1fecd79a-9323-4b57-a949-d7892a3ea283/scratchpad/v23m-r2
EPS=docs/sjira/v26.9.23/episodes
cd "$X" || exit 2
for v in $(env | cut -d= -f1 | grep -E '^(ANTHROPIC_|CLAUDE|OPENAI_|ZAI_|Z_AI_|GLM_|ZCODE_)'); do unset "$v"; done
export MIX_ENV=test MIX_TEST_PARTITION=_v23m
rm -rf "$S/build" "$S/work" "$S/aside"; mkdir -p "$S/build" "$S/work" "$S/aside"
cp -cRp "$G/_build/test" "$S/build/test"
echo "code subject: $(git rev-parse HEAD) + working tree (porcelain: $(git status --porcelain | wc -l | tr -d ' ') paths)"
echo "judge: $G @ $(git -C $G rev-parse HEAD)"
echo "refs before: $(git -C /Users/sac/ggen_igniter for-each-ref --format='%(refname:short)=%(objectname:short)' 'refs/heads/v23/episode-me-*' | tr '\n' ' ')"
echo "df: $(df -g /Users/sac | tail -1 | awk '{print $4}') GB free"
nle() { sh docs/sjira/v26.9.23/courts/no_llm_env.sh -- "$@"; }
last() { grep -E '^\{' "$1" | tail -1; }
# 1. episode 1 before exploration: UNKNOWN, receipted, nothing executed
mv "$EPS/me-1/exploration.json" "$S/aside/exploration.json"
nle mix xaas.machine_experience --name me-1 --ggen-igniter-dir "$G" --ggen-build-path "$S/build/test" \
  --work-root "$S/work" --pin-ref v23/episode-me-1-r2-receipt >"$S/episode-me1-unknown.log" 2>&1; c=$?
mv "$S/aside/exploration.json" "$EPS/me-1/exploration.json"
echo "me-1 before exploration: exit $c $(last "$S/episode-me1-unknown.log" | cut -c1-200)"
# 2. episode 1 with the committed exploration artifact
nle mix xaas.machine_experience --name me-1 --ggen-igniter-dir "$G" --ggen-build-path "$S/build/test" \
  --work-root "$S/work" --pin-ref v23/episode-me-1-r2-receipt >"$S/episode-me1-explore.log" 2>&1; c=$?
echo "me-1 with exploration: exit $c $(last "$S/episode-me1-explore.log" | python3 -c 'import json,sys;r=json.loads(sys.stdin.read());print(r["standing"],r["decision"],r["step_count"],"steps",r["ocel"]["events"],"events",r["machine_experience"]["machine_experience"])' 2>&1)"
# 3. episode 2 from the regenerated admitted experience
nle mix xaas.machine_experience --name me-2 --ggen-igniter-dir "$G" --ggen-build-path "$S/build/test" \
  --work-root "$S/work" --pin-ref v23/episode-me-2-r2-receipt \
  --experience "$EPS/me-1/machine_experience.ttl" >"$S/episode-me2.log" 2>&1; c=$?
echo "me-2 KNOWN: exit $c $(last "$S/episode-me2.log" | python3 -c 'import json,sys;r=json.loads(sys.stdin.read());print(r["standing"],r["decision"],r["step_count"],"steps",r["ocel"]["events"],"events",r["route"]["machine_experience"])' 2>&1)"
echo "refs after: $(git -C /Users/sac/ggen_igniter for-each-ref --format='%(refname:short)=%(objectname:short)' 'refs/heads/v23/episode-me-*' | tr '\n' ' ')"
