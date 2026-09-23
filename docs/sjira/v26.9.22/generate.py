#!/usr/bin/env python3
"""TTL-first generator for the v26.9.22 multi-repo Semantic Jira graph.

The source of truth is work-orders.ttl (sj: vocabulary). This script projects it:

  wo.json        full work-order maps, the WO_JSON input of admit.exs
  index.json     top-level array the consumer lanes read (id, path, standing,
                 repository, dependencies) — never clobbered by hand edits:
                 standing is a projected OBSERVATION, not a literal here
  jira/<id>.md   one ticket projection per order

Standing projection (the v26.9.21 defect fix — generate.py hard-coded standings
as literals and clobbered index.json, and lanes read index.json):
  1. transition-log.jsonl  — events {identity, seq, from, to, evidence}; the
     latest event per identity by seq wins (the same projection
     GgenIgniter.SemanticJira.project/2 performs over a TransitionLog).
  2. standing/<identity>.json — a recorded observation input {standing, ...}.
  3. otherwise "UNKNOWN" — the standing vocabulary's default, not a per-order
     literal.

Regeneration must be idempotent: committed projections always equal a fresh run
(the v26.9.21 cycle's tests assert exactly this).

Usage:  python3 generate.py [--check]
Env:    SJIRA_OUT  output dir (default: this script's directory)
        WO_JSON    where to write wo.json (default: <out>/wo.json)
Requires rdflib for the TTL parse.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("SJIRA_OUT", HERE)
WO_JSON = os.environ.get("WO_JSON", os.path.join(OUT, "wo.json"))
TTL = os.path.join(OUT, "work-orders.ttl")
TRANSITION_LOG = os.path.join(OUT, "transition-log.jsonl")
STANDING_DIR = os.environ.get("SJIRA_STANDING", os.path.join(OUT, "standing"))
JIRA_DIR = os.path.join(OUT, "jira")

STANDING_DEFAULT = "UNKNOWN"

COURTS_DEFAULT = ["compile", "tests", "chicago_no_mocks"]


def fail(msg):
    sys.stderr.write(f"generate: {msg}\n")
    sys.exit(1)


def parse_graph():
    try:
        import rdflib
    except ImportError:
        fail("rdflib is required to parse work-orders.ttl (pip install rdflib)")
    g = rdflib.Graph()
    g.parse(TTL, format="turtle")
    return g


def one(g, s, p):
    v = g.value(s, p)
    return None if v is None else str(v)


def project_standings():
    """Latest logged transition per identity, then standing-file inputs."""
    projected = {}
    if os.path.exists(TRANSITION_LOG):
        events = []
        with open(TRANSITION_LOG) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                e = json.loads(line)
                if not isinstance(e, dict) or "identity" not in e or "to" not in e:
                    fail(f"{TRANSITION_LOG}: event needs identity and to: {e}")
                events.append(e)
        latest = {}
        for e in sorted(events, key=lambda e: (e.get("seq", 0), json.dumps(e, sort_keys=True))):
            latest[e["identity"]] = e
        projected = {i: {"standing": e["to"], "evidence": e.get("evidence")} for i, e in latest.items()}

    if os.path.isdir(STANDING_DIR):
        for fn in sorted(os.listdir(STANDING_DIR)):
            if not fn.endswith(".json"):
                continue
            p = os.path.join(STANDING_DIR, fn)
            o = json.load(open(p))
            ident = fn[: -len(".json")]
            if ident in projected:
                fail(f"{p}: conflicts with a transition-log event for {ident}; reconcile one input")
            projected[ident] = {"standing": o["standing"], "evidence": o.get("standing_note")}
    return projected


def build_orders(g):
    import rdflib

    SJ = rdflib.Namespace("https://ggen-igniter.dev/ontology/semantic-jira#")
    DCT = rdflib.Namespace("http://purl.org/dc/terms/")
    RDF = rdflib.RDF
    standings = project_standings()

    orders = []
    for s in g.subjects(RDF.type, SJ.WorkOrder):
        ident = one(g, s, SJ.identity)
        if not ident:
            fail(f"{TTL}: a sj:WorkOrder has no sj:identity")
        deps = []
        for d in g.objects(s, SJ.dependency):
            deps.append(
                {
                    "upstream": str(g.value(d, SJ.upstream)),
                    "type": str(g.value(d, SJ.dependencyType)),
                }
            )

        def indexed(predicate, cls, text_prop=DCT.description):
            items = []
            for node in g.objects(s, predicate):
                if (node, RDF.type, cls) not in g:
                    continue
                idx = int(str(g.value(node, SJ.index) or 0))
                items.append((idx, str(g.value(node, text_prop) or "")))
            return [t for _, t in sorted(items)]

        acceptance = indexed(SJ.acceptanceItem, SJ.AcceptanceCriterion)
        falsifiers = indexed(SJ.falsifierItem, SJ.Falsifier)
        obs = standings.get(ident, {})
        wo = {
            "identity": ident,
            "title": one(g, s, DCT.title),
            "description": one(g, s, DCT.description),
            "subject": one(g, s, SJ.subject),
            "repository": one(g, s, SJ.repository),
            "base_sha": one(g, s, SJ.baseSha),
            "standing": obs.get("standing", STANDING_DEFAULT),
            "evidence_ceiling": one(g, s, SJ.evidenceCeiling),
            "promotion_rule": one(g, s, SJ.promotionRule),
            "replay_identity": one(g, s, SJ.replayIdentity),
            "required_courts": sorted(str(o) for o in g.objects(s, SJ.requiredCourt)),
            "required_evidence": sorted(str(o) for o in g.objects(s, SJ.requiredEvidence)),
            "acceptance": acceptance,
            "falsifiers": falsifiers,
            "projections": sorted(str(o) for o in g.objects(s, SJ.projection)),
            "dependencies": deps,
            "authority_requirement": one(g, s, SJ.authorityRequirement) or "NONE",
            "path_scope": sorted(str(o) for o in g.objects(s, SJ.pathScope)),
            "required_receipt_classes": ["manufacture", "verification"],
        }
        if obs.get("evidence"):
            wo["standing_evidence"] = obs["evidence"]
        orders.append((ident, wo))
    orders.sort(key=lambda p: p[0])
    return [w for _, w in orders]


def render_ticket(wo):
    deps = "".join(
        f"\n- **Requires receipt of**: {d['upstream']} ({d['type']})" for d in wo["dependencies"]
    )
    acc = "".join(f"- [ ] {a}\n" for a in wo["acceptance"])
    fal = "".join(f"- {f}\n" for f in wo["falsifiers"])
    ev = (
        f"\n- **Standing evidence**: {wo['standing_evidence']}"
        if wo.get("standing_evidence")
        else ""
    )
    return (
        "---\n"
        + json.dumps(
            {k: wo[k] for k in wo if k not in ("standing_evidence",)}, indent=2, sort_keys=True
        )
        + "\n---\n\n"
        + f"# {wo['identity']}: {wo['title']}\n\n"
        f"- **Standing**: {wo['standing']}{ev}\n"
        f"- **Repository**: {wo['repository']} @ `{wo['base_sha'][:7]}`\n"
        f"- **Authority requirement**: {wo['authority_requirement']}\n"
        f"{deps}\n\n## Description\n{wo['description']}\n\n"
        "## Definition of done\n" + acc
        + "\n## Falsifiers\n" + fal
    )


def main():
    check = "--check" in sys.argv
    g = parse_graph()
    orders = build_orders(g)
    if not orders:
        fail(f"{TTL}: no sj:WorkOrder individuals found")
    os.makedirs(JIRA_DIR, exist_ok=True)
    idx = []
    for wo in orders:
        path = f"jira/{wo['identity']}.md"
        body = render_ticket(wo)
        fp = os.path.join(OUT, path)
        if check:
            if not os.path.exists(fp) or open(fp).read() != body:
                fail(f"--check: {path} is not the projection of {TTL}")
        else:
            open(fp, "w").write(body)
        idx.append(
            {
                "id": wo["identity"],
                "path": path,
                "standing": wo["standing"],
                "repository": wo["repository"],
                "dependencies": [d["upstream"] for d in wo["dependencies"]],
            }
        )
    idx_body = json.dumps(idx, indent=2) + "\n"
    wo_body = json.dumps(orders, indent=2) + "\n"
    if check:
        if open(os.path.join(OUT, "index.json")).read() != idx_body:
            fail("--check: index.json is not the projection of work-orders.ttl")
        if open(WO_JSON).read() != wo_body:
            fail(f"--check: {WO_JSON} is not the projection of work-orders.ttl")
        print(f"check ok: {len(orders)} orders reproduce byte-identically")
        return
    open(os.path.join(OUT, "index.json"), "w").write(idx_body)
    open(WO_JSON, "w").write(wo_body)
    print(len(orders))


if __name__ == "__main__":
    main()
