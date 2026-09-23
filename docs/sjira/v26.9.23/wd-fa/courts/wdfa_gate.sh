#!/bin/sh
# Gate courts of GC-WDFA-PILOT (docs/sjira/v26.9.23/wd-fa/goal.ttl; lane V23-W,
# PRD section 9.2). Every gate's sj:courtCommand is
#   sh docs/sjira/v26.9.23/wd-fa/courts/wdfa_gate.sh <WDFA-n | GC-WDFA-PILOT>
# run from the xaas root (XAAS_DIR overrides). Exit contract (V23-P): 0 ALIVE,
# 75 UNKNOWN (machinery or a Western Digital input absent), anything else
# refused. No LLM runs here: a run with an LLM credential variable set is
# refused REFUSED(llm_credential_present), broken term mu_on_O (exit 3), so
# run it under the F3 env, which also needs the durable Python/validator
# configuration passed explicitly (a fresh HOME hides the user site and ~/.claude):
#   sh docs/sjira/v26.9.23/courts/no_llm_env.sh \
#     PYTHONUSERBASE="$(python3 -m site --user-base)" \
#     DFCM_VALIDATOR="$HOME/.claude/dfcm/validate_receipt.py" -- \
#     sh docs/sjira/v26.9.23/wd-fa/courts/wdfa_gate.sh WDFA-0
#
# WDFA-0  runs the V23-W lane gate (prose_spans.py check of the WBPR candidates
#         + wd_claims.py check of the claims ledger and its rendered proposal);
#         a failure is refused (exit 1). A passing ledger is still UNKNOWN (75)
#         until wd-fa/acceptance.json records the operator's and a Western
#         Digital sponsor's acceptance of the exact wbpr.md digest -- the gate's
#         description includes acceptance, and this court does not manufacture it.
# WDFA-1 .. WDFA-6 and the root: UNKNOWN (75) naming the unsupplied WD input.
set -u

gate=${1:-}
root=${XAAS_DIR:-$(pwd)}
cd "$root" || { echo "UNKNOWN: wdfa_gate: XAAS_DIR $root unreadable"; exit 75; }
wd=docs/sjira/v26.9.23/wd-fa

llm=$(env | grep -E '^(ANTHROPIC_[A-Za-z0-9_]*|CLAUDE_[A-Za-z0-9_]*|CLAUDECODE|OPENAI_[A-Za-z0-9_]*|ZAI_[A-Za-z0-9_]*|Z_AI_[A-Za-z0-9_]*|GLM_[A-Za-z0-9_]*|ZCODE_[A-Za-z0-9_]*)=' | cut -d= -f1 | sort | tr '\n' ' ')
if [ -n "$llm" ]; then
  echo "REFUSED(llm_credential_present) $gate: LLM credential variables set: ${llm% } (broken_term mu_on_O)"
  exit 3
fi

unknown() { echo "UNKNOWN: $gate requires Western Digital input: $1"; exit 75; }

case "$gate" in
  WDFA-0)
    python3 scripts/sjira/prose_spans.py check --source "$wd/wbpr.md" --candidates "$wd/candidates.ttl" \
      --extract "$wd/wbpr.extract.json" || { echo "REFUSED WDFA-0: candidate provenance check failed"; exit 1; }
    python3 scripts/sjira/wd_claims.py check --ledger "$wd/claims.ttl" --proposal "$wd/proposal.md" ||
      { echo "REFUSED WDFA-0: claims ledger court failed"; exit 1; }
    if [ ! -f "$wd/acceptance.json" ]; then
      echo "UNKNOWN: WDFA-0 claims ledger admitted; WBPR acceptance (operator, then a Western Digital sponsor) is not recorded in $wd/acceptance.json"
      exit 75
    fi
    echo "UNKNOWN: WDFA-0 acceptance.json present but no acceptance verifier has landed (successor work)"
    exit 75 ;;
  WDFA-1) unknown "read access to the pilot corpus and data lake, and a corpus inventory" ;;
  WDFA-2) unknown "the failure-mode catalogue with applicability conditions and falsifiers (reference kernel: autofde-lab eb93405c, synthetic only)" ;;
  WDFA-3) unknown "admitted real case state to project; the prototype pages 2a-2h are illustrative" ;;
  WDFA-4) unknown "authorization roles for closure and escalation, and the QMS/MES write-back decision" ;;
  WDFA-5) unknown "real dispositions and reopen events from a pilot" ;;
  WDFA-6) unknown "the MTTR baseline by failure mode and its measurement method, a golden set, and a shadow period" ;;
  GC-WDFA-PILOT) unknown "a sponsor's acceptance; STOP(GC-WDFA-PILOT) needs every gate ALIVE" ;;
  *) echo "wdfa_gate: unknown gate '$gate' (expected WDFA-0 .. WDFA-6 or GC-WDFA-PILOT)" >&2; exit 2 ;;
esac
