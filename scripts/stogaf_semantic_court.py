#!/usr/bin/env python3
"""Execute the WD CS2 STOGAF RDF/SHACL/SPARQL semantic court."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from pyshacl import validate
from rdflib import Graph


DATA_FILES = [
    "stogaf-core.ttl",
    "stogaf-wd-instance.ttl",
    "ontology.ttl",
    "stogaf.ttl",
]


def load_graph(pack: Path) -> Graph:
    graph = Graph()
    for name in DATA_FILES:
        path = pack / name
        if not path.is_file():
            raise SystemExit(f"REFUSED:MISSING_SEMANTIC_FILE:{name}")
        graph.parse(path, format="turtle")
    return graph


def run_shacl(data: Graph, pack: Path) -> dict[str, object]:
    shapes = Graph()
    shapes_path = pack / "stogaf-shapes.ttl"
    shapes.parse(shapes_path, format="turtle")

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
        "--output",
        default="wd-cs2-stogaf-semantic-report.json",
        help="JSON report path",
    )
    args = parser.parse_args()

    pack = Path(args.pack)
    data = load_graph(pack)
    shacl = run_shacl(data, pack)
    gates = run_gates(data, pack)

    payload = {
        "schema": "STOGAF_SEMANTIC_COURT_V1",
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

    output = Path(args.output)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, sort_keys=True))

    if payload["standing"] != "ALIVE":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
