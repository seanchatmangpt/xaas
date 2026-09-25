#!/usr/bin/env python3
"""Execute the WD CS2 STOGAF RDF/SHACL/SPARQL semantic court."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from pyshacl import validate
from rdflib import Graph


SCHEMA = "STOGAF_SEMANTIC_COURT_V2"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DECK = ROOT / "docs" / "case-studies" / "wd-fa" / "presentation"

DATA_FILES = [
    "stogaf-core.ttl",
    "stogaf-wd-instance.ttl",
    "ontology.ttl",
    "stogaf.ttl",
    "case-study.ttl",
    "claims.ttl",
]
SHAPE_FILES = [
    "stogaf-shapes.ttl",
    "case-study-shapes.ttl",
]


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def input_files(pack: Path, deck: Path, extra: list[Path]) -> list[tuple[str, Path]]:
    """Every file the verdict depends on, keyed by a location-free name."""
    files: list[tuple[str, Path]] = []
    for name in DATA_FILES + SHAPE_FILES:
        path = pack / name
        if not path.is_file():
            raise SystemExit(f"REFUSED:MISSING_SEMANTIC_FILE:{name}")
        files.append((f"pack/{name}", path))
    if not deck.is_dir():
        raise SystemExit(f"REFUSED:MISSING_DECK:{deck}")
    deck_files = sorted(deck.glob("*.ttl"))
    if not deck_files:
        raise SystemExit(f"REFUSED:EMPTY_DECK:{deck}")
    files.extend((f"deck/{path.name}", path) for path in deck_files)
    files.extend((f"gates/{path.name}", path) for path in sorted((pack / "gates").glob("*.rq")))
    for path in extra:
        if not path.is_file():
            raise SystemExit(f"REFUSED:MISSING_EXTRA_FILE:{path}")
        files.append((f"extra/{path.name}", path))
    return files


def load_graph(pack: Path, deck: Path, extra: list[Path]) -> Graph:
    graph = Graph()
    for name in DATA_FILES:
        graph.parse(pack / name, format="turtle")
    for path in sorted(deck.glob("*.ttl")):
        graph.parse(path, format="turtle")
    for path in extra:
        graph.parse(path, format="turtle")
    return graph


def run_shacl(data: Graph, pack: Path) -> dict[str, object]:
    shapes = Graph()
    for name in SHAPE_FILES:
        shapes.parse(pack / name, format="turtle")

    conforms, results_graph, results_text = validate(
        data_graph=data,
        shacl_graph=shapes,
        inference="rdfs",
        abort_on_first=False,
        allow_infos=False,
        allow_warnings=False,
        meta_shacl=True,
        advanced=True,
        js=False,
        debug=False,
    )
    return {
        "conforms": bool(conforms),
        "results_triples": len(results_graph),
        "results_text": str(results_text),
    }


def run_gates(data: Graph, pack: Path) -> list[dict[str, object]]:
    reports: list[dict[str, object]] = []
    gates_dir = pack / "gates"

    for gate in sorted(gates_dir.glob("*.rq")):
        query = gate.read_text(encoding="utf-8")
        rows = list(data.query(query))
        reports.append(
            {
                "gate": gate.name,
                "refusal_rows": len(rows),
                "rows": [[str(value) for value in row] for row in rows],
            }
        )

    return reports


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--pack",
        default="priv/packs/wd_cs2_pack",
        help="Path to the WD CS2 semantic pack",
    )
    parser.add_argument(
        "--deck",
        default=str(DEFAULT_DECK),
        help="Directory of presentation *.ttl loaded into the same graph",
    )
    parser.add_argument(
        "--extra",
        action="append",
        default=[],
        help="Additional Turtle data file (negative controls); repeatable",
    )
    parser.add_argument(
        "--output",
        default="wd-cs2-stogaf-semantic-report.json",
        help="JSON report path",
    )
    args = parser.parse_args()

    pack = Path(args.pack)
    deck = Path(args.deck)
    extra = [Path(item) for item in args.extra]
    inputs = input_files(pack, deck, extra)
    data = load_graph(pack, deck, extra)
    shacl = run_shacl(data, pack)
    gates = run_gates(data, pack)

    payload = {
        "schema": SCHEMA,
        "inputs_sha256": {name: _sha256(path) for name, path in inputs},
        "evidence_ceiling": "REPO_LOCAL_FIXTURE",
        "data_triples": len(data),
        "shacl": shacl,
        "gates": gates,
        "gate_count": len(gates),
        "refusal_rows": sum(int(item["refusal_rows"]) for item in gates),
    }
    payload["standing"] = (
        "ALIVE"
        if shacl["conforms"] and payload["gate_count"] > 0 and payload["refusal_rows"] == 0
        else "REFUSED"
    )
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    payload["report_sha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    output = Path(args.output)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, sort_keys=True))

    if payload["standing"] != "ALIVE":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
