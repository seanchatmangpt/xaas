# W463 — remaining test/xaas dirs slice

Wave skip list (already witnessed): a2a(W454), accounts(W416), actuation+W414(corpus),
autofde(W457), bridges(W456), castle*(corpus), chicago(W435), conference(W453), generated(W350),
library(W455), marketplace(W427/W429), ontology(W387), operations(W433), receipt(W443), sjira(W442),
semantics(W447), telemetry(W432), ultracode(W425), witness(W434), vault(guard).

Remaining dirs with tests (30):
architecture billing causal_receipt case_studies coupling cs2 deployment eds fabric gall
governance graphlaw igniter mix ocel pack planning platform release research_runtime runtime
sa2a security temporal_memory trimtab tunnel verifiers workbench zcode_plugin zoe

Plan: single batch run under lane build root:
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW463 \
  mix test test/xaas/<each remaining dir> 2>&1 | tail

On failure: isolate once, classify verbatim vs w300/w315-era. Verdict green-at-final-tree or findings.

## RESULT (2026-10-06)

Batch 1 (19 dirs: architecture billing causal_receipt case_studies coupling cs2 deployment eds
fabric gall governance graphlaw igniter mix ocel pack planning platform release):
`Result: 376 passed, 17 excluded` EXIT=0
Batch 2 (11 dirs: research_runtime runtime sa2a security temporal_memory trimtab tunnel
verifiers workbench zcode_plugin zoe):
`Result: 276 passed, 18 skipped, 2 excluded` EXIT=0

Verdict: REMAINING DIRS GREEN-AT-FINAL-TREE. 652 passed / 0 failed across 30 remaining dirs.

Cleanup: `rm -rf /Users/sac/xaas/_build-laneW463` DENIED twice by permission system
(sandboxed and unsandboxed). Build root left on disk — coordinator to delete at integration
per same-checkout-fanout cleanup law.
