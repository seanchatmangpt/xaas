#!/bin/zsh
# Sequenced ultracode drain: wave -> merge integration branch into main -> verify -> refresh clone -> next wave.
# A batch is never abandoned before its integration branch is merged and verified; a conflict, a failed
# compile, or a failed test STOPS the drain (fix forward; no auto-resolution, no reset, no force).
# Hand-written residue: UNSUPPORTED(generator-capability) (see HANDWRITTEN.md).
#
#   scripts/ultracode_sequenced_drain.sh [--batch N] [--max-batches M] [--pattern REGEX] [--dry-run]
#
# Requires: phx server running with INTERNAL_API_TOKEN equal to the xaas-fabric plugin's zcode_xaas_token
# (the worker leg claims/closes leases over the xaas-execution MCP endpoint), node>=22 first on PATH.
set -u
BATCH=3; MAXB=12; PATTERN='jira-xa-30[0-9][0-9]-'; DRY=0
while [ $# -gt 0 ]; do case $1 in
  --batch) BATCH=$2; shift 2;; --max-batches) MAXB=$2; shift 2;;
  --pattern) PATTERN=$2; shift 2;; --dry-run) DRY=1; shift;; *) echo "bad arg $1"; exit 2;; esac; done

REPO=${XAAS_REPO:-$HOME/xaas}; CLONE=$REPO/worktrees/repos/xaas
export PATH=$HOME/.local-xaas-bin:$HOME/.asdf/shims:$PATH
cd "$REPO" || exit 2
TOK=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.zcode/cli/config.json')))['plugins']['options']['xaas-fabric@xaas-fabric-marketplace']['zcode_xaas_token'])") || { echo "REFUSED(token_unreadable)"; exit 3; }
curl -s -m5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' localhost:4000/internal-api/execution/mcp | grep -q '^200$' \
  || { echo "BLOCKED(fabric_unreachable): start mix phx.server with INTERNAL_API_TOKEN"; exit 3; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "BLOCKED(dirty_main_tree)"; git status --short | head; exit 3; }

open_ids() {
  mix run --no-start -e '{:ok,p}=Xaas.Ultracode.Sensing.profile("xaas-sjira"); {:ok,r}=Xaas.Ultracode.Sensing.derive(p,System.get_env("CLONE")); items=r["items"]||r[:items]||r; IO.puts("IDS:" <> Enum.join(for(i<-items, Regex.match?(Regex.compile!(System.get_env("PATTERN")), i["id"]), do: i["id"]), ","))' 2>/dev/null \
    | grep -a '^IDS:' | tail -1 | sed 's/^IDS://'
}

declare -A tries
for n in $(seq 1 $MAXB); do
  mix xaas.ultracode.repos --refresh xaas >/dev/null 2>&1
  ALL=$(CLONE=$CLONE PATTERN=$PATTERN open_ids)
  [ -n "$ALL" ] || { echo "DRAINED: no open tickets matching $PATTERN"; exit 0; }
  # skip tickets already tried twice without landing (no infinite loop)
  SEL=""; cnt=0
  for id in ${(s:,:)ALL}; do
    [ "${tries[$id]:-0}" -ge 2 ] && continue
    SEL="${SEL:+$SEL,}$id"; cnt=$((cnt+1)); [ $cnt -ge $BATCH ] && break
  done
  [ -n "$SEL" ] || { echo "STUCK: remaining tickets tried twice without landing: $ALL"; exit 4; }
  echo "== batch $n: $SEL"; [ $DRY = 1 ] && exit 0
  for id in ${(s:,:)SEL}; do tries[$id]=$(( ${tries[$id]:-0} + 1 )); done

  LOG=${TMPDIR:-/tmp}/drain-batch-$n.log
  INTERNAL_API_TOKEN="$TOK" mix xaas.ultracode.start --repo xaas --capacity $BATCH --duration 2h \
    --wave-interval 10m --max-waves 1 --only "$SEL" --goal "sequenced drain batch $n" > "$LOG" 2>&1
  RCPT=$(grep -a -E '^wave 1:' "$LOG" | awk '{print $NF}')
  echo "wave receipt: $RCPT"
  [ -f "$RCPT" ] || { echo "no receipt; see $LOG"; continue; }
  BR=$(python3 -c "
import json,sys
d=json.load(open('$RCPT')); i=d.get('integration') or {}
print(i.get('branch','') if isinstance(i,dict) else '')")
  if [ -z "$BR" ]; then echo "nothing promoted in batch $n (standing $(python3 -c "import json;print(json.load(open('$RCPT')).get('standing'))"))"; continue; fi

  # MERGE (sequenced: the batch is not finished until this lands and verifies)
  git fetch -q "$CLONE" "$BR:refs/remotes/clone/$BR" || { echo "BLOCKED(fetch_integration_branch:$BR)"; exit 5; }
  MSG=${TMPDIR:-/tmp}/drain-merge-$n.txt
  printf 'merge: ultracode sequenced drain batch %s (%s)\n\nIntegration branch %s from the xaas clone; tickets: %s\n' "$n" "$BR" "$BR" "$SEL" > "$MSG"
  if ! git merge --no-ff -F "$MSG" "refs/remotes/clone/$BR"; then
    echo "BLOCKED(merge_conflict:$BR): resolve by reading both sides; drain stopped"; git status --short | head; exit 6
  fi
  mix compile > ${TMPDIR:-/tmp}/drain-compile-$n.log 2>&1 || { echo "BUILD_BROKEN after merging $BR; see drain-compile-$n.log"; exit 7; }
  TESTS=$(git diff --name-only HEAD~1 HEAD -- 'test/*_test.exs' | tr '\n' ' ')
  if [ -n "$TESTS" ]; then
    mix test ${=TESTS} > ${TMPDIR:-/tmp}/drain-test-$n.log 2>&1 || { echo "TESTS_FAILED after merging $BR: $TESTS (drain-test-$n.log)"; exit 8; }
  fi
  echo "MERGED+VERIFIED batch $n: $BR tests=[$TESTS] head=$(git rev-parse --short HEAD)"
done
echo "max batches reached"
