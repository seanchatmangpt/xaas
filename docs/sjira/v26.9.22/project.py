#!/usr/bin/env python3
"""Project docs/sjira/v26.9.22/work-orders.ttl (the source) into its projections.

  wo.json        list of work-order maps in the field set
                 GgenIgniter.SemanticJira.admit_work_order/1 admits (admit.exs input)
  index.json     top-level array, v26.9.21 index shape:
                 {id, path, standing, repository, dependencies}
  jira/<ID>.md   one Jira-shaped ticket per work order (JSON front matter = the
                 wo.json entry), a disposable projection

Standing is projected verbatim from sj:standing in the graph (UNKNOWN for every
order at authoring). Observed standing belongs to the TransitionLog
(GGEN_IGNITER-26922-06/07); a projection is never edited to carry it.

UNSUPPORTED(generator-capability): this script is hand-written consumer code,
pending GGEN_IGNITER-26922-08 (a TTL->work-order loader in semantic-jira-pack).
See HANDWRITTEN.md.

Usage: python3 project.py [--check]
  --check  regenerate into memory and exit 1 if any committed projection differs.
Requires rdflib (7.x verified).
"""
import json
import os
import sys

import rdflib
from rdflib.namespace import DCTERMS, RDF, RDFS

HERE = os.path.dirname(os.path.abspath(__file__))
TTL = os.path.join(HERE, "work-orders.ttl")
SJ = rdflib.Namespace("https://ggen-igniter.dev/ontology/semantic-jira#")

RECEIPT_CLASS_ORDER = ["manufacture", "projection", "authority_preparation", "actuation",
                       "verification", "postcondition", "replay", "publication", "deployment"]
PROJECTION_ORDER = ["jira", "wbpr", "prd", "ard", "vision", "fond", "hddl", "sa2a",
                    "a2a_agent_card", "worker", "verification", "executive", "machine",
                    "receipt", "replay"]


def fail(msg):
    sys.stderr.write(f"project: {msg}\n")
    sys.exit(2)


def local(iri):
    s = str(iri)
    return s.split("#", 1)[1] if "#" in s else s


def one(g, s, p, required=True):
    vals = list(g.objects(s, p))
    if len(vals) != 1:
        if required or len(vals) > 1:
            fail(f"{local(s)}: expected exactly one {local(p) if '#' in str(p) else p}, got {len(vals)}")
        return None
    return str(vals[0])


def many(g, s, p):
    return sorted(g.objects(s, p), key=str)


def described(g, nodes):
    out = []
    for n in nodes:
        d = one(g, n, DCTERMS.description)
        out.append(d)
    return out


def project_work_order(g, s):
    ident = one(g, s, DCTERMS.identifier)
    deps = []
    for edge in many(g, s, SJ.dependsOn):
        up = one(g, edge, SJ.upstreamWorkOrder)
        up_id = one(g, rdflib.URIRef(up), DCTERMS.identifier)
        deps.append({"upstream": up_id, "type": one(g, edge, SJ.dependencyType)})
    deps.sort(key=lambda d: (d["upstream"], d["type"]))
    projections = [one(g, p, SJ.projectionType) for p in many(g, s, SJ.projection)]
    projections.sort(key=lambda t: PROJECTION_ORDER.index(t) if t in PROJECTION_ORDER else 99)
    classes = [str(c) for c in g.objects(s, SJ.requiresReceiptClass)]
    classes.sort(key=lambda c: RECEIPT_CLASS_ORDER.index(c) if c in RECEIPT_CLASS_ORDER else 99)
    action = one(g, s, SJ.nextAction)
    checkpoint = one(g, s, SJ.nextCheckpoint)
    return {
        "identity": ident,
        "title": one(g, s, DCTERMS.title),
        "description": one(g, s, DCTERMS.description),
        "subject": one(g, s, SJ.subject),
        "repository": one(g, s, SJ.repository),
        "base_sha": one(g, s, SJ.baseSha),
        "standing": one(g, s, SJ.standing),
        "evidence_ceiling": one(g, s, SJ.evidenceCeiling),
        "authority_ceiling": one(g, s, SJ.authorityCeiling),
        "authority_requirement": one(g, s, SJ.authorityRequirement),
        "promotion_rule": one(g, s, SJ.promotionRule),
        "replay_identity": one(g, s, SJ.replayIdentity),
        "required_courts": [local(c) for c in many(g, s, SJ.requiresCourt)],
        "required_evidence": [local(e) for e in many(g, s, SJ.requiresEvidence)],
        "acceptance": described(g, many(g, s, SJ.acceptance)),
        "falsifiers": described(g, many(g, s, SJ.falsifier)),
        "projections": projections,
        "dependencies": deps,
        "path_scope": sorted(str(p) for p in g.objects(s, SJ.pathScope)),
        "required_receipt_classes": classes,
        "next_action": one(g, rdflib.URIRef(action), DCTERMS.description),
        "next_checkpoint": local(checkpoint),
    }


