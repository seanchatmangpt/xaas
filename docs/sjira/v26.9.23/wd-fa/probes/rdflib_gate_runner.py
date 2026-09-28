#!/usr/bin/env python3
"""rdflib SPARQL runner for the ggen-marketplace semantic gate witness court.

The court (packs/semantic-gate-witness-court-pack, rendered by `ggen sync`)
proves gate <-> witness coverage itself and delegates gate semantics to a
consumer-supplied runner (its README: "an optional runner delegates gate
semantics without coupling the pack to a SPARQL engine"). This is that
runner for the wd-failure-analysis-pack (ggen-marketplace PR 474):

    rdflib_gate_runner.py <gate.rq> <witness.ttl> <pass|fail>

A gate is a SELECT whose rows are violations. `pass` is observed when the
gate yields zero rows over the witness graph; `fail` when it yields at least
one. Exit 0 only when the requested expectation is observed, 1 when it is
not, 2 on a usage or parse error. The witness is evaluated alone (the court's
exact-stem contract: one gate, one witness file). No LLM, no network.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[2] not in ("pass", "fail"):
        sys.stderr.write("usage: rdflib_gate_runner.py <gate.rq> <witness.ttl> <pass|fail>\n")
        return 2
    from rdflib import Graph

    gate, witness, expectation = Path(argv[0]), Path(argv[1]), argv[2]
    graph = Graph()
    try:
        graph.parse(witness.as_posix(), format="turtle")
        rows = list(graph.query(gate.read_text(encoding="utf-8")))
    except Exception as exc:  # rdflib raises several parser/evaluation exception types
        sys.stderr.write(f"{type(exc).__name__}: {exc}\n")
        return 2
    observed = "pass" if not rows else "fail"
    sys.stdout.write(
        json.dumps(
            {"expectation": expectation, "observed": observed, "rows": len(rows)},
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    )
    return 0 if observed == expectation else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
