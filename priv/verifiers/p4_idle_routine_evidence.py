#!/usr/bin/env python3
"""Mechanical evidence collector for the P4 Claude-routine deletion falsifier.

    python3 p4_idle_routine_evidence.py [--window-hours 24] [--min-epochs 3]
                                        [--until ISO_UTC] [--json]
                                        [--host H] [--port P] [--user U]
                                        [--db D] [--password PW]

Judges the precondition of docs/jira/v26.9.17/p4-claude-routine-deletion.md
(the c4 crown falsifier, docs/ultracode/c4-architecture.md):
Remove(ClaudeCode routine) => Behavior(Ultracode) = Unchanged. The routine
(trigger trig_01X4MaMBcr9DuFhVVZjJuLbQ) may be deleted only after >=24h of
IDLE-routine evidence. This script reads xaas_dev (read-only psql, no app
boot) and reports, for one window (default: trailing 24h against the
DATABASE clock, not the host clock -- the DB is the evidence plane):

  * epoch completions        -- ultracode_epochs.state = 'completed' with
                                completed_at in the window, joined to a
                                receipt whose evidence carries the
                                'head_verified' court key (the AliveRequiresCourt
                                law: evidence["head_verified"] == true);
  * unverified completions   -- completed epochs with NO such receipt
                                (fail-closed: these block PASS);
  * receipts sealed          -- ultracode_receipts rows sealed in the
                                window (the loop's own ledger writes -- the
                                continuity PROGRESS.md appends used to be),
                                broken down by outcome class (standing vs
                                the non-standing :heartbeat);
  * missed-epoch reaps       -- ultracode_epochs.state = 'missed' with
                                terminal_at in the window: continuity kept
                                by the loop's own missed-epoch detection,
                                not by a human.

Verdict (fail-closed): PASS iff verified_completions >= --min-epochs
(default 3, the P4 ">=3 epochs / 24h with receipts" bar) AND
unverified_completions == 0. Prints one verdict line

    P4-EVIDENCE: PASS|FAIL (<numbers>)

plus the full numbers (and a JSON document with --json, schemaVersion
"p4-idle-evidence/1"). Exit codes: 0 = PASS, 1 = FAIL, 2 = could not
collect evidence (connection failure, bad arguments) -- a collector that
cannot see is never a PASS.

This script NEVER touches the routine itself. The deletion is the
OPERATOR's two acts: pause the trigger, then delete it after the evidence
window passes. Never delete early (P4 invariant: deleting early converts
safety into an experiment). 並 laws apply to any standing cadence feeding
this window (<=16 heavyweight in-flight, top-up only, [1302] storm
protocol).

Like its siblings (aps/eds/nounverb/spr_backlog.py): python3 + psql only,
no Elixir, no app boot, no dependencies beyond the stdlib.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any

SCHEMA_VERSION = "p4-idle-evidence/1"

# The two receipt families (Xaas.Ultracode.Receipt moduledoc): standing
# claims vs the non-standing Run-tick liveness record.
STANDING_OUTCOMES = (
    "alive",
    "partial_alive",
    "blocked",
    "build_broken",
    "unsupported",
    "refused",
)


def utc_naive(text: str) -> str:
    """Validate an ISO-8601 instant and return a naive-UTC SQL literal body.

    The DB stores `timestamp without time zone` in UTC (AshPostgres
    convention: `now() AT TIME ZONE 'utc'`), so any supplied boundary is
    normalized to naive UTC before it ever touches SQL.
    """
    cleaned = text.strip()
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(cleaned)
    except ValueError:
        raise argparse.ArgumentTypeError(f"not an ISO-8601 timestamp: {text!r}")
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed.isoformat(sep=" ")


def psql_query(args: argparse.Namespace, sql: str) -> str:
    """Run one read-only psql statement and return its raw stdout."""
    env = dict(os.environ)
    env["PGPASSWORD"] = args.password
    cmd = [
        "psql",
        "-h", args.host,
        "-p", str(args.port),
        "-U", args.user,
        "-d", args.db,
        "--no-psqlrc",
        "-v", "ON_ERROR_STOP=1",
        "-At",  # unaligned, tuples-only: one clean value per line
        "-c", sql,
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=env)
    except (OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError(f"psql failed to run: {exc}") from exc
    if proc.returncode != 0:
        raise RuntimeError(
            f"psql exited {proc.returncode}: {proc.stderr.strip() or 'no stderr'}"
        )
    return proc.stdout.strip()


def collect(args: argparse.Namespace) -> dict[str, Any]:
    """Query the evidence plane once and return the metrics document."""
    if args.until:
        until_sql = f"'{utc_naive(args.until)}'::timestamp"
        until_display = utc_naive(args.until)
        db_now = until_display
    else:
        until_display = psql_query(args, "SELECT (now() at time zone 'utc')::text")
        until_sql = "(now() at time zone 'utc')"
        db_now = until_display

    hours = args.window_hours  # argparse type=int, already validated
    sql = f"""
    WITH win AS (
      SELECT ({until_sql} - make_interval(hours => {hours})) AS since,
             {until_sql} AS until
    )
    SELECT json_build_object(
      'db_now', (SELECT until::text FROM win),
      'window_since', (SELECT since::text FROM win),
      'completions', (
        SELECT count(*) FROM ultracode_epochs e, win
        WHERE e.state = 'completed'
          AND e.completed_at >= win.since AND e.completed_at < win.until),
      'verified_completions', (
        SELECT count(DISTINCT e.id)
        FROM ultracode_epochs e
        JOIN ultracode_receipts r ON r.epoch_id = e.id, win
        WHERE e.state = 'completed'
          AND e.completed_at >= win.since AND e.completed_at < win.until
          AND r.evidence ? 'head_verified'),
      'reaps', (
        SELECT count(*) FROM ultracode_epochs e, win
        WHERE e.state = 'missed'
          AND e.terminal_at >= win.since AND e.terminal_at < win.until),
      'failures', (
        SELECT count(*) FROM ultracode_epochs e, win
        WHERE e.state = 'failed'
          AND e.terminal_at >= win.since AND e.terminal_at < win.until),
      'in_flight', (
        SELECT count(*) FROM ultracode_epochs e
        WHERE e.state IN ('expected', 'running')),
      'receipts_sealed', (
        SELECT count(*) FROM ultracode_receipts r, win
        WHERE r.sealed_at >= win.since AND r.sealed_at < win.until),
      'receipts_by_outcome', (
        SELECT COALESCE(json_object_agg(outcome, n), '{{}}'::json)
        FROM (SELECT r.outcome, count(*) AS n
              FROM ultracode_receipts r, win
              WHERE r.sealed_at >= win.since AND r.sealed_at < win.until
              GROUP BY r.outcome) o),
      'standing_receipts', (
        SELECT count(*) FROM ultracode_receipts r, win
        WHERE r.sealed_at >= win.since AND r.sealed_at < win.until
          AND r.outcome = ANY(ARRAY[{", ".join(repr(o) for o in STANDING_OUTCOMES)}])),
      'heartbeat_receipts', (
        SELECT count(*) FROM ultracode_receipts r, win
        WHERE r.sealed_at >= win.since AND r.sealed_at < win.until
          AND r.outcome = 'heartbeat')
    )::text;
    """
    raw = psql_query(args, sql)
    try:
        metrics = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"psql returned non-JSON metrics: {raw[:200]!r}") from exc
    metrics["schemaVersion"] = SCHEMA_VERSION
    metrics["window_hours"] = hours
    metrics["db"] = args.db
    metrics["min_epochs"] = args.min_epochs
    return metrics


def judge(metrics: dict[str, Any]) -> tuple[bool, list[str]]:
    """Fail-closed verdict: >=min_epochs court-verified completions, zero unverified."""
    completions = int(metrics["completions"])
    verified = int(metrics["verified_completions"])
    unverified = completions - verified
    reasons = []
    if verified < metrics["min_epochs"]:
        reasons.append(
            f"verified completions {verified} < required {metrics['min_epochs']}"
        )
    if unverified > 0:
        reasons.append(
            f"{unverified} completion(s) in window lack a head_verified court receipt"
        )
    return (not reasons), reasons


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--window-hours", type=int, default=24,
                        help="evidence window length in hours (default 24)")
    parser.add_argument("--min-epochs", type=int, default=3,
                        help="required court-verified completions (P4: 3)")
    parser.add_argument("--until", type=utc_naive, default=None, metavar="ISO_UTC",
                        help="window end (naive/local ISO UTC); default: DB now()")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--db", default="xaas_dev")
    parser.add_argument("--password", default="postgres")
    parser.add_argument("--json", action="store_true",
                        help="also print the full metrics JSON document")
    args = parser.parse_args()

    if args.window_hours < 1:
        parser.error("--window-hours must be >= 1")
    if args.min_epochs < 1:
        parser.error("--min-epochs must be >= 1")

    try:
        metrics = collect(args)
    except RuntimeError as exc:
        print(f"P4-EVIDENCE: ERROR ({exc})", file=sys.stderr)
        return 2

    passed, reasons = judge(metrics)
    verdict = "PASS" if passed else "FAIL"

    print(f"P4 idle-routine evidence window: {metrics['window_since']} .. {metrics['db_now']} "
          f"({metrics['window_hours']}h, db={metrics['db']})")
    print(f"  epoch completions (state=completed): {metrics['completions']}")
    print(f"  completions with head_verified receipt (court): {metrics['verified_completions']}")
    print(f"  completions WITHOUT court receipt: {metrics['completions'] - metrics['verified_completions']}")
    print(f"  receipts sealed (loop ledger writes): {metrics['receipts_sealed']} "
          f"(standing={metrics['standing_receipts']}, heartbeat={metrics['heartbeat_receipts']})")
    print(f"  receipts by outcome: {json.dumps(metrics['receipts_by_outcome'], sort_keys=True)}")
    print(f"  missed-epoch reaps (continuity by the loop): {metrics['reaps']}")
    print(f"  failed epochs in window: {metrics['failures']}")
    print(f"  epochs in flight now (expected|running): {metrics['in_flight']}")
    if not passed:
        for reason in reasons:
            print(f"  FAIL reason: {reason}")
    print(
        f"P4-EVIDENCE: {verdict} "
        f"(verified={metrics['verified_completions']}/{metrics['completions']} completions "
        f">= {metrics['min_epochs']}, receipts={metrics['receipts_sealed']}, "
        f"reaps={metrics['reaps']}, window={metrics['window_hours']}h)"
    )
    if args.json:
        print(json.dumps(metrics, indent=2, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
