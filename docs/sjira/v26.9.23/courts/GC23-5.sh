#!/bin/sh
# GC23-5 court: Authorized No-LLM Execution (PRD section 12, PR-009/PR-010;
# ARD section 10; goal.ttl v23:GC23-5). Machinery: lane V23-D.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses, over the committed reference episode fmt-1:
#   1. the receipt's executor is the deterministic provider: the R projection's
#      authority.actor, the provider hop's executor and the drive summary all
#      name recipe-worker, and the drive's no-LLM guard passed;
#   2. the OCEL log carries zero LLM-provider events: every Provider object is
#      the deterministic recipe provider and no event or object names an LLM
#      provider (zcode, claude, anthropic, openai, glm, zai);
#   3. anti-vacuity control: `mix xaas.episode --check-env` under the F3
#      no-LLM environment (courts/no_llm_env.sh) passes the guard;
#   4. F3: the same episode rerun with ANTHROPIC_API_KEY=x exposed is refused
#      REFUSED(llm_credential_present), broken term mu_on_O -- by the guard,
#      not by any later refusal.
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
cd "$xaas" || { echo "UNKNOWN: GC23-5 XAAS_DIR $xaas unreadable"; exit 75; }

for f in receipt.r.json hops.json drive.json ocel.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-5 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-5.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-5 $*"; exit 1; }
env_sh="$xaas/docs/sjira/v26.9.23/courts/no_llm_env.sh"

# 1 + 2. executor and OCEL
python3 - "$ep" <<'PY' || refuse "executor is not the deterministic provider, or the OCEL names an LLM provider"
import json, sys
ep = sys.argv[1]
load = lambda n: json.load(open(f"{ep}/{n}", encoding="utf-8"))
r = load("receipt.r.json")
assert r["authority"]["actor"] == "recipe-worker", r["authority"]
hops = {h["hop"]: h for h in load("hops.json")["hops"]}
assert hops["provider"]["executor"] == "recipe-worker", hops["provider"].get("executor")
drive = load("drive.json")
assert drive["provider"] == {"provider": "recipe", "executor": "recipe-worker",
                             "capability": "recipe:mix-format"}, drive["provider"]
assert drive["no_llm_guard"] == "passed"
llm = ("zcode", "claude", "anthropic", "openai", "glm", "zai")
ocel = load("ocel.json")
providers = [o for o in ocel["ocel:objects"] if o["type"] == "Provider"]
assert [o["id"] for o in providers] == ["provider:recipe-worker"], providers
assert providers[0]["attributes"]["deterministic"] == "true"
# every provider-bearing value (event/object attributes provider, executor,
# leased_to; every Provider relationship) names the deterministic provider
keys = ("provider", "executor", "leased_to")
seen = []
for item in ocel["ocel:events"] + ocel["ocel:objects"]:
    for k in keys:
        if k in item["attributes"]:
            seen.append((item["id"], item["attributes"][k]))
    for rel in item.get("relationships", []):
        if rel["objectId"].startswith("provider:"):
            seen.append((item["id"], rel["objectId"]))
bad = [(i, v) for i, v in seen if any(word in v.lower() for word in llm)
       or v not in ("recipe", "recipe-worker", "provider:recipe-worker")]
assert seen and bad == [], f"LLM or non-deterministic provider values: {bad}"
print(f"executor recipe-worker; OCEL {len(ocel['ocel:events'])} events, 0 LLM-provider events/objects")
PY

# 3. anti-vacuity control: the clean no-LLM env passes the guard
MIX_ENV=test sh "$env_sh" -- mix xaas.episode --check-env >"$tmp/control.log" 2>&1
code=$?
if [ "$code" = "75" ]; then tail -1 "$tmp/control.log"; echo "UNKNOWN: GC23-5 no-LLM env unbuildable"; exit 75; fi
[ "$code" = "0" ] || { tail -3 "$tmp/control.log"; refuse "control: the no-LLM env did not pass the guard (exit $code)"; }
echo "control: $(tail -1 "$tmp/control.log")"

# 4. F3: an exposed LLM credential is refused by the guard
MIX_ENV=test sh "$env_sh" ANTHROPIC_API_KEY=x -- \
  mix xaas.episode --name fmt-1 --ggen-igniter-dir "$ggen" >"$tmp/f3.log" 2>&1
code=$?
[ "$code" = "3" ] || { tail -3 "$tmp/f3.log"; refuse "F3: episode rerun with ANTHROPIC_API_KEY=x exited $code, expected 3"; }
tail -1 "$tmp/f3.log" | python3 -c '
import json, sys
r = json.loads(sys.stdin.read())
assert r["standing"] == "REFUSED(llm_credential_present)", r
assert r["broken_term"] == "mu_on_O" and r["hop"] == "guard", r
assert r["detail"]["variables"] == ["ANTHROPIC_API_KEY"], r
' || refuse "F3: refusal is not REFUSED(llm_credential_present) at the guard"
echo "F3: $(tail -1 "$tmp/f3.log")"

echo "ALIVE: GC23-5 no-LLM KNOWN execution witnessed on episode fmt-1 (recipe-worker, 0 LLM events, F3 refused)"
exit 0
