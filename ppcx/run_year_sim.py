#!/usr/bin/env python3
"""CLI entrypoint: runs the full simulated EDS research year and writes
real ERC/Receipt/OCEL/summary artifacts to disk under output/.

Usage: python3 run_year_sim.py [--seed N] [--out DIR]
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from eds.receipt import Receipt

from ppcx.sim.eds_bridge import write_cycle_result
from ppcx.sim.ocel_bridge import build_ocel_log
from ppcx.sim.year_driver import EDS_YEAR_SEED, TOTAL_CYCLES, run_year


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the ppcx simulated EDS research year.")
    parser.add_argument("--seed", type=int, default=EDS_YEAR_SEED)
    parser.add_argument("--out", type=Path, default=Path(__file__).parent / "output")
    args = parser.parse_args()

    out_dir: Path = args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    results = run_year(master_seed=args.seed, total_cycles=TOTAL_CYCLES)

    for result in results:
        erc_path, receipt_path = write_cycle_result(result, out_dir)
        print(
            f"cycle {result.cycle_no:03d} {result.cycle_date.isoformat()} "
            f"historical={result.historical} -> {result.erc.evidence_state.value}"
        )

    ocel_log = build_ocel_log(results)
    reports_dir = out_dir / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    ocel_path = reports_dir / "eds-year-2026-2027.ocel.json"
    ocel_path.write_text(json.dumps(ocel_log, indent=2, sort_keys=True) + "\n")

    state_counts = Counter(r.erc.evidence_state.value for r in results)
    falsifier_triggers = sum(
        1
        for r in results
        if r.erc.evidence_state.value == "FALSIFIED" and "falsify-check" in {d.action for d in r.trace.draws}
        and any(d.action == "falsify-check" and d.outcome == "falsified" for d in r.trace.draws)
    )
    summary = {
        "seed": args.seed,
        "total_cycles": len(results),
        "historical_cycles": sum(1 for r in results if r.historical),
        "simulated_cycles": sum(1 for r in results if not r.historical),
        "evidence_state_counts": dict(sorted(state_counts.items())),
        "falsify_check_falsifier_triggers": falsifier_triggers,
    }
    summary_path = reports_dir / "eds-year-summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    # Re-verify every written receipt's digest for real before reporting done.
    for r in results:
        receipt_path = out_dir / "receipts" / f"cycle-{r.cycle_no:03d}.json"
        Receipt.read(receipt_path)

    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
