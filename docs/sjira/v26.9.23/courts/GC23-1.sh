#!/bin/sh
# GC23-1 court: Cold Bootstrap (PRD section 12, section 8.1; ARD section 16;
# goal.ttl v23:GC23-1). "The system reconstructs its own bounded state without
# chat/session context." Machinery: V23-B (ggen_igniter `mix
# semantic_jira.bootstrap` + scripts/sjira/bootstrap_court.sh, PR-006); court
# body lane V23-K.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Witnesses:
#   1. the ggen_igniter bootstrap court helper ($GGEN_IGNITER_DIR/
#      scripts/sjira/bootstrap_court.sh) passes under the F3 no-LLM env
#      (courts/no_llm_env.sh: env -i, fresh HOME, no LLM variable): it runs
#      `mix semantic_jira.bootstrap` twice in two cold processes over durable
#      artifacts only -- the fleet universe docs/sjira/v26.9.23/fleet/
#      universe.json, the goal graph docs/sjira/v26.9.23/goal.ttl (+ the
#      predecessor Friday goal) and the receipts dirs of both checkouts under
#      judgement ($XAAS_DIR/receipts/v26.9.23, $GGEN_IGNITER_DIR/receipts/
#      v26.9.23) -- and requires byte-identical state files, a recomputed
#      state digest, and every critical-path WorkOrder of goal.ttl
#      reconstructed;
#   2. F3 anti-vacuity: the same helper with ANTHROPIC_API_KEY=x exposed is
#      refused REFUSED(llm_credential_present) (broken term mu_on_O) before
#      any reconstruction.
set -u

xaas=${XAAS_DIR:-$(pwd)}
gi=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
cd "$xaas" || { echo "UNKNOWN: GC23-1 XAAS_DIR $xaas unreadable"; exit 75; }

v=docs/sjira/v26.9.23
courts="$xaas/$v/courts"
helper="$gi/scripts/sjira/bootstrap_court.sh"

refuse() { echo "REFUSED: GC23-1 $*"; exit 1; }
unknown() { echo "UNKNOWN: GC23-1 $*"; exit 75; }

if [ ! -f "$helper" ] || [ ! -f "$gi/lib/mix/tasks/semantic_jira.bootstrap.ex" ]; then
  unknown "bootstrap machinery (lane V23-B) absent: no scripts/sjira/bootstrap_court.sh + mix semantic_jira.bootstrap in $gi"
fi

for f in "$v/goal.ttl" "$v/fleet/universe.json"; do
  git -C "$xaas" ls-files --error-unmatch "$f" >/dev/null 2>&1 || refuse "$f is not committed in $xaas"
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-1.XXXXXX") || unknown "cannot create a temp dir"
trap 'rm -rf "$tmp"' EXIT INT TERM

# bootstrap [NAME=value ...]: the helper under the no-LLM env. The receipts
# dirs list holds a space, which no_llm_env.sh assignments cannot carry, so an
# inner sh sets it.
bootstrap() {
  sh "$courts/no_llm_env.sh" \
    XAAS_DIR="$xaas" GGEN_IGNITER_DIR="$gi" TMPDIR="$tmp" \
    BOOTSTRAP_VERSION=v26.9.23 \
    BOOTSTRAP_FLEET="$xaas/$v/fleet/universe.json" \
    BOOTSTRAP_GOAL="$xaas/$v/goal.ttl" \
    "$@" \
    -- sh -c 'BOOTSTRAP_RECEIPTS_DIRS="$1 $2" exec sh "$0"' \
    "$helper" "$xaas/receipts/v26.9.23" "$gi/receipts/v26.9.23"
}

# 2 first (cheap): F3, an exposed credential is refused before any work
bootstrap ANTHROPIC_API_KEY=x >"$tmp/f3.log" 2>&1
code=$?
if [ "$code" = "75" ]; then tail -1 "$tmp/f3.log"; unknown "no-LLM env unbuildable"; fi
[ "$code" = "1" ] || { tail -3 "$tmp/f3.log"; refuse "F3: the helper with ANTHROPIC_API_KEY=x exited $code, expected 1"; }
grep -q '^REFUSED(llm_credential_present) GC23-1: LLM credential variables set: ANTHROPIC_API_KEY (broken_term mu_on_O)' "$tmp/f3.log" ||
  { tail -3 "$tmp/f3.log"; refuse "F3: no REFUSED(llm_credential_present) for ANTHROPIC_API_KEY"; }
echo "F3: helper with ANTHROPIC_API_KEY=x refused REFUSED(llm_credential_present), broken_term mu_on_O"

# 1. two cold reconstructions
bootstrap >"$tmp/court.log" 2>&1
code=$?
grep -E '^(run[12]:|WARN:|OK:|FAIL:|INVALID:|REFUSED)' "$tmp/court.log" | cut -c1-400
case "$code" in
  0) ;;
  75) unknown "bootstrap helper reports its machinery absent" ;;
  *) tail -5 "$tmp/court.log"; refuse "bootstrap_court.sh exited $code" ;;
esac
grep -q '^OK: GC23-1 two cold bootstrap runs byte-identical (sha256:[0-9a-f]\{64\}); critical-path orders reconstructed: ' "$tmp/court.log" ||
  refuse "bootstrap_court.sh exited 0 without its OK line"

echo "ALIVE: GC23-1 two cold no-LLM reconstructions from durable artifacts are byte-identical; F3 refused"
exit 0
