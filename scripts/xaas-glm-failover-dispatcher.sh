#!/usr/bin/env bash
#
# xaas-glm-failover-dispatcher.sh
#
# Unattended trigger for the zcode/GLM failover worker. Polls the XaaS
# Postgres for provider='zcode' epochs that are :running (advanced there by the
# real Oban :tick -> Xaas.Ultracode.Reactor) with lease_token IS NULL, and runs
# one headless zcode turn (`/xaas`, the plugin's worker protocol) per pass so
# the worker claims via the MCP fabric. It never grants tools: Bash, git_push
# and publish stay hard-refused server-side by Xaas.Ultracode.Lease.admit_tool.
#
# Usage: xaas-glm-failover-dispatcher.sh [--once] [--interval SECONDS]
#
# Env (defaults in parens):
#   PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE  (localhost 5432 postgres postgres xaas_dev)
#   ZCODE_CLI_DIR        (/Users/sac/dev/zcode-cli)
#   POLL_INTERVAL        (30)    seconds between passes
#   DISPATCH_TIMEOUT     (840)   seconds before a zcode turn is killed; keep < run epoch_timeout_seconds (900)
#   MAX_DRAIN            (5)     max dispatches per pass before yielding to the next poll
#   STALL_ALERT_SECONDS  (600)   oldest unleased ready epoch older than this raises an ALERT
#   STATE_DIR            (~/.zcode/failover)  heartbeat, alert, lock, per-dispatch logs

set -u
set -o pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
PGDATABASE="${PGDATABASE:-xaas_dev}"
export PGPASSWORD

ZCODE_CLI_DIR="${ZCODE_CLI_DIR:-/Users/sac/dev/zcode-cli}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
DISPATCH_TIMEOUT="${DISPATCH_TIMEOUT:-840}"
MAX_DRAIN="${MAX_DRAIN:-5}"
STALL_ALERT_SECONDS="${STALL_ALERT_SECONDS:-600}"
STATE_DIR="${STATE_DIR:-$HOME/.zcode/failover}"

ONCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --once) ONCE=1; shift ;;
    --interval) POLL_INTERVAL="${2:?--interval requires a value}"; shift 2 ;;
    --interval=*) POLL_INTERVAL="${1#--interval=}"; shift ;;
    -h|--help) echo "Usage: $0 [--once] [--interval SECONDS]"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$STATE_DIR"

log() {
  printf '%s [xaas-glm-failover] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1"
}

LOCK_DIR="$STATE_DIR/dispatcher.lock"

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$LOCK_DIR/pid"
    return 0
  fi
  holder="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    log "another dispatcher is running (pid=${holder}); exiting"
    return 1
  fi
  log "reclaiming stale lock (pid=${holder:-unknown} not alive)"
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  mkdir "$LOCK_DIR" 2>/dev/null || return 1
  echo "$$" > "$LOCK_DIR/pid"
}

