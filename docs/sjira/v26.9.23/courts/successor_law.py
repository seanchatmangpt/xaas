#!/usr/bin/env python3
"""GC23-12 successor law (lane V23-H; PRD section 12, ARD sections 5.5, 24 M9).

Independent of the compiler (rdflib + the standard library only), over the
committed successor artifacts of docs/sjira/v26.9.23/successor/:

  L1 the successor goal graph holds no sj:WorkOrder, no sj:Receipt and no
     sj:receipt; its single root is v23:GC-26.9.24 (sj:successorOf
     v23:GC-26.9.23) with at least one gate;
  L2 docs/sjira/v26.9.23/goal.ttl names v23:GC-26.9.24 as the
     sj:successorCheckpoint of v23:GC-26.9.23;
  L3 the root pins the prose: sj:sourceSha256 = sha256(prose bytes) and
     dcterms:source = the prose path; the prose is headed
     "# DRAFT — awaiting operator acceptance" and has at most 60 lines;
  L4 admission invented nothing: the admitted propositions are exactly the
     emitted candidates, all bound to the prose digest;
  L5 every WorkOrder is compiler output: its IRI is <ns>WO-<first 16 hex of
     sha256(sj:subject)>, its sj:subject is an admitted required
     Postcondition/Invariant/Falsifier proposition, sj:checkpointOf equals
     that proposition's sj:requiredBy (the root or one of its gates), and
     required delta propositions and orders are 1:1;
  L6 every order carries the full tuple (subject, postcondition, capability =
     the single canonical sj:capabilityId, evidence ceiling and horizon,
     authority ceiling, consequence class, successor policy; exclusions
     0..n) and its stop-court tuple digest is recomputed here;
  L7 every order is sj:checkpointOf+ v23:GC-26.9.24 and none is
     sj:checkpointOf+ v23:GC-26.9.23 in goal.ttl + successor goal + orders;
  L8 predecessor inventory: the only orders goal.ttl itself places under
     v23:GC-26.9.24 are GC-26.9.23 lane orders (dcterms:identifier V23-*)
     typed sj:boundaryClass sj:Successor, none under a successor gate; they
     are listed, never counted as GC-26.9.24 delta;
  L9 the intake (mix xaas.successor): work.json rows are exactly the orders
     with the recomputed tuple digests, the frontier is non-empty, the first
     eligible order went through the descriptor (provider recipe) and its
     item is a typed UNSUPPORTED(provider_capability) or UNKNOWN successor
     item whose capability the XaaS registry does not serve, and every
     eligible order has a typed item.

Exit 0 and a summary per law; exit 1 with "REFUSED: GC23-12 L<n> <detail>"
on the first broken law. --successor-goal and --orders override the committed
files (the court's anti-vacuity mutations use them).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from rdflib import Graph, Literal, URIRef
from rdflib.namespace import RDF

SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"
DCT = "http://purl.org/dc/terms/"
HEADING = "# DRAFT — awaiting operator acceptance"
CAPABILITY = re.compile(r"^[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*$")
DELTA = {"Postcondition", "Invariant", "Falsifier"}
TYPED = re.compile(r"^(UNSUPPORTED\(provider_capability\)|UNKNOWN)$")


def sj(name: str) -> URIRef:
    return URIRef(SJ + name)


def dct(name: str) -> URIRef:
    return URIRef(DCT + name)


class Refused(Exception):
    pass


def law(ok: bool, number: int, detail: str) -> None:
    if not ok:
        raise Refused(f"L{number} {detail}")


def one(graph: Graph, subject, predicate, number: int, what: str):
    values = list(graph.objects(subject, predicate))
    law(len(values) == 1, number, f"{what}: {subject} has {len(values)} values of {predicate}")
    return values[0]


def digest(tuple_: dict) -> str:
    t = dict(tuple_)
    t["exclusions"] = sorted(t["exclusions"])
    blob = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return "sha256:" + hashlib.sha256(blob).hexdigest()


def closure(graph: Graph, node, top) -> bool:
    seen, frontier = set(), [node]
    while frontier:
        current = frontier.pop()
        for parent in graph.objects(current, sj("checkpointOf")):
            if parent == top:
                return True
            if parent not in seen:
                seen.add(parent)
                frontier.append(parent)
    return False


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--xaas", required=True, help="xaas checkout under judgement")
    p.add_argument("--successor-goal", help="override successor/goal.ttl")
    p.add_argument("--orders", help="override successor/compiled/orders.ttl")
    args = p.parse_args(argv)

    xaas = Path(args.xaas)
    base = xaas / "docs/sjira/v26.9.23"
    succ = base / "successor"
    prose_rel = "docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md"
    paths = {
        "goal": base / "goal.ttl",
        "successor_goal": Path(args.successor_goal) if args.successor_goal else succ / "goal.ttl",
        "candidates": succ / "candidates.ttl",
        "propositions": succ / "compiled/propositions.ttl",
        "orders": Path(args.orders) if args.orders else succ / "compiled/orders.ttl",
    }
    try:
        graphs = {name: Graph().parse(str(path), format="turtle") for name, path in paths.items()}
        prose = (xaas / prose_rel).read_bytes()
        intake = {n: json.loads((succ / "intake" / f"{n}.json").read_text("utf-8"))
                  for n in ("work", "frontier", "descriptor", "resolution")}
    except Exception as exc:  # noqa: BLE001 - any unreadable input refuses
        print(f"REFUSED: GC23-12 L0 unreadable successor input: {exc}")
        return 1

    try:
        summary = judge(graphs, prose, prose_rel, intake)
    except Refused as refused:
        print(f"REFUSED: GC23-12 {refused}")
        return 1
    for line in summary:
        print(line)
    return 0


def judge(graphs: dict, prose: bytes, prose_rel: str, intake: dict) -> list[str]:
    goal, sgoal = graphs["goal"], graphs["successor_goal"]
    cands, props, orders = graphs["candidates"], graphs["propositions"], graphs["orders"]
    root, pred = URIRef(V23 + "GC-26.9.24"), URIRef(V23 + "GC-26.9.23")
    out = []

    # L1
    smuggled = sorted(str(s) for s in sgoal.subjects(RDF.type, sj("WorkOrder")))
    law(not smuggled, 1, f"hand-authored WorkOrder in the successor goal graph: {smuggled}")
    law(not list(sgoal.subjects(RDF.type, sj("Receipt"))) and not list(sgoal.triples((None, sj("receipt"), None))),
        1, "the successor goal graph asserts a receipt")
    roots = {c for c in sgoal.subjects(RDF.type, sj("GoalCheckpoint"))
             if not list(sgoal.objects(c, sj("checkpointOf")))
             and list(sgoal.subjects(sj("checkpointOf"), c))}
    law(roots == {root}, 1, f"successor goal roots {sorted(map(str, roots))} != [{root}]")
    law((root, sj("successorOf"), pred) in sgoal, 1, "v23:GC-26.9.24 is not sj:successorOf v23:GC-26.9.23")
    gates = {g for g in sgoal.subjects(sj("checkpointOf"), root) if (g, RDF.type, sj("GoalCheckpoint")) in sgoal}
    law(len(gates) >= 1, 1, "v23:GC-26.9.24 has no gate")
    out.append(f"L1 successor goal: root GC-26.9.24 (successorOf GC-26.9.23), {len(gates)} gates, "
               f"0 WorkOrders, 0 receipts")

    # L2
    law((pred, sj("successorCheckpoint"), root) in goal, 2,
        "goal.ttl does not name v23:GC-26.9.24 as the successorCheckpoint of v23:GC-26.9.23")
    out.append("L2 goal.ttl: GC-26.9.23 sj:successorCheckpoint GC-26.9.24")

    # L3
    prose_sha = "sha256:" + hashlib.sha256(prose).hexdigest()
    law(str(one(sgoal, root, sj("sourceSha256"), 3, "root")) == prose_sha, 3,
        f"root sj:sourceSha256 does not pin the prose {prose_sha}")
    law(str(one(sgoal, root, dct("source"), 3, "root")) == prose_rel, 3, "root dcterms:source is not the prose path")
    text = prose.decode("utf-8")
    law(text.split("\n", 1)[0] == HEADING, 3, f"the prose is not headed {HEADING!r}")
    lines = text.count("\n") + (0 if text.endswith("\n") else 1)
    law(lines <= 60, 3, f"the prose has {lines} lines (> 60)")
    out.append(f"L3 prose {prose_rel} {prose_sha}: {lines} lines, headed DRAFT, pinned by the root")

    # L4
    cand_iris = set(cands.subjects(RDF.type, sj("Proposition")))
    prop_iris = set(props.subjects(RDF.type, sj("Proposition")))
    law(cand_iris == prop_iris, 4,
        f"admitted propositions differ from the candidates: +{len(prop_iris - cand_iris)} -{len(cand_iris - prop_iris)}")
    law(all(str(one(props, p, sj("sourceSha256"), 4, "proposition")) == prose_sha for p in prop_iris), 4,
        "an admitted proposition is not bound to the prose digest")
    out.append(f"L4 admission: {len(prop_iris)} propositions = {len(cand_iris)} emitted candidates, all bound to the prose")

    # L5
    ns = str(root).rsplit("#", 1)[0] + "#"
    work_orders = sorted(orders.subjects(RDF.type, sj("WorkOrder")), key=str)
    law(work_orders, 5, "the compiled successor projection holds no WorkOrder")
    required_delta = {p for p in prop_iris
                      if str(props.value(p, sj("propositionKind"))) in DELTA
                      and props.value(p, sj("requiredBy")) is not None}
    seen = {}
    for wo in work_orders:
        subject = str(one(orders, wo, sj("subject"), 5, "order"))
        expected = URIRef(ns + "WO-" + hashlib.sha256(subject.encode("utf-8")).hexdigest()[:16])
        law(wo == expected, 5, f"{wo} does not recompute from its subject (expected {expected})")
        law(URIRef(subject) in required_delta, 5, f"{wo}: {subject} is not an admitted required delta proposition")
        required_by = props.value(URIRef(subject), sj("requiredBy"))
        parents = set(orders.objects(wo, sj("checkpointOf")))
        law(parents == {required_by}, 5, f"{wo}: sj:checkpointOf {sorted(map(str, parents))} != sj:requiredBy {required_by}")
        law(required_by in gates | {root}, 5, f"{wo}: placed under {required_by}, outside GC-26.9.24 and its gates")
        seen[URIRef(subject)] = seen.get(URIRef(subject), 0) + 1
    law(set(seen) == required_delta and all(n == 1 for n in seen.values()), 5,
        "required delta propositions and orders are not 1:1")
    out.append(f"L5 compiler output: {len(work_orders)} WorkOrders = {len(required_delta)} required "
               f"Postcondition/Invariant/Falsifier propositions, each IRI = WO-sha256(subject)[:16]")

    # L6
    digests = {}
    for wo in work_orders:
        cap_node = one(orders, wo, sj("requiresCapability"), 6, "order")
        capability = str(one(orders, cap_node, sj("capabilityId"), 6, "capability"))
        law(bool(CAPABILITY.match(capability)), 6, f"{wo}: non-canonical capability {capability!r}")
        tuple_ = {
            "subject": str(one(orders, wo, sj("subject"), 6, "order")),
            "postcondition": str(one(orders, wo, sj("postcondition"), 6, "order")),
            "capability": capability,
            "evidence_ceiling": str(one(orders, wo, sj("evidenceCeiling"), 6, "order")),
            "authority_ceiling": str(one(orders, wo, sj("authorityCeiling"), 6, "order")),
            "consequence_class": str(one(orders, wo, sj("consequenceClass"), 6, "order")),
            "exclusions": [str(e) for e in orders.objects(wo, sj("exclusion"))],
        }
        one(orders, wo, sj("evidenceHorizon"), 6, "order")
        one(orders, wo, sj("successorPolicy"), 6, "order")
        identifier = str(one(orders, wo, dct("identifier"), 6, "order"))
        digests[identifier] = digest(tuple_)
    out.append(f"L6 full tuple on {len(digests)} orders; tuple digests recomputed (json.dumps)")

    # L7
    merged = Graph()
    for g in (goal, sgoal, orders):
        merged += g
    for wo in work_orders:
        law(closure(merged, wo, root), 7, f"{wo} is not sj:checkpointOf+ GC-26.9.24")
        law(not closure(merged, wo, pred), 7, f"{wo} is sj:checkpointOf+ GC-26.9.23")
    out.append(f"L7 placement: {len(work_orders)} orders under GC-26.9.24, 0 under GC-26.9.23")

    # L8
    inventory = []
    for wo in sorted(goal.subjects(RDF.type, sj("WorkOrder")), key=str):
        if not closure(goal, wo, root):
            continue
        ident = str(goal.value(wo, dct("identifier")))
        law(re.fullmatch(r"V23-[A-Z0-9]+", ident) is not None, 8,
            f"goal.ttl places {wo} ({ident}) under GC-26.9.24 and it is not a GC-26.9.23 lane order")
        law((wo, sj("boundaryClass"), sj("Successor")) in goal, 8, f"{ident} under GC-26.9.24 is not typed sj:Successor")
        law(not set(goal.objects(wo, sj("checkpointOf"))) & gates, 8, f"{ident} sits under a GC-26.9.24 gate")
        inventory.append(ident)
    out.append("L8 predecessor inventory (GC-26.9.23 lane orders typed Successor, not GC-26.9.24 delta): "
               + (", ".join(inventory) or "none"))

    # L9
    rows = {r["identity"]: r for r in intake["work"]["work_orders"]}
    law(set(rows) == set(digests), 9, f"work.json rows {sorted(rows)} != compiled orders {sorted(digests)}")
    for ident, row in rows.items():
        law(row.get("tuple_digest") == digests[ident], 9, f"work.json {ident} tuple_digest differs from the recompute")
    eligible = [e["identity"] for e in intake["frontier"]["eligible"]]
    law(eligible, 9, "the frontier over the successor orders is empty")
    law(set(eligible) <= set(rows), 9, "the frontier names an order outside the work graph")
    res = intake["resolution"]
    first = res["first"]
    law(first["order"] == eligible[0], 9, f"resolution.first {first['order']} is not the first eligible {eligible[0]}")
    law(bool(TYPED.match(first["standing"])), 9, f"first item standing {first['standing']!r} is not typed")
    if first["standing"].startswith("UNSUPPORTED"):
        law(first["reason"] == "provider_capability", 9, "UNSUPPORTED item without reason provider_capability")
        law(first["capability"] not in first.get("registered_capabilities", []), 9,
            "UNSUPPORTED(provider_capability) for a registered capability")
    law(first["tuple_digest"] == digests[first["order"]], 9, "first item tuple digest differs from the recompute")
    descriptor = intake["descriptor"]
    law(descriptor["provider"] == "recipe", 9, f"descriptor provider {descriptor['provider']!r} != recipe")
    law(descriptor["bridge"]["identity"] == first["order"], 9, "the descriptor is not the first eligible order's")
    items = {i["order"]: i for i in res["items"]}
    law(set(items) == set(eligible), 9, "resolution items do not cover the eligible orders")
    for ident, item in items.items():
        law(bool(TYPED.match(item["standing"])), 9, f"{ident}: item standing {item['standing']!r} is not typed")
        law(item["tuple_digest"] == digests[ident], 9, f"{ident}: item tuple digest differs from the recompute")
    tally = {}
    for item in items.values():
        tally[item["standing"]] = tally.get(item["standing"], 0) + 1
    out.append(f"L9 intake: frontier {len(eligible)} eligible; first {first['order']} ({first['capability']}) -> "
               f"descriptor provider recipe -> Route.resolve -> {first['standing']}; items {json.dumps(tally, sort_keys=True)}")
    return out


if __name__ == "__main__":
    sys.exit(main())