def ticket(wo):
    lines = ["---", json.dumps(wo, indent=2, ensure_ascii=False), "---", "",
             f"# {wo['identity']}: {wo['title']}", "",
             f"- **Standing**: {wo['standing']} (projected from work-orders.ttl; observed standing comes from the TransitionLog)",
             f"- **Repository**: {wo['repository']} @ `{wo['base_sha'][:12]}` (release/v26.9.22)",
             f"- **Subject**: `{wo['subject']}`",
             f"- **Authority**: ceiling {wo['authority_ceiling']}, requirement {wo['authority_requirement']}",
             "", "## Description", wo["description"], "", "## Acceptance"]
    lines += [f"- [ ] {a}" for a in wo["acceptance"]]
    lines += ["", "## Falsifiers"] + [f"- {f}" for f in wo["falsifiers"]]
    lines += ["", "## Dependencies"]
    lines += [f"- {d['upstream']} ({d['type']})" for d in wo["dependencies"]] or ["- none"]
    lines += ["", "## Next action", wo["next_action"], "",
              "## Promotion rule", wo["promotion_rule"], ""]
    return "\n".join(lines)


def build():
    g = rdflib.Graph()
    g.parse(TTL, format="turtle")
    orders = [project_work_order(g, s) for s in g.subjects(RDF.type, SJ.WorkOrder)]
    orders.sort(key=lambda w: w["identity"])
    ids = [w["identity"] for w in orders]
    if len(set(ids)) != len(ids):
        fail("duplicate dcterms:identifier")
    files = {"wo.json": json.dumps(orders, indent=2, ensure_ascii=False) + "\n"}
    index = [{"id": w["identity"], "path": f"jira/{w['identity']}.md", "standing": w["standing"],
              "repository": w["repository"],
              "dependencies": [d["upstream"] for d in w["dependencies"]]} for w in orders]
    files["index.json"] = json.dumps(index, indent=2, ensure_ascii=False) + "\n"
    for w in orders:
        files[f"jira/{w['identity']}.md"] = ticket(w)
    return files, len(orders)


def main():
    check = "--check" in sys.argv[1:]
    files, n = build()
    if check:
        stale = []
        for rel, body in sorted(files.items()):
            p = os.path.join(HERE, rel)
            if not os.path.exists(p) or open(p, encoding="utf-8").read() != body:
                stale.append(rel)
        jira = os.path.join(HERE, "jira")
        extra = sorted(f"jira/{f}" for f in os.listdir(jira)) if os.path.isdir(jira) else []
        stale += [f"{e} (not projected)" for e in extra if e not in files]
        for s in stale:
            print(f"STALE {s}")
        print(f"checked {len(files)} projections of {n} work orders: {len(stale)} stale")
        sys.exit(1 if stale else 0)
    os.makedirs(os.path.join(HERE, "jira"), exist_ok=True)
    for rel, body in files.items():
        with open(os.path.join(HERE, rel), "w", encoding="utf-8") as f:
            f.write(body)
    print(f"projected {n} work orders -> wo.json, index.json, {len(files) - 2} jira tickets")


if __name__ == "__main__":
    main()