release_lock() {
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

# One "id|worktree|age_seconds" row per unleased running zcode epoch, oldest first
# (same order as Lease.claim_next).
find_ready_epochs() {
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=1 -t -A -F'|' \
    -c "SELECT e.id, COALESCE(e.worktree, ''),
               GREATEST(0, EXTRACT(EPOCH FROM (now() AT TIME ZONE 'utc' - e.inserted_at)))::bigint
        FROM ultracode_epochs e
        JOIN ultracode_runs r ON r.id = e.run_id
        WHERE r.provider = 'zcode'
          AND e.state = 'running'
          AND e.lease_token IS NULL
        ORDER BY e.inserted_at ASC;" 2>&1
}

# Kills the command after DISPATCH_TIMEOUT seconds (SIGALRM survives exec).
run_with_timeout() {
  perl -e 'alarm shift; exec @ARGV or exit 127' "$DISPATCH_TIMEOUT" "$@"
}

notify_stall() {
  msg="$1"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$msg" > "$STATE_DIR/alert"
  log "ALERT ${msg}"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${msg}\" with title \"XaaS GLM failover\"" >/dev/null 2>&1 || true
  fi
}

# A missing/empty worktree epoch is dispatched from a scratch cwd so the worker
# can claim and refuse it through the fabric; it cannot write to any repo.
dispatch_one_epoch() {
  epoch_id="$1"
  worktree="$2"
  cwd="$worktree"
  mode="claim"

  if [ -z "$worktree" ] || [ ! -d "$worktree" ]; then
    cwd="$(mktemp -d "${TMPDIR:-/tmp}/xaas-failover-reap.XXXXXX")"
    mode="reap"
  fi

  logfile="$STATE_DIR/dispatch-${epoch_id}.log"
  log "DISPATCH epoch=${epoch_id} mode=${mode} worktree=${worktree:-none} log=${logfile}"

  # zcode memory can resurrect a stale "session id" from an earlier prompt, so
  # the worker id is passed explicitly rather than left to the model to infer.
  worker_id="zcode-dispatch-$(hostname -s)-${epoch_id%%-*}-$$"

  # XAAS_WORKER=1 arms the xaas-fabric plugin's PreToolUse gate (host-enforced
  # admit_tool, worktree-confined writes, Bash allowlist); XAAS_LEASE_CWD tells
  # it where the lease file for this session lives.
  cwd_real="$(cd "$cwd" && pwd -P)"

  (
    cd "$ZCODE_CLI_DIR" || exit 127
    export XAAS_WORKER=1 XAAS_LEASE_CWD="$cwd_real"
    run_with_timeout node bin/zcode.js \
      --prompt "/xaas Call claim_next with provider_worker_id exactly \"${worker_id}\"; do not use any other id." \
      --cwd "$cwd_real" --json
  ) > "$logfile" 2>&1
  rc=$?

  [ "$mode" = "reap" ] && rmdir "$cwd" 2>/dev/null

  case "$rc" in
    0) log "DISPATCH-OK epoch=${epoch_id} exit=0" ;;
    142) log "DISPATCH-TIMEOUT epoch=${epoch_id} after=${DISPATCH_TIMEOUT}s" ;;
    *) log "DISPATCH-FAIL epoch=${epoch_id} exit=${rc}" ;;
  esac
  return 0
}

run_once_pass() {
  date +%s > "$STATE_DIR/heartbeat"
  drained=0
  prev_count=-1

  while [ "$drained" -lt "$MAX_DRAIN" ]; do
    rows="$(find_ready_epochs)"
    if [ "$?" -ne 0 ]; then
      log "QUERY-FAIL output=${rows}"
      return 0
    fi

    if [ -z "$rows" ]; then
      [ "$drained" -eq 0 ] && log "no ready work (zero provider=zcode running+unleased epochs)"
      rm -f "$STATE_DIR/alert"
      return 0
    fi

    count="$(printf '%s\n' "$rows" | grep -c .)"
    IFS='|' read -r head_id head_worktree head_age <<EOF
$(printf '%s\n' "$rows" | head -n 1)
EOF

    if [ "${head_age:-0}" -ge "$STALL_ALERT_SECONDS" ]; then
      notify_stall "epoch ${head_id} unleased for ${head_age}s (>= ${STALL_ALERT_SECONDS}s); ${count} ready"
    fi

    if [ "$prev_count" -ge 0 ] && [ "$count" -ge "$prev_count" ]; then
      log "no progress after dispatch (ready ${prev_count} -> ${count}); yielding to next poll"
      return 0
    fi
    prev_count="$count"

    dispatch_one_epoch "$head_id" "$head_worktree"
    drained=$((drained + 1))
  done

  log "pass complete: ${drained} dispatch(es), MAX_DRAIN=${MAX_DRAIN} reached"
  return 0
}

acquire_lock || exit 0
trap release_lock EXIT INT TERM

log "starting (once=${ONCE} interval=${POLL_INTERVAL}s timeout=${DISPATCH_TIMEOUT}s db=${PGDATABASE}@${PGHOST}:${PGPORT} zcode_cli=${ZCODE_CLI_DIR} state=${STATE_DIR})"

if [ "$ONCE" -eq 1 ]; then
  run_once_pass
  log "single pass complete (--once), exiting"
  exit 0
fi

while true; do
  run_once_pass
  sleep "$POLL_INTERVAL"
done
