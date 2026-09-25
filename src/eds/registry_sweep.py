"""Loop-integration gap (README "Status"): nothing in the hourly Project-2
EDS-classification loop calls ``lifecycle.advance()`` against the ERC records
it deposits in ``/Users/sac/eds-registry/receipts/``. This module is the
conservative first bridge: a real, read-only sweep of a registry directory
that reports what is actually there — state counts, and which records carry
non-empty evidence text but have not been advanced past their current tier
(a candidate list for a human/agent to review before calling erc-advance).

Named gap closed this session (README "Status": "a real, honest finding
about the upstream loop's own output" — 4 real charter-violating records
found by ``tests/test_real_registry_corpus.py`` via a one-off ``ERC.validate()``
sweep, but never surfaced by the actual ``registry-sweep`` CLI command a
human/agent would run day to day). ``sweep_registry`` now also calls the
real ``ERC.validate()`` on every successfully-parsed record and reports any
non-empty violation list in ``charter_violations`` — the same real check,
now wired into the standing sweep instead of living only in a test file.

Named gap closed this session (README "Status": registry-sweep's own
recommendations were still not concrete — ``stalled_with_evidence`` said a
record COULD legally move forward but never said to WHICH state, forcing a
human/agent to re-derive ``lifecycle._CONFIRMING_PATH`` by hand before
running ``eds erc-advance --to ...``). Each ``SweepRecord`` now carries a
real ``suggested_next_state`` computed via the new
``lifecycle.next_confirming_state()`` — still purely advisory, never
auto-applied.

Deliberately conservative: this module never calls ``lifecycle.advance()``
and never rewrites a record. It cannot independently verify a record's
evidence text against a real falsifier/verifier without the record also
supplying one (ERC records carry only free-text falsifier/verification
fields, not serialized callables — see erc.py), so forcing an automatic
state change here would be an unverified self-report wearing a script's
name. Reporting a candidate list is the honest, executable-today action;
actually advancing a record stays a deliberate, reviewed call to
``eds erc-advance`` (or a future, separately-falsified auto-advance loop).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from eds.erc import ERC
from eds.lifecycle import _legal_targets, next_confirming_state
from eds.states import EvidenceState


@dataclass
class SweepRecord:
    """One real, successfully-parsed ERC record's sweep-relevant facts."""

    path: str
    id: str
    evidence_state: str
    has_evidence: bool
    advanceable: bool  # non-empty evidence AND a legal forward target exists
    suggested_next_state: str | None  # the one concrete confirming-path target,
    # e.g. "IMPLEMENTED" -> "EXECUTABLE"; never auto-applied, just named so a
    # human/agent reviewing `stalled_with_evidence` doesn't have to re-derive
    # the transition graph by hand before running `eds erc-advance --to ...`


@dataclass
class SweepFailure:
    """A file under the registry directory that could not be read as an ERC
    — reported, never silently skipped."""

    path: str
    error: str


@dataclass
class ViolationRecord:
    """A record that parsed fine but failed its own real ``ERC.validate()``
    internal-consistency check — e.g. a claimed ``falsifier`` text present
    together with ``no_falsifier=True``. Reported separately from parse
    ``failures`` because the record IS a well-formed ERC; it just contradicts
    itself."""

    path: str
    id: str
    violations: list[str]


@dataclass
class SweepReport:
    registry: str
    total_files: int
    state_counts: dict[str, int] = field(default_factory=dict)
    records: list[SweepRecord] = field(default_factory=list)
    failures: list[SweepFailure] = field(default_factory=list)
    anomalies: list[SweepFailure] = field(default_factory=list)
    charter_violations: list[ViolationRecord] = field(default_factory=list)

    @property
    def stalled_with_evidence(self) -> list[SweepRecord]:
        """Records with non-empty evidence that have not been advanced past
        their current tier (a legal forward target exists but evidence_state
        hasn't moved there) — the exact real candidates for a human/agent to
        run `eds erc-advance` against, never auto-advanced here."""
        return [r for r in self.records if r.advanceable]

    def to_dict(self) -> dict[str, Any]:
        return {
            "registry": self.registry,
            "total_files": self.total_files,
            "state_counts": self.state_counts,
            "records": [vars(r) for r in self.records],
            "failures": [vars(f) for f in self.failures],
            "anomalies": [vars(a) for a in self.anomalies],
            "stalled_with_evidence": [vars(r) for r in self.stalled_with_evidence],
            "charter_violations": [vars(v) for v in self.charter_violations],
        }


