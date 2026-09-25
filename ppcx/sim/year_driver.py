"""Builds all 52 weekly cycles of the simulated EDS research year.

Cycles 1-6 (Aug 1 - Sep 12, 2026) are historical=True and forced-positive,
grounding to the real, already-lived paper Sec.4 history. Cycles 7-52
(Sep 13, 2026 - Jul 31, 2027) are historical=False and go through the real
seeded Monte Carlo FOND sampling in sim/fond_engine.py.
"""

from __future__ import annotations

from datetime import date, timedelta

from ppcx.sim.eds_bridge import CycleResult, build_cycle_result
from ppcx.sim.fond_engine import force_positive_cycle, run_cycle

EDS_YEAR_SEED = 20260912
YEAR_START = date(2026, 8, 1)
TOTAL_CYCLES = 52
HISTORICAL_CYCLES = 6


def cycle_date(cycle_no: int) -> date:
    return YEAR_START + timedelta(weeks=cycle_no - 1)


def run_year(master_seed: int = EDS_YEAR_SEED, total_cycles: int = TOTAL_CYCLES) -> list[CycleResult]:
    results: list[CycleResult] = []
    for cycle_no in range(1, total_cycles + 1):
        historical = cycle_no <= HISTORICAL_CYCLES
        d = cycle_date(cycle_no)
        trace = force_positive_cycle() if historical else run_cycle(cycle_no, master_seed)
        result = build_cycle_result(cycle_no, d, historical, trace, master_seed)
        results.append(result)
    return results
