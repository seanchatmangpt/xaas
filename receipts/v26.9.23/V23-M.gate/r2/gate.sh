#!/bin/sh
# lane gate for V23-M repair 2; run from the lane worktree
set -u
cd /Users/sac/wt/v26922/v23/V23-M || exit 2
for v in $(env | cut -d= -f1 | grep -E '^(ANTHROPIC_|CLAUDE|OPENAI_|ZAI_|Z_AI_|GLM_|ZCODE_)'); do unset "$v"; done
export GGEN_IGNITER_DIR=/Users/sac/wt/v26922/fri/ggen_igniter-int MIX_TEST_PARTITION=_v23m XAAS_DIR=/Users/sac/wt/v26922/v23/V23-M
t=$(mktemp -d "${TMPDIR:-/tmp}/v23m-gate.XXXXXX")
noise='Application.get_env|│|└─|^ *$|\[warning\]|^longnames|^https://www.erlang'
echo "subject: $(git rev-parse HEAD) porcelain=[$(git status --porcelain | tr '\n' ' ')]"
echo "judge: $GGEN_IGNITER_DIR @ $(git -C $GGEN_IGNITER_DIR rev-parse HEAD)"
echo "df: $(df -g /Users/sac | tail -1 | awk '{print $4}') GB free"
echo "== mix format --check-formatted"; mix format --check-formatted >"$t/f" 2>&1; F=$?; grep -Ev "$noise" "$t/f"
echo "FORMAT_EXIT=$F"
echo "== MIX_ENV=test mix compile --force --warnings-as-errors"; MIX_ENV=test mix compile --force --warnings-as-errors >"$t/c" 2>&1; C=$?
grep -E 'Compiling|Generated|error|warning:' "$t/c" | grep -v 'Application.get_env/2 is discouraged'
echo "COMPILE_EXIT=$C"
echo "== mix test test/xaas/ultracode/machine_experience_test.exs"; mix test test/xaas/ultracode/machine_experience_test.exs >"$t/t" 2>&1; T=$?
grep -E 'tests,|Finished|failure|skipped|^ +[0-9]+\) test' "$t/t"
echo "TEST_EXIT=$T"
echo "== sh docs/sjira/v26.9.23/courts/GC23-9.sh"; sh docs/sjira/v26.9.23/courts/GC23-9.sh >"$t/k" 2>&1; K=$?; grep -Ev "$noise" "$t/k"
echo "COURT_EXIT=$K"
echo "final porcelain=[$(git status --porcelain | tr '\n' ' ')]"
rm -rf "$t"
[ "$F$C$T$K" = "0000" ]