def sweep_registry(registry_dir: Path) -> SweepReport:
    """Walk ``registry_dir`` for ``*.json`` files, load each as a real
    ``ERC`` via ``ERC.read()``, and report real, observed facts only. A file
    that fails to parse as an ERC is recorded in ``failures``, never
    silently dropped from the count."""
    registry_dir = Path(registry_dir)
    paths = sorted(registry_dir.rglob("*.json")) if registry_dir.is_dir() else []

    report = SweepReport(registry=str(registry_dir), total_files=len(paths))
    counts: dict[str, int] = {}

    for path in paths:
        try:
            raw = json.loads(path.read_text())
            if isinstance(raw.get("evidence"), list):
                # A real, previously-crashing shape (an earlier agent pass
                # wrote evidence as a list of strings). ERC.from_dict()
                # coerces it into a real string so the record still parses
                # and reports correctly, but it's still worth counting as
                # an anomaly rather than silently treating it as clean.
                report.anomalies.append(
                    SweepFailure(
                        path=str(path),
                        error="evidence field was a list; coerced to a joined string",
                    )
                )
            erc = ERC.from_dict(raw)

            violations = erc.validate()
            if violations:
                report.charter_violations.append(
                    ViolationRecord(path=str(path), id=erc.id, violations=violations)
                )

            state_value = erc.evidence_state.value
            counts[state_value] = counts.get(state_value, 0) + 1

            has_evidence = bool(erc.evidence.strip())
            legal_forward = bool(_legal_targets(erc.evidence_state) - {
                EvidenceState.FALSIFIED,
                EvidenceState.BLOCKED,
                EvidenceState.UNSUPPORTED,
                EvidenceState.UNKNOWN,
            })
            next_state = next_confirming_state(erc.evidence_state)
            report.records.append(
                SweepRecord(
                    path=str(path),
                    id=erc.id,
                    evidence_state=state_value,
                    has_evidence=has_evidence,
                    advanceable=has_evidence and legal_forward,
                    suggested_next_state=next_state.value if next_state else None,
                )
            )
        except Exception as e:  # real parse/validation failure, reported not hidden
            report.failures.append(SweepFailure(path=str(path), error=str(e)))
            continue

    report.state_counts = counts
    return report


def format_report(report: SweepReport) -> str:
    lines = [
        f"registry:      {report.registry}",
        f"total files:   {report.total_files}",
        f"parsed ok:     {len(report.records)}",
        f"parse failures:{len(report.failures)}",
        f"parse anomalies:{len(report.anomalies)}",
        "state counts:",
    ]
    for state, count in sorted(report.state_counts.items()):
        lines.append(f"  {state:<14} {count}")
    stalled = report.stalled_with_evidence
    lines.append(f"stalled with evidence (candidates for erc-advance): {len(stalled)}")
    for r in stalled:
        suggestion = f" -> {r.suggested_next_state}" if r.suggested_next_state else ""
        lines.append(f"  {r.id:<30} [{r.evidence_state}]{suggestion} {r.path}")
    if report.failures:
        lines.append("parse failures:")
        for f in report.failures:
            lines.append(f"  {f.path}: {f.error}")
    if report.anomalies:
        lines.append("parse anomalies:")
        for a in report.anomalies:
            lines.append(f"  {a.path}: {a.error}")
    if report.charter_violations:
        lines.append(f"charter violations (real ERC.validate() failures): {len(report.charter_violations)}")
        for v in report.charter_violations:
            lines.append(f"  {v.id:<30} {v.path}: {'; '.join(v.violations)}")
    return "\n".join(lines)
