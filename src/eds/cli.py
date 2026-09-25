"""eds CLI: create/validate ERC records, validate receipts, compute program
metrics over a registry directory. Thin argparse wrapper — all real logic
lives in erc.py / receipt.py / metrics.py so it's independently unit-testable
without shelling out."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from eds.erc import ERC, ERCValidationError
from eds.lifecycle import IllegalStateTransition, advance
from eds.receipt import Receipt
from eds.metrics import compute_snapshot, load_corpus
from eds.registry_sweep import format_report, sweep_registry
from eds.states import EvidenceState
from eds.verify import DictSubsetVerifier


def cmd_erc_validate(args: argparse.Namespace) -> int:
    exit_code = 0
    for path_str in args.paths:
        path = Path(path_str)
        try:
            erc = ERC.read(path)
        except Exception as e:
            print(f"FAIL {path}: could not parse — {e}")
            exit_code = 1
            continue
        problems = erc.validate()
        if problems:
            print(f"FAIL {path}:")
            for p in problems:
                print(f"  - {p}")
            exit_code = 1
        else:
            print(f"OK   {path} [{erc.evidence_state.value}]")
    return exit_code


def cmd_erc_new(args: argparse.Namespace) -> int:
    erc = ERC(
        id=args.id,
        hypothesis=args.hypothesis,
        artifact_reference=args.artifact,
        evidence_state=EvidenceState(args.state),
        falsifier=args.falsifier or "",
        no_falsifier=args.no_falsifier,
        evidence=args.evidence or "",
        verification=args.verification or "",
        source_revision=args.source_revision or "",
    )
    problems = erc.validate()
    out_path = Path(args.out)
    erc.write(out_path)
    if problems:
        print(f"WROTE {out_path} WITH VIOLATIONS:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"WROTE {out_path} [{erc.evidence_state.value}]")
    return 0


def cmd_erc_advance(args: argparse.Namespace) -> int:
    """Real lifecycle.advance() wiring: load an ERC record from disk, call
    the real transition-graph enforcement in lifecycle.py, write the
    resulting record back (in place, or to --out), and report the real
    resulting state or the real IllegalStateTransition error. No bookkeeping
    shortcut — this is the actual advance() call, not a status-field write."""
    path = Path(args.path)
    try:
        erc = ERC.read(path)
    except Exception as e:
        print(f"FAIL {path}: could not parse — {e}")
        return 1

    target = EvidenceState(args.to)

    expected: Any = None
    observed: Any = None
    verifier = None
    if args.expected is not None:
        expected = json.loads(args.expected)
    if args.observed is not None:
        observed = json.loads(args.observed)
    if target == EvidenceState.VERIFIED:
        # ERC records don't carry a serialized Falsifier/Verifier object —
        # only free text (charter §7/§9 fields). The real, callable judge
        # this record specifies via --expected/--observed is DictSubsetVerifier,
        # the same independent-judgment default verify.py ships.
        verifier = DictSubsetVerifier()

    try:
        new_erc = advance(
            erc,
            target,
            evidence=args.evidence or "",
            verifier=verifier,
            expected=expected,
            observed=observed,
        )
    except IllegalStateTransition as e:
        print(f"ILLEGAL {path}: {e}")
        return 1

    out_path = Path(args.out) if args.out else path
    new_erc.write(out_path)
    print(f"ADVANCED {path} -> {out_path} [{new_erc.evidence_state.value}]")
    return 0


def cmd_receipt_verify(args: argparse.Namespace) -> int:
    exit_code = 0
    for path_str in args.paths:
        path = Path(path_str)
        try:
            Receipt.read(path)
        except Exception as e:
            print(f"FAIL {path}: {e}")
            exit_code = 1
            continue
        print(f"OK   {path}")
    return exit_code


def cmd_metrics(args: argparse.Namespace) -> int:
    records, parse_failures = load_corpus(Path(args.registry))
    snapshot = compute_snapshot(records, parse_failures)
    if args.json:
        payload = dict(snapshot.__dict__)
        payload["parse_failures"] = [vars(f) for f in snapshot.parse_failures]
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"total claims:            {snapshot.total_claims}")
        print(f"parse failures:          {len(snapshot.parse_failures)}")
        print(f"executable claim ratio:  {snapshot.executable_claim_ratio}")
        print(f"reproduction ratio:      {snapshot.reproduction_ratio}")
        print(f"falsifier coverage:      {snapshot.falsifier_coverage}")
        print(f"receipt coverage:        {snapshot.receipt_coverage}")
        print("state counts:")
        for state, count in sorted(snapshot.state_counts.items()):
            print(f"  {state:<14} {count}")
        if snapshot.parse_failures:
            print("parse failures:")
            for f in snapshot.parse_failures:
                print(f"  {f.path}: {f.error}")
    return 1 if snapshot.parse_failures else 0


def cmd_registry_sweep(args: argparse.Namespace) -> int:
    """Conservative, read-only summary of a registry directory: real
    ERC.read() over every *.json file found, state counts, and which
    records have non-empty evidence but haven't been advanced past their
    current tier. Never calls lifecycle.advance() and never rewrites a
    file — see registry_sweep.py's module docstring for why."""
    report = sweep_registry(Path(args.registry))
    if args.json:
        print(json.dumps(report.to_dict(), indent=2, sort_keys=True))
    else:
        print(format_report(report))
    return 1 if report.failures else 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="eds", description="Executable Design Science tooling")
    sub = p.add_subparsers(dest="command", required=True)

    p_new = sub.add_parser("erc-new", help="create a new ERC record")
    p_new.add_argument("--id", required=True)
    p_new.add_argument("--hypothesis", required=True)
    p_new.add_argument("--artifact", required=True)
    p_new.add_argument("--state", required=True, choices=[s.value for s in EvidenceState])
    p_new.add_argument("--falsifier", default="")
    p_new.add_argument("--no-falsifier", action="store_true")
    p_new.add_argument("--evidence", default="")
    p_new.add_argument("--verification", default="")
    p_new.add_argument("--source-revision", default="")
    p_new.add_argument("--out", required=True)
    p_new.set_defaults(func=cmd_erc_new)

    p_validate = sub.add_parser("erc-validate", help="validate ERC record(s) against charter invariants")
    p_validate.add_argument("paths", nargs="+")
    p_validate.set_defaults(func=cmd_erc_validate)

    p_advance = sub.add_parser(
        "erc-advance", help="advance an ERC record's evidence_state via lifecycle.advance()"
    )
    p_advance.add_argument("path", help="path to the ERC JSON record")
    p_advance.add_argument("--to", required=True, choices=[s.value for s in EvidenceState])
    p_advance.add_argument("--evidence", default="")
    p_advance.add_argument("--expected", default=None, help="JSON value, required to reach VERIFIED")
    p_advance.add_argument("--observed", default=None, help="JSON value, required to reach VERIFIED")
    p_advance.add_argument("--out", default=None, help="write to this path instead of overwriting in place")
    p_advance.set_defaults(func=cmd_erc_advance)

    p_receipt = sub.add_parser("receipt-verify", help="verify receipt digest(s)")
    p_receipt.add_argument("paths", nargs="+")
    p_receipt.set_defaults(func=cmd_receipt_verify)

    p_metrics = sub.add_parser("metrics", help="compute charter §21 program metrics over a registry")
    p_metrics.add_argument("registry")
    p_metrics.add_argument("--json", action="store_true")
    p_metrics.set_defaults(func=cmd_metrics)

    p_sweep = sub.add_parser(
        "registry-sweep",
        help="conservative, read-only summary of a registry directory of ERC records",
    )
    p_sweep.add_argument("registry")
    p_sweep.add_argument("--json", action="store_true")
    p_sweep.set_defaults(func=cmd_registry_sweep)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
