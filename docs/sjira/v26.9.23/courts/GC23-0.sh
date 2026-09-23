#!/bin/sh
# GC23-0 court: Future Semantics (PRD section 12; goal.ttl v23:GC23-0).
# "Accepted Vision/WBPR exists and has a complete admitted semantic
# projection." Machinery: V23-P (accepted prose, PR-001, AR-003), V23-X
# (candidates, scripts/sjira/prose_spans.py, PR-002), V23-C (ggen_igniter
# `mix semantic_jira.compile_prose`, PR-003/PR-004, ARD sections 5 and 17);
# court body lane V23-K.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses (every tool runs under the F3 no-LLM env, courts/no_llm_env.sh):
#   1. the accepted prose docs/sjira/v26.9.23/prd-ard.md is committed and
#      byte-identical to the accepted revision (sha256 pinned below);
#   2. the candidates (candidates/prd-ard.ttl), their extraction JSON (the
#      only LLM-edited artifact) and the admitted projection
#      (compiled/propositions.ttl, compiled/orders.ttl) are committed;
#   3. `prose_spans.py check --require-gates 13 --extract` binds every
#      candidate to its exact byte span of the prose, re-emits the Turtle from
#      the extraction JSON byte-identically (no hand edit) and covers every
#      gate GC23-0 .. GC23-12;
#   4. `mix semantic_jira.compile_prose --check` (ggen_igniter at
#      GGEN_IGNITER_DIR, courts/gi_mix.sh) admits the candidates -- admission
#      is all-or-nothing: provenance, SHACL, contradiction, foreign
#      requirement, gate coverage -- and recomputes compiled/*.ttl
#      byte-identically; its admitted count equals the verified candidate
#      count and its REQUIRED_BY tally names all 13 gates.
set -u

xaas=${XAAS_DIR:-$(pwd)}
gi=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}
GGEN_IGNITER_DIR=$gi
export GGEN_IGNITER_DIR
cd "$xaas" || { echo "UNKNOWN: GC23-0 XAAS_DIR $xaas unreadable"; exit 75; }

v=docs/sjira/v26.9.23
prose="$v/prd-ard.md"
pinned="7c8797b2bc9130fc4c8fce9138cc8140cb704e0633715807398451c660658212"
courts="$xaas/$v/courts"

refuse() { echo "REFUSED: GC23-0 $*"; exit 1; }
unknown() { echo "UNKNOWN: GC23-0 $*"; exit 75; }

# 1. the accepted prose, committed and byte-identical
if ! git -C "$xaas" ls-files --error-unmatch "$prose" >/dev/null 2>&1; then
  refuse "accepted prose $prose is not committed in $xaas"
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$xaas/$prose" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$xaas/$prose" | cut -d' ' -f1)
fi

if [ "$actual" != "$pinned" ]; then
  refuse "accepted prose drifted: sha256:$actual != sha256:$pinned"
fi
echo "GC23-0 source: $prose sha256:$actual (byte-identical to the accepted prose)"

# 2. candidates, extraction and the admitted projection are committed
for f in candidates/prd-ard.ttl candidates/prd-ard.extract.json goal.ttl \
  compiled/propositions.ttl compiled/orders.ttl; do
  git -C "$xaas" ls-files --error-unmatch "$v/$f" >/dev/null 2>&1 ||
    refuse "$v/$f is not committed in $xaas"
done

if [ ! -f "$gi/lib/mix/tasks/semantic_jira.compile_prose.ex" ]; then
  unknown "admission machinery (lane V23-C) absent: no mix semantic_jira.compile_prose in $gi"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-0.XXXXXX") || unknown "cannot create a temp dir"
trap 'rm -rf "$tmp"' EXIT INT TERM

pyuser=$(python3 -m site --user-base 2>/dev/null) || pyuser=""
py() { sh "$courts/no_llm_env.sh" PYTHONUSERBASE="$pyuser" -- python3 "$@"; }

# 3. provenance binding and coverage of the candidates (V23-X)
py scripts/sjira/prose_spans.py check --source "$prose" \
  --candidates "$v/candidates/prd-ard.ttl" --require-gates 13 \
  --extract "$v/candidates/prd-ard.extract.json" --summary "$tmp/summary.json" \
  >"$tmp/spans.log" 2>&1
code=$?
if [ "$code" = "75" ]; then tail -1 "$tmp/spans.log"; unknown "no-LLM env unbuildable for prose_spans.py"; fi
[ "$code" = "0" ] || { tail -5 "$tmp/spans.log"; refuse "prose_spans.py check exited $code"; }
echo "spans: $(grep '^CHECK OK' "$tmp/spans.log" | cut -c1-160)"

# 4. admission + byte-identical projection (V23-C)
sh "$courts/gi_mix.sh" semantic_jira.compile_prose --check \
  --source "$xaas/$prose" \
  --candidates "$xaas/$v/candidates/prd-ard.ttl" \
  --goal "$xaas/$v/goal.ttl" \
  --out-dir "$xaas/$v/compiled" >"$tmp/check.log" 2>&1
code=$?
if [ "$code" = "75" ]; then tail -1 "$tmp/check.log"; unknown "no-LLM env or ggen_igniter checkout unusable"; fi
[ "$code" = "0" ] || { grep -E '^REFUSED' "$tmp/check.log" | head -20; tail -3 "$tmp/check.log"; refuse "compile_prose --check exited $code"; }

py - "$tmp/summary.json" "$tmp/check.log" <<'PY' || refuse "admitted projection does not cover the verified candidates"
import json, re, sys
summary = json.load(open(sys.argv[1], encoding="utf-8"))
log = open(sys.argv[2], encoding="utf-8").read()
admitted = re.search(r"^ADMITTED: (\d+) propositions \((\d+) required, (\d+) not required\)$", log, re.M)
assert admitted, "no ADMITTED line"
n, required, not_required = map(int, admitted.groups())
assert summary["check"] == "OK" and summary["refusals"] == 0, summary
assert n == summary["candidates"] == summary["verified"], (n, summary["candidates"])
assert (required, not_required) == (summary["required"], summary["not_required"]), (required, not_required)
tally = re.search(r"^REQUIRED_BY: (.*)$", log, re.M)
assert tally, "no REQUIRED_BY line"
counts = dict(pair.split("=") for pair in tally.group(1).split())
gates = [f"GC23-{i}" for i in range(13)]
missing = [g for g in gates if int(counts.get(g, "0")) < 1]
assert not missing, f"uncovered gates {missing}"
assert re.search(r"^CHECK: .* outputs recompute byte-identically$", log, re.M), "no CHECK line"
digests = dict(re.findall(r"^(propositions\.ttl|orders\.ttl) (sha256:[0-9a-f]{64})$", log, re.M))
orders = re.search(r"(\d+) work orders$", log, re.M).group(1)
print(f"admitted {n}/{summary['candidates']} candidates ({required} required, {not_required} not required); "
      f"13/13 gates covered; {orders} work orders; propositions.ttl {digests['propositions.ttl']}; "
      f"orders.ttl {digests['orders.ttl']}")
PY

echo "ALIVE: GC23-0 accepted prose + complete admitted semantic projection (compile_prose --check byte-identical, no LLM)"
exit 0
