#!/usr/bin/env python3
"""Deterministic provenance binding for prose-extracted candidate propositions.

v26.9.23 first mile (PRD PR-002, ARD §5.2-5.3, §17): an extractor (the only
permitted LLM edge) reads accepted prose and writes an extraction JSON list;
this script is the deterministic half that binds every candidate to the exact
UTF-8 byte span it came from and projects the list into PVOCAB Turtle
(DRIVER.md "Proposition vocabulary contract"). It never admits anything:
every candidate carries sj:candidateStanding "UNKNOWN"; admission is
ggen_igniter compile_prose (lane V23-C).

  emit  --source <md> --extract <json> --out <ttl> --source-path <repo-rel> --extracted-by <id>
  check --source <md> --candidates <ttl> [--require-gates N] [--extract <json>] [--summary <json>]

Extraction item: {kind, statement, quote, occurrence?, required_by?,
boundary_class, hints?}. `quote` must occur in the source; if it occurs more
than once, `occurrence` (1-based, in byte order) picks one. `required_by` is a
local name (or list) in the instance namespace, e.g. "GC23-5". `hints` keys:
postcondition, requiresCapability, evidenceHorizon, exclusion,
consequenceClass, successorPolicy (literal tuple hints) and acceptance,
falsifier (text carried as sj:AcceptanceCriterion / sj:Falsifier nodes with
dcterms:description, the pack's existing properties for those meanings).

`check --summary` writes a tally of the verified candidates (kinds, per-target
sj:requiredBy counts, not-required count) as sorted JSON, so a receipt copies
its numbers from the checked artifact instead of retyping them.

Exit codes: 0 all checks hold; 1 one or more refusals (each printed as
"REFUSED <subject>: <code>: <detail>"); 2 usage error. Output is a pure
function of (source bytes, extraction bytes, arguments): candidates are
sorted by (start, kind, end, iri) and the Turtle is written by this script,
not by an rdflib serializer. Standard library + rdflib only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
DCTERMS = "http://purl.org/dc/terms/"
RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
XSD_INTEGER = "http://www.w3.org/2001/XMLSchema#integer"
DEFAULT_NAMESPACE = "https://ggen-igniter.dev/sjira/v26.9.23#"
DEFAULT_PREFIX = "v23"
DEFAULT_GATE_PREFIX = "GC23-"

# ARD §5.2, in the order the prose lists them.
KINDS = (
    "Actor",
    "Object",
    "Role",
    "State",
    "Transition",
    "Capability",
    "Trigger",
    "Dependency",
    "Invariant",
    "Exclusion",
    "Evidence",
    "Authority",
    "Postcondition",
    "Falsifier",
    "Metric",
    "Successor",
)
BOUNDARY_CLASSES = ("Bootstrap", "FirstMile", "Core", "LastMile", "Successor")
LITERAL_HINTS = (
    "consequenceClass",
    "evidenceHorizon",
    "exclusion",
    "postcondition",
    "requiresCapability",
    "successorPolicy",
)
NODE_HINTS = {"acceptance": "AcceptanceCriterion", "falsifier": "Falsifier"}
ITEM_KEYS = {"kind", "statement", "quote", "occurrence", "required_by", "boundary_class", "hints"}
REQUIRED_ITEM_KEYS = {"kind", "statement", "quote", "boundary_class"}
LOCAL_NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_.\-]*[A-Za-z0-9_\-]$|^[A-Za-z]$")
PN_LOCAL_SAFE = re.compile(r"^[A-Za-z_][A-Za-z0-9_\-]*$")
SINGLE_PROPS = (
    "propositionKind",
    "statement",
    "sourceDocument",
    "sourceSha256",
    "sourceStart",
    "sourceEnd",
    "sourceText",
    "boundaryClass",
    "candidateStanding",
    "extractedBy",
)


class Refusals:
    def __init__(self) -> None:
        self.items: list[tuple[str, str, str]] = []

    def add(self, subject: str, code: str, detail: str) -> None:
        self.items.append((subject, code, detail))

    def __bool__(self) -> bool:
        return bool(self.items)

    def render(self) -> str:
        return "".join(f"REFUSED {s}: {c}: {d}\n" for s, c, d in self.items)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_digest(data: bytes) -> str:
    return "sha256:" + sha256_hex(data)


def candidate_local(source_sha: str, start: int, end: int, kind: str) -> str:
    return "P-" + sha256_hex(f"{source_sha}:{start}:{end}:{kind}".encode("utf-8"))[:16]


def turtle_string(value: str) -> str:
    out = []
    for ch in value:
        code = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif code < 0x20 or code == 0x7F:
            out.append("\\u%04X" % code)
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def short(text: str, width: int = 48) -> str:
    flat = text.replace("\n", "\\n")
    return flat if len(flat) <= width else flat[: width - 3] + "..."


def as_list(value: object) -> list | None:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(v, str) for v in value):
        return list(value)
    return None


def find_all(haystack: bytes, needle: bytes) -> list[int]:
    hits = []
    at = haystack.find(needle)
    while at != -1:
        hits.append(at)
        at = haystack.find(needle, at + 1)
    return hits


# ── emit ─────────────────────────────────────────────────────────────────────


def resolve_items(source: bytes, items: object, refusals: Refusals) -> list[dict]:
    """Validate extraction items and bind each quote to its unique byte span."""
    sha = source_digest(source)
    if not isinstance(items, list) or not items:
        refusals.add("extract", "extract_invalid", "extraction JSON must be a non-empty list")
        return []
    resolved: list[dict] = []
    seen: dict[str, int] = {}
    for index, item in enumerate(items):
        where = f"item[{index}]"
        if not isinstance(item, dict):
            refusals.add(where, "item_invalid", "item is not an object")
            continue
        where = f"item[{index}] {short(str(item.get('quote', '')))!r}"
        unknown = sorted(set(item) - ITEM_KEYS)
        missing = sorted(REQUIRED_ITEM_KEYS - set(item))
        if unknown:
            refusals.add(where, "item_unknown_key", ", ".join(unknown))
        if missing:
            refusals.add(where, "item_missing_key", ", ".join(missing))
        if unknown or missing:
            continue
        ok = True
        kind = item["kind"]
        if kind not in KINDS:
            refusals.add(where, "kind_invalid", f"{kind!r} is not an ARD §5.2 kind")
            ok = False
        boundary = item["boundary_class"]
        if boundary not in BOUNDARY_CLASSES:
            refusals.add(where, "boundary_class_invalid", f"{boundary!r}")
            ok = False
        statement = item["statement"]
        if not isinstance(statement, str) or not statement.strip() or "\n" in statement or "\r" in statement:
            refusals.add(where, "statement_invalid", "statement must be one non-empty line")
            ok = False
        quote = item["quote"]
        if not isinstance(quote, str) or not quote:
            refusals.add(where, "quote_invalid", "quote must be a non-empty string")
            continue
        occurrence = item.get("occurrence")
        if occurrence is not None and (
            isinstance(occurrence, bool) or not isinstance(occurrence, int) or occurrence < 1
        ):
            refusals.add(where, "occurrence_invalid", f"{occurrence!r} (1-based integer)")
            ok = False
        required = as_list(item.get("required_by", []))
        if required is None or any(not LOCAL_NAME.match(r) for r in required):
            refusals.add(where, "required_by_invalid", f"{item.get('required_by')!r}")
            ok = False
            required = []
        if len(set(required)) != len(required):
            refusals.add(where, "required_by_invalid", "duplicate gate")
            ok = False
        hints_in = item.get("hints", {})
        hints: dict[str, list[str]] = {}
        if not isinstance(hints_in, dict):
            refusals.add(where, "hints_invalid", "hints must be an object")
            ok = False
        else:
            for key in sorted(hints_in):
                values = as_list(hints_in[key])
                if key not in LITERAL_HINTS and key not in NODE_HINTS:
                    refusals.add(where, "hints_invalid", f"unknown hint {key!r}")
                    ok = False
                elif not values or any(not v.strip() for v in values):
                    refusals.add(where, "hints_invalid", f"hint {key!r} must be non-empty text")
                    ok = False
                else:
                    hints[key] = sorted(set(values))
        needle = quote.encode("utf-8")
        hits = find_all(source, needle)
        if not hits:
            refusals.add(where, "quote_not_found", "0 matches in the source bytes")
            continue
        if occurrence is None and len(hits) > 1:
            refusals.add(
                where,
                "quote_ambiguous",
                f"{len(hits)} matches at byte offsets {hits[:8]} and no occurrence index",
            )
            continue
        if occurrence is not None and isinstance(occurrence, int) and occurrence > len(hits):
            refusals.add(where, "occurrence_out_of_range", f"occurrence {occurrence} of {len(hits)} matches")
            continue
        if not ok:
            continue
        start = hits[(occurrence or 1) - 1]
        end = start + len(needle)
        local = candidate_local(sha, start, end, kind)
        if local in seen:
            refusals.add(where, "duplicate_candidate", f"same span and kind as item[{seen[local]}] ({local})")
            continue
        seen[local] = index
        resolved.append(
            {
                "local": local,
                "kind": kind,
                "statement": statement,
                "start": start,
                "end": end,
                "text": quote,
                "boundary": boundary,
                "required": sorted(required),
                "hints": hints,
            }
        )
    resolved.sort(key=lambda c: (c["start"], c["kind"], c["end"], c["local"]))
    return resolved


def term(prefix: str, namespace: str, local: str) -> str:
    if PN_LOCAL_SAFE.match(local):
        return f"{prefix}:{local}"
    return f"<{namespace}{local}>"


def render(
    candidates: list[dict],
    source: bytes,
    source_doc: str,
    extracted_by: str,
    extract_bytes: bytes,
    namespace: str,
    prefix: str,
) -> str:
    sha = source_digest(source)
    lines = [
        "# GENERATED by scripts/sjira/prose_spans.py emit; do not edit. Re-emit from the extraction JSON.",
        f"# source: {source_doc} {sha}",
        f"# extraction: sha256:{sha256_hex(extract_bytes)} ({len(candidates)} candidates, extractedBy {extracted_by})",
        '# Candidates only (sj:candidateStanding "UNKNOWN"); admission is a separate step (ARD §5.3-5.4).',
        "",
        f"@prefix dcterms: <{DCTERMS}> .",
        f"@prefix sj: <{SJ}> .",
        f"@prefix {prefix}: <{namespace}> .",
        "",
    ]
    for c in candidates:
        subject = term(prefix, namespace, c["local"])
        body = [
            f"sj:propositionKind {turtle_string(c['kind'])}",
            f"sj:statement {turtle_string(c['statement'])}",
            f"sj:sourceDocument {turtle_string(source_doc)}",
            f"sj:sourceSha256 {turtle_string(sha)}",
            f"sj:sourceStart {c['start']}",
            f"sj:sourceEnd {c['end']}",
            f"sj:sourceText {turtle_string(c['text'])}",
            f"sj:boundaryClass sj:{c['boundary']}",
        ]
        body += [f"sj:requiredBy {term(prefix, namespace, g)}" for g in c["required"]]
        children = []
        for key in sorted(c["hints"]):
            for n, value in enumerate(c["hints"][key], start=1):
                if key in NODE_HINTS:
                    child = f"{c['local']}-{key}-{n}"
                    body.append(f"sj:{key} {term(prefix, namespace, child)}")
                    children.append((child, NODE_HINTS[key], value))
                else:
                    body.append(f"sj:{key} {turtle_string(value)}")
        body += ['sj:candidateStanding "UNKNOWN"', f"sj:extractedBy {turtle_string(extracted_by)}"]
        lines.append(f"{subject} a sj:Proposition ;")
        lines += [f"    {b} ;" for b in body[:-1]]
        lines.append(f"    {body[-1]} .")
        lines.append("")
        for child, cls, value in children:
            lines.append(f"{term(prefix, namespace, child)} a sj:{cls} ;")
            lines.append(f"    dcterms:description {turtle_string(value)} .")
            lines.append("")
    return "\n".join(lines)


def project(
    source: bytes,
    extract_bytes: bytes,
    source_doc: str,
    extracted_by: str,
    namespace: str,
    prefix: str,
    refusals: Refusals,
) -> str | None:
    try:
        items = json.loads(extract_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        refusals.add("extract", "extract_invalid", str(exc))
        return None
    candidates = resolve_items(source, items, refusals)
    if refusals:
        return None
    return render(candidates, source, source_doc, extracted_by, extract_bytes, namespace, prefix)


def validate_arguments(source_doc: str, extracted_by: str, refusals: Refusals) -> None:
    if not source_doc or source_doc.startswith("/") or ".." in Path(source_doc).parts or "\n" in source_doc:
        refusals.add("arguments", "source_path_invalid", f"{source_doc!r} must be repo-relative")
    if not extracted_by.strip() or "\n" in extracted_by:
        refusals.add("arguments", "extracted_by_invalid", f"{extracted_by!r}")


def cmd_emit(args: argparse.Namespace) -> int:
    refusals = Refusals()
    source = Path(args.source).read_bytes()
    extract_bytes = Path(args.extract).read_bytes()
    validate_arguments(args.source_path, args.extracted_by, refusals)
    text = None
    if not refusals:
        text = project(
            source, extract_bytes, args.source_path, args.extracted_by, args.namespace, args.prefix, refusals
        )
    if text is not None:
        # Self-check: never write a projection that `check` would refuse.
        verify_turtle(text, source, args.source, args.namespace, refusals, "emitted")
    if refusals or text is None:
        sys.stdout.write(refusals.render())
        sys.stdout.write(f"EMIT REFUSED: {len(refusals.items)} refusal(s); {args.out} not written\n")
        return 1
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    tmp.write_bytes(text.encode("utf-8"))
    os.replace(tmp, out)
    count = text.count(" a sj:Proposition ;")
    sys.stdout.write(f"EMIT: {count} candidates -> {args.out} sha256:{sha256_hex(text.encode('utf-8'))}\n")
    return 0


# ── check ────────────────────────────────────────────────────────────────────


def verify_turtle(
    text: str,
    source: bytes,
    source_arg: str,
    namespace: str,
    refusals: Refusals,
    label: str,
) -> tuple[dict[str, list[str]], int, dict[str, tuple[str, list[str]]]]:
    """Re-verify every candidate against the source bytes.

    Returns (gate -> valid candidates, n, valid candidate -> (kind, sorted requiredBy targets)).
    """
    from rdflib import Graph, Literal, URIRef
    from rdflib.namespace import RDF

    graph = Graph()
    try:
        graph.parse(data=text, format="turtle")
    except Exception as exc:  # rdflib raises several parser exception types
        refusals.add(label, "candidates_unparseable", f"{type(exc).__name__}: {short(str(exc), 160)}")
        return {}, 0, {}

    def sj(name: str) -> URIRef:
        return URIRef(SJ + name)

    sha = source_digest(source)
    proposition = sj("Proposition")
    allowed = {URIRef(RDF_TYPE), sj("requiredBy")} | {sj(p) for p in SINGLE_PROPS}
    allowed |= {sj(h) for h in LITERAL_HINTS} | {sj(h) for h in NODE_HINTS}
    boundary_iris = {sj(b): b for b in BOUNDARY_CLASSES}
    subjects = sorted({s for s in graph.subjects(RDF.type, proposition)}, key=str)
    if not subjects:
        refusals.add(label, "no_candidates", "no sj:Proposition in the candidates graph")
    covered: dict[str, list[str]] = {}
    verified: dict[str, tuple[str, list[str]]] = {}
    children: set = set()
    resolved_source = Path(source_arg).resolve().as_posix()

    for s in subjects:
        name = str(s)
        before = len(refusals.items)
        if not isinstance(s, URIRef):
            refusals.add(name, "iri_invalid", "candidate is a blank node")
            continue
        for p in sorted({p for p in graph.predicates(s, None)}, key=str):
            if p not in allowed:
                refusals.add(name, "unknown_predicate", str(p))
        types = set(graph.objects(s, RDF.type))
        if types != {proposition}:
            refusals.add(name, "type_invalid", ", ".join(sorted(str(t) for t in types)))
        values = {}
        for prop in SINGLE_PROPS:
            objs = list(graph.objects(s, sj(prop)))
            if len(objs) != 1:
                code = "missing_property" if not objs else "duplicate_property"
                refusals.add(name, code, f"sj:{prop} has {len(objs)} values")
            else:
                values[prop] = objs[0]
        kind = values.get("propositionKind")
        if kind is not None and (not isinstance(kind, Literal) or str(kind) not in KINDS):
            refusals.add(name, "kind_invalid", f"{str(kind)!r} is not an ARD §5.2 kind")
        boundary = values.get("boundaryClass")
        if boundary is not None and boundary not in boundary_iris:
            refusals.add(name, "boundary_class_invalid", str(boundary))
        standing = values.get("candidateStanding")
        if standing is not None and str(standing) != "UNKNOWN":
            refusals.add(name, "candidate_standing_invalid", f"{str(standing)!r} (must be UNKNOWN)")
        statement = values.get("statement")
        if statement is not None and (not str(statement).strip() or "\n" in str(statement)):
            refusals.add(name, "statement_invalid", "statement must be one non-empty line")
        doc = values.get("sourceDocument")
        if doc is not None and not (resolved_source == str(doc) or resolved_source.endswith("/" + str(doc))):
            refusals.add(name, "source_document_mismatch", f"{str(doc)!r} does not name {source_arg}")
        digest = values.get("sourceSha256")
        if digest is not None and str(digest) != sha:
            refusals.add(name, "source_sha256_mismatch", f"candidate {str(digest)} != source {sha}")
        start, end = values.get("sourceStart"), values.get("sourceEnd")
        span_ok = True
        for label_, lit in (("sourceStart", start), ("sourceEnd", end)):
            if lit is not None and (
                not isinstance(lit, Literal) or str(lit.datatype) != XSD_INTEGER or not isinstance(lit.toPython(), int)
            ):
                refusals.add(name, "offset_invalid", f"sj:{label_} is not an xsd:integer")
                span_ok = False
        if start is not None and end is not None and span_ok:
            a, b = start.toPython(), end.toPython()
            if not (0 <= a < b <= len(source)):
                refusals.add(name, "offset_out_of_range", f"[{a}, {b}) outside 0..{len(source)}")
            else:
                try:
                    span = source[a:b].decode("utf-8")
                except UnicodeDecodeError:
                    refusals.add(name, "utf8_span_invalid", f"bytes[{a}:{b}] split a UTF-8 sequence")
                else:
                    text_lit = values.get("sourceText")
                    if text_lit is not None and span != str(text_lit):
                        refusals.add(
                            name,
                            "source_text_mismatch",
                            f"bytes[{a}:{b}] = {short(span)!r} != sourceText {short(str(text_lit))!r}",
                        )
            if kind is not None and digest is not None:
                expected = namespace + candidate_local(str(digest), a, b, str(kind))
                if name != expected:
                    refusals.add(name, "iri_mismatch", f"recomputed {expected}")
        gates = []
        for g in graph.objects(s, sj("requiredBy")):
            if not isinstance(g, URIRef):
                refusals.add(name, "required_by_invalid", f"{str(g)!r} is not a gate IRI")
            else:
                gates.append(str(g))
        for key, cls in NODE_HINTS.items():
            linked = sorted(graph.objects(s, sj(key)), key=str)
            expected_nodes = {f"{name}-{key}-{n}" for n in range(1, len(linked) + 1)}
            for child in linked:
                children.add(child)
                if str(child) not in expected_nodes:
                    refusals.add(name, "hint_node_invalid", f"sj:{key} {child}")
                    continue
                if set(graph.objects(child, RDF.type)) != {sj(cls)}:
                    refusals.add(name, "hint_node_invalid", f"{child} is not only a sj:{cls}")
                descs = list(graph.objects(child, URIRef(DCTERMS + "description")))
                if len(descs) != 1 or not str(descs[0]).strip():
                    refusals.add(name, "hint_node_invalid", f"{child} needs one dcterms:description")
                extra = {p for p in graph.predicates(child, None)} - {
                    RDF.type,
                    URIRef(DCTERMS + "description"),
                }
                if extra:
                    refusals.add(name, "unknown_predicate", ", ".join(sorted(str(p) for p in extra)))
        for key in LITERAL_HINTS:
            for v in graph.objects(s, sj(key)):
                if not isinstance(v, Literal) or not str(v).strip():
                    refusals.add(name, "hints_invalid", f"sj:{key} must be non-empty text")
        if len(refusals.items) == before:
            verified[name] = (str(kind), sorted(gates))
            for g in gates:
                covered.setdefault(g, []).append(name)

    candidates = set(subjects)
    for s in sorted({s for s in graph.subjects(None, None)}, key=str):
        if s not in candidates and s not in children:
            refusals.add(str(s), "stray_subject", "not a candidate nor a candidate's hint node")
    return covered, len(subjects), verified


def tally(verified: dict[str, tuple[str, list[str]]], namespace: str) -> dict:
    """Counts over verified candidates; every candidate lands in exactly one of required / not_required."""
    kinds: dict[str, int] = {}
    targets: dict[str, int] = {}
    required = not_required = multi_required = 0
    for kind, gates in verified.values():
        kinds[kind] = kinds.get(kind, 0) + 1
        if not gates:
            not_required += 1
            continue
        required += 1
        if len(gates) > 1:
            multi_required += 1
        for g in gates:
            local = g[len(namespace) :] if g.startswith(namespace) else g
            targets[local] = targets.get(local, 0) + 1
    return {
        "kinds": kinds,
        "multi_required": multi_required,
        "not_required": not_required,
        "required": required,
        "required_by": targets,
        "verified": len(verified),
    }


def cmd_check(args: argparse.Namespace) -> int:
    refusals = Refusals()
    source = Path(args.source).read_bytes()
    candidates_bytes = Path(args.candidates).read_bytes()
    text = None
    try:
        text = candidates_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        refusals.add(args.candidates, "candidates_unparseable", str(exc))
    covered, count, verified = ({}, 0, {})
    if text is not None:
        covered, count, verified = verify_turtle(text, source, args.source, args.namespace, refusals, args.candidates)
    gates = [f"{args.gate_prefix}{i}" for i in range(args.require_gates or 0)]
    for gate in gates:
        if not covered.get(args.namespace + gate):
            refusals.add(
                args.namespace + gate,
                "gate_uncovered",
                "no verified candidate carries sj:requiredBy for this gate",
            )
    if args.extract:
        from rdflib import Graph, URIRef

        graph = Graph()
        try:
            graph.parse(data=text or "", format="turtle")
            docs = {str(o) for o in graph.objects(None, URIRef(SJ + "sourceDocument"))}
            ids = {str(o) for o in graph.objects(None, URIRef(SJ + "extractedBy"))}
        except Exception:  # already refused as candidates_unparseable above
            docs, ids = set(), set()
        if len(docs) != 1 or len(ids) != 1:
            refusals.add(args.candidates, "projection_drift", "sourceDocument/extractedBy not unique")
        else:
            sub = Refusals()
            again = project(
                source,
                Path(args.extract).read_bytes(),
                docs.pop(),
                ids.pop(),
                args.namespace,
                args.prefix,
                sub,
            )
            refusals.items += sub.items
            if again is not None and again.encode("utf-8") != candidates_bytes:
                refusals.add(
                    args.candidates,
                    "projection_drift",
                    f"re-emit from {args.extract} differs from the candidates bytes",
                )
    counts = tally(verified, args.namespace)
    if args.summary:
        summary = dict(
            counts,
            candidates=count,
            candidates_sha256=source_digest(candidates_bytes),
            check="FAILED" if refusals else "OK",
            refusals=len(refusals.items),
            require_gates=args.require_gates or 0,
            source_sha256=source_digest(source),
        )
        out = Path(args.summary)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(summary, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if refusals:
        sys.stdout.write(refusals.render())
        sys.stdout.write(f"CHECK FAILED: {len(refusals.items)} refusal(s) over {count} candidates\n")
        return 1
    gate_tally = " ".join(f"{g}={len(covered.get(args.namespace + g, []))}" for g in gates)
    targets = " ".join(f"{t}={n}" for t, n in sorted(counts["required_by"].items()))
    sys.stdout.write(
        f"CHECK OK: {count} candidates bound to {args.source} {source_digest(source)}"
        + (f"; gates {gate_tally}" if gates else "")
        + "\n"
        + f"TALLY: required {counts['required']} + not_required {counts['not_required']} = {count}"
        + f" (multi_required {counts['multi_required']}); requiredBy {targets or '-'}\n"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="prose_spans.py", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("emit", "check"):
        p = sub.add_parser(name)
        p.add_argument("--source", required=True, help="accepted prose file (bytes are the provenance)")
        p.add_argument("--namespace", default=DEFAULT_NAMESPACE, help="instance namespace for candidate IRIs")
        p.add_argument("--prefix", default=DEFAULT_PREFIX, help="Turtle prefix label for --namespace")
        if name == "emit":
            p.add_argument("--extract", required=True, help="extraction JSON list (the raw O)")
            p.add_argument("--out", required=True, help="candidates Turtle to write")
            p.add_argument("--source-path", required=True, help="repo-relative path recorded as sj:sourceDocument")
            p.add_argument("--extracted-by", required=True, help="extractor identity, e.g. llm:<model>@<run>")
        else:
            p.add_argument("--candidates", required=True, help="candidates Turtle to re-verify")
            p.add_argument("--require-gates", type=int, default=0, help="require gates <prefix>0..N-1 covered")
            p.add_argument("--gate-prefix", default=DEFAULT_GATE_PREFIX, help="gate local-name prefix")
            p.add_argument("--extract", help="also re-emit from this extraction and require identical bytes")
            p.add_argument("--summary", help="write the verified-candidate tally (sorted JSON) to this path")
    args = parser.parse_args(argv)
    return cmd_emit(args) if args.command == "emit" else cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
