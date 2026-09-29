#!/usr/bin/env python3
"""WD FA claims ledger court (lane V23-W; PRD section 9.2, the Friday G12 deliverable).

The claims ledger (Turtle) is canonical; the proposal (Markdown) is its
projection (ARD AR-002). Every claim-bearing sentence of the proposal carries
a ledger marker `[Cn]` and exactly one PRD section 9.2 class:

  SUPPLIED                  carried by an artifact supplied into the record and
                            bound by a receipt the fleet validator ADMITS:
                            evidenceKind "supplied-input" (a quote verified
                            against a digest-bound supplied text) or
                            "observed-proof" (an ALIVE receipt of an executed run)
  PUBLICLY_OBSERVABLE       verifiable by a third party from public artifacts
                            (https references: PR, commit, CI run, standard)
  ARCHITECTURAL_INFERENCE   derived by a stated reasoning chain from other
                            claims (premises), none of them WD_DEPENDENT_UNKNOWN
  WD_DEPENDENT_UNKNOWN      requires a Western Digital input that was not
                            supplied; names the missing input(s)

  render --ledger <claims.ttl> --out <proposal.md>
  check  --ledger <claims.ttl> --proposal <proposal.md> [--root DIR]
         [--validator PATH] [--summary JSON]

`check` refuses (one `REFUSED <subject>: <code>: <detail>` line each):
  * a `[Cn]` marker that resolves to no claim, a malformed marker, a sentence
    with two markers, or a marked sentence whose text differs from the ledger;
  * a ledger claim no proposal sentence references;
  * a claim without exactly one class, or whose evidence does not fit it;
  * a SUPPLIED claim whose receipts the validator does not ADMIT, an
    observed proof whose receipt standing is not ALIVE, a supplied quote not
    found in its supplied text, or a supplied text whose digest no cited
    receipt binds;
  * an inference on an unknown or unresolved premise, or a premise cycle;
  * a sentence matching a declared missing WD input's guard that is neither
    WD_DEPENDENT_UNKNOWN naming that input nor a verified supplied quote
    (an unsupplied WD fact classified as anything else);
  * a sentence containing a digit or a will / prove(n) / reduce verb without
    a marker;
  * a proposal whose bytes differ from `render` of the ledger (projection_drift).

Exit 0 when every check holds, 1 on any refusal, 2 on usage errors. No LLM,
no network; the validator runs as a real subprocess
(`python3 <validator> <receipt> ...`, default $DFCM_VALIDATOR or
~/.claude/dfcm/validate_receipt.py). Standard library + rdflib.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WDC = "https://ggen-igniter.dev/sjira/v26.9.23/wd-fa/claims#"
DCTERMS = "http://purl.org/dc/terms/"
RDFS = "http://www.w3.org/2000/01/rdf-schema#"
CLASSES = ("SUPPLIED", "PUBLICLY_OBSERVABLE", "ARCHITECTURAL_INFERENCE", "WD_DEPENDENT_UNKNOWN")
EVIDENCE_KINDS = ("supplied-input", "observed-proof")
CLAIM_ID = re.compile(r"^C[1-9][0-9]*$")
MARKER = re.compile(r"\[C([1-9][0-9]*)\]")
MARKER_LIKE = re.compile(r"\[\s*[Cc]\s*[^\]]*\]")
PLACEHOLDER = re.compile(r"\{(C[1-9][0-9]*)\}")
PLACEHOLDER_LIKE = re.compile(r"\{\s*[Cc][^}]*\}")
CLAIM_VERB = re.compile(r"\b(will|prove|proves|proved|proven|reduce|reduces|reduced|reducing)\b", re.IGNORECASE)
DIGIT = re.compile(r"[0-9]")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+(?=\S)")
PUBLIC_REF = re.compile(r"^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/\S*)?$")


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


def short(text: str, width: int = 60) -> str:
    flat = text.replace("\n", "\\n")
    return flat if len(flat) <= width else flat[: width - 3] + "..."


# ── ledger ───────────────────────────────────────────────────────────────────


class Ledger:
    """The parsed claims ledger: document skeleton, claims and missing inputs."""

    def __init__(self) -> None:
        self.title: str | None = None
        self.status: str | None = None
        self.preamble: str | None = None
        self.sections: list[tuple[int, str, str, str]] = []  # (order, iri, heading, body)
        self.claims: dict[str, dict] = {}  # claim id -> fields
        self.by_iri: dict[str, str] = {}  # claim iri -> claim id
        self.missing: dict[str, dict] = {}  # missing-input iri -> {label, guards}


def load_ledger(path: Path, refusals: Refusals) -> Ledger | None:
    try:
        from rdflib import Graph, Literal, URIRef
        from rdflib.namespace import RDF
    except ImportError as exc:
        refusals.add(path.as_posix(), "rdflib_unavailable", f"{exc} (under a fresh HOME pass PYTHONUSERBASE explicitly)")
        return None

    graph = Graph()
    try:
        graph.parse(path.as_posix(), format="turtle")
    except Exception as exc:  # rdflib raises several parser exception types
        refusals.add(path.as_posix(), "ledger_unparseable", f"{type(exc).__name__}: {short(str(exc), 160)}")
        return None

    def w(name: str) -> URIRef:
        return URIRef(WDC + name)

    def texts(s, p) -> list[str]:
        return sorted(str(o) for o in graph.objects(s, p) if isinstance(o, Literal))

    def one(s, p, label: str, subject: str) -> str | None:
        values = texts(s, p)
        if len(values) != 1:
            refusals.add(subject, "ledger_field_invalid", f"{label} has {len(values)} values (need 1)")
            return None
        return values[0]

    ledger = Ledger()
    proposals = sorted(graph.subjects(RDF.type, w("Proposal")), key=str)
    if len(proposals) != 1:
        refusals.add(path.as_posix(), "ledger_field_invalid", f"{len(proposals)} wdc:Proposal nodes (need 1)")
    else:
        p = proposals[0]
        ledger.title = one(p, URIRef(DCTERMS + "title"), "dcterms:title", str(p))
        ledger.status = one(p, w("status"), "wdc:status", str(p))
        pre = texts(p, w("preamble"))
        ledger.preamble = pre[0] if len(pre) == 1 else None
        if len(pre) > 1:
            refusals.add(str(p), "ledger_field_invalid", "wdc:preamble has more than one value")

    orders: set[int] = set()
    for s in sorted(graph.subjects(RDF.type, w("Section")), key=str):
        order_values = [o.toPython() for o in graph.objects(s, w("order")) if isinstance(o, Literal)]
        heading = one(s, URIRef(RDFS + "label"), "rdfs:label", str(s))
        body = one(s, w("body"), "wdc:body", str(s))
        if len(order_values) != 1 or not isinstance(order_values[0], int) or isinstance(order_values[0], bool):
            refusals.add(str(s), "ledger_field_invalid", "wdc:order must be one xsd:integer")
            continue
        if order_values[0] in orders:
            refusals.add(str(s), "ledger_field_invalid", f"duplicate section order {order_values[0]}")
            continue
        orders.add(order_values[0])
        if heading is not None and body is not None:
            ledger.sections.append((order_values[0], str(s), heading, body))
    ledger.sections.sort()
    if not ledger.sections:
        refusals.add(path.as_posix(), "ledger_field_invalid", "no wdc:Section")

    for s in sorted(graph.subjects(RDF.type, w("MissingInput")), key=str):
        label = one(s, URIRef(RDFS + "label"), "rdfs:label", str(s))
        guards = []
        for pattern in texts(s, w("guardPattern")):
            try:
                guards.append(re.compile(pattern, re.IGNORECASE))
            except re.error as exc:
                refusals.add(str(s), "guard_invalid", f"{pattern!r}: {exc}")
        ledger.missing[str(s)] = {"label": label or str(s), "guards": guards}

    for s in sorted(graph.subjects(RDF.type, w("Claim")), key=str):
        subject = str(s)
        ids = texts(s, URIRef(DCTERMS + "identifier"))
        if len(ids) != 1 or not CLAIM_ID.match(ids[0]):
            refusals.add(subject, "claim_id_invalid", f"dcterms:identifier {ids!r} (need one ^C[1-9][0-9]*$)")
            continue
        cid = ids[0]
        if cid in ledger.claims:
            refusals.add(subject, "duplicate_claim_id", f"{cid} is also {ledger.claims[cid]['iri']}")
            continue
        classes = sorted(
            str(o)[len(WDC) :] if str(o).startswith(WDC) else str(o) for o in graph.objects(s, w("claimClass"))
        )
        ledger.claims[cid] = {
            "iri": subject,
            "id": cid,
            "sentence": texts(s, w("sentence")),
            "classes": classes,
            "evidence_kinds": texts(s, w("evidenceKind")),
            "receipts": texts(s, w("receipt")),
            "public_refs": texts(s, w("publicRef")),
            "premises": sorted(str(o) for o in graph.objects(s, w("premise"))),
            "reasoning": texts(s, w("reasoning")),
            "missing_inputs": sorted(str(o) for o in graph.objects(s, w("missingInput"))),
            "quotes": texts(s, w("quote")),
            "supplied_sources": texts(s, w("suppliedSource")),
            "classified_by": texts(s, w("classifiedBy")),
        }
        ledger.by_iri[subject] = cid
    if not ledger.claims:
        refusals.add(path.as_posix(), "ledger_field_invalid", "no wdc:Claim")
    return ledger


# ── render ───────────────────────────────────────────────────────────────────


def marked(sentence: str, cid: str) -> str:
    return f"{sentence[:-1]} [{cid}]{sentence[-1]}"


def render(ledger: Ledger, refusals: Refusals) -> str | None:
    """The proposal as a pure function of the ledger (sorted sections, placeholders expanded)."""
    if ledger.title is None or ledger.status is None:
        return None
    parts = [f"# {ledger.title}", "", ledger.status.strip(), ""]
    if ledger.preamble:
        parts += [ledger.preamble.strip(), ""]
    for _order, iri, heading, body in ledger.sections:
        for bad in PLACEHOLDER_LIKE.findall(body):
            if not PLACEHOLDER.fullmatch(bad):
                refusals.add(iri, "placeholder_malformed", repr(bad))

        def expand(match: re.Match) -> str:
            cid = match.group(1)
            claim = ledger.claims.get(cid)
            if claim is None or len(claim["sentence"]) != 1 or not claim["sentence"][0][-1:] in ".!?":
                refusals.add(iri, "placeholder_unresolved", f"{{{cid}}} names no claim with one sentence")
                return match.group(0)
            return marked(claim["sentence"][0], cid)

        parts += [f"## {heading}", "", PLACEHOLDER.sub(expand, body.strip()), ""]
    return "\n".join(parts)


# ── proposal scan ────────────────────────────────────────────────────────────


def units(markdown: str) -> list[tuple[int, str]]:
    """(line number, text) of each heading, list item and paragraph."""
    out: list[tuple[int, str]] = []
    buffer: list[str] = []
    start = 0

    def flush() -> None:
        nonlocal buffer
        if buffer:
            out.append((start, " ".join(buffer)))
            buffer = []

    for number, raw in enumerate(markdown.split("\n"), start=1):
        line = raw.strip()
        if not line:
            flush()
            continue
        heading = re.match(r"^#{1,6}\s+(.*)$", line)
        item = re.match(r"^[-*]\s+(.*)$", line)
        if heading or item:
            flush()
            out.append((number, (heading or item).group(1)))
            continue
        if not buffer:
            start = number
        buffer.append(line)
    flush()
    return out


def sentences(markdown: str) -> list[tuple[int, str]]:
    return [(n, s.strip()) for n, unit in units(markdown) for s in SENTENCE_SPLIT.split(unit) if s.strip()]


def scan_proposal(text: str, ledger: Ledger, refusals: Refusals) -> dict:
    referenced: set[str] = set()
    scanned = marked_count = 0
    for line, sentence in sentences(text):
        scanned += 1
        where = f"proposal:{line}"
        for bad in MARKER_LIKE.findall(sentence):
            if not MARKER.fullmatch(bad):
                refusals.add(where, "marker_malformed", f"{bad!r} in {short(sentence)!r}")
        markers = [f"C{m}" for m in MARKER.findall(sentence)]
        if len(markers) > 1:
            refusals.add(where, "sentence_multi_claim", f"{markers} in {short(sentence)!r}")
            continue
        if not markers:
            if DIGIT.search(sentence) or CLAIM_VERB.search(sentence):
                refusals.add(where, "unmarked_claim_sentence", repr(short(sentence, 90)))
            continue
        cid = markers[0]
        marked_count += 1
        claim = ledger.claims.get(cid)
        if claim is None:
            refusals.add(where, "marker_unresolved", f"[{cid}] names no ledger claim")
            continue
        referenced.add(cid)
        bare = sentence.replace(f" [{cid}]", "", 1)
        if claim["sentence"] != [bare]:
            refusals.add(where, "sentence_mismatch", f"[{cid}] {short(bare)!r} != ledger {short(' | '.join(claim['sentence']))!r}")
    for cid in sorted(set(ledger.claims) - referenced, key=lambda c: int(c[1:])):
        refusals.add(ledger.claims[cid]["iri"], "claim_unreferenced", f"no proposal sentence carries [{cid}]")
    return {"sentences": scanned, "marked_sentences": marked_count, "referenced_claims": len(referenced)}


# ── evidence ─────────────────────────────────────────────────────────────────


def check_claims(ledger: Ledger, root: Path, refusals: Refusals) -> set[str]:
    """Class and evidence rules; returns the receipt paths to validate."""
    to_validate: set[str] = set()
    for cid in sorted(ledger.claims, key=lambda c: int(c[1:])):
        c = ledger.claims[cid]
        subject = c["iri"]
        if len(c["sentence"]) != 1:
            refusals.add(subject, "sentence_invalid", f"{len(c['sentence'])} wdc:sentence values (need 1)")
        else:
            s = c["sentence"][0]
            if "\n" in s or s != s.strip() or s[-1:] not in ".!?" or MARKER_LIKE.search(s) or PLACEHOLDER_LIKE.search(s):
                refusals.add(subject, "sentence_invalid", f"one line ending in . ! or ?, no marker: {short(s)!r}")
            elif len(SENTENCE_SPLIT.split(s)) != 1:
                refusals.add(subject, "claim_sentence_not_single", repr(short(s)))
        if len(c["classes"]) != 1:
            refusals.add(subject, "class_count", f"{len(c['classes'])} wdc:claimClass values (need exactly 1)")
            continue
        cls = c["classes"][0]
        if cls not in CLASSES:
            refusals.add(subject, "class_invalid", f"{cls!r} is not one of {', '.join(CLASSES)}")
            continue
        if not c["classified_by"]:
            refusals.add(subject, "classified_by_missing", "wdc:classifiedBy names no classifier")
        to_validate.update(c["receipts"])
        if cls == "SUPPLIED":
            if len(c["evidence_kinds"]) != 1 or c["evidence_kinds"][0] not in EVIDENCE_KINDS:
                refusals.add(subject, "evidence_kind_invalid", f"{c['evidence_kinds']!r} (need one of {EVIDENCE_KINDS})")
            if not c["receipts"]:
                refusals.add(subject, "receipt_missing", "a SUPPLIED claim cites no receipt")
            kind = c["evidence_kinds"][0] if c["evidence_kinds"] else None
            if kind == "supplied-input":
                check_supplied_input(c, root, refusals)
            elif kind == "observed-proof":
                for rel in c["receipts"]:
                    data = read_json(root / rel)
                    value = ((data or {}).get("standing") or {}).get("value") if isinstance(data, dict) else None
                    if data is not None and value != "ALIVE":
                        refusals.add(subject, "proof_not_alive", f"{rel} standing {value!r}")
        elif cls == "PUBLICLY_OBSERVABLE":
            if not c["public_refs"]:
                refusals.add(subject, "public_ref_missing", "no wdc:publicRef")
            for ref in c["public_refs"]:
                if not PUBLIC_REF.match(ref):
                    refusals.add(subject, "public_ref_invalid", f"{ref!r} is not an https URL")
        elif cls == "ARCHITECTURAL_INFERENCE":
            if not c["premises"]:
                refusals.add(subject, "premise_missing", "an inference names no premise claim")
            if not any(r.strip() for r in c["reasoning"]):
                refusals.add(subject, "reasoning_missing", "no wdc:reasoning chain")
            for premise in c["premises"]:
                pid = ledger.by_iri.get(premise)
                if pid is None:
                    refusals.add(subject, "premise_unresolved", premise)
                elif pid == cid:
                    refusals.add(subject, "inference_cycle", "a claim is its own premise")
                elif ledger.claims[pid]["classes"] == ["WD_DEPENDENT_UNKNOWN"]:
                    refusals.add(subject, "inference_on_unknown", f"premise {pid} is WD_DEPENDENT_UNKNOWN")
        elif cls == "WD_DEPENDENT_UNKNOWN":
            if not c["missing_inputs"]:
                refusals.add(subject, "missing_input_missing", "no wdc:missingInput")
            for mi in c["missing_inputs"]:
                if mi not in ledger.missing:
                    refusals.add(subject, "missing_input_unresolved", mi)
    check_cycles(ledger, refusals)
    check_guards(ledger, refusals)
    return to_validate


def read_json(path: Path) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None


def check_supplied_input(c: dict, root: Path, refusals: Refusals) -> None:
    subject = c["iri"]
    if len(c["supplied_sources"]) != 1 or not c["quotes"]:
        refusals.add(subject, "supplied_quote_missing", "supplied-input needs one wdc:suppliedSource and >= 1 wdc:quote")
        return
    source = root / c["supplied_sources"][0]
    try:
        data = source.read_bytes()
    except OSError as exc:
        refusals.add(subject, "supplied_source_unreadable", f"{c['supplied_sources'][0]}: {exc.strerror}")
        return
    for quote in c["quotes"]:
        if quote.encode("utf-8") not in data:
            refusals.add(subject, "quote_not_in_supplied_source", f"{short(quote)!r} not in {c['supplied_sources'][0]}")
    digest = "sha256:" + sha256_hex(data)
    bound = any(digest in (root / rel).read_text(encoding="utf-8", errors="replace") for rel in c["receipts"] if (root / rel).is_file())
    if not bound:
        refusals.add(subject, "supplied_source_unbound", f"no cited receipt names {c['supplied_sources'][0]} {digest}")


def check_cycles(ledger: Ledger, refusals: Refusals) -> None:
    state: dict[str, int] = {}

    def visit(cid: str, trail: list[str]) -> None:
        state[cid] = 1
        for premise in ledger.claims[cid]["premises"]:
            pid = ledger.by_iri.get(premise)
            if pid is None or pid == cid:
                continue
            if state.get(pid) == 1:
                refusals.add(ledger.claims[cid]["iri"], "inference_cycle", " -> ".join(trail + [cid, pid]))
            elif state.get(pid) is None:
                visit(pid, trail + [cid])
        state[cid] = 2

    for cid in sorted(ledger.claims, key=lambda c: int(c[1:])):
        if state.get(cid) is None:
            visit(cid, [])


def check_guards(ledger: Ledger, refusals: Refusals) -> None:
    """An unsupplied WD fact may appear only as WD_DEPENDENT_UNKNOWN (or a verified supplied quote)."""
    for cid in sorted(ledger.claims, key=lambda c: int(c[1:])):
        c = ledger.claims[cid]
        if len(c["sentence"]) != 1:
            continue
        for mi, info in sorted(ledger.missing.items()):
            if not any(g.search(c["sentence"][0]) for g in info["guards"]):
                continue
            if c["classes"] == ["WD_DEPENDENT_UNKNOWN"] and mi in c["missing_inputs"]:
                continue
            if c["classes"] == ["SUPPLIED"] and c["evidence_kinds"] == ["supplied-input"]:
                continue
            refusals.add(
                c["iri"],
                "unsupplied_wd_fact",
                f"[{cid}] matches the guard of missing input {info['label']!r} but is {c['classes']} "
                "(must be WD_DEPENDENT_UNKNOWN naming it, or a verified supplied quote)",
            )


def validate_receipts(paths: set[str], root: Path, validator: Path, refusals: Refusals) -> int:
    existing = []
    for rel in sorted(paths):
        if (root / rel).is_file():
            existing.append(rel)
        else:
            refusals.add(rel, "receipt_missing", "cited receipt file does not exist")
    if not existing:
        return 0
    if not validator.is_file():
        refusals.add(validator.as_posix(), "validator_unavailable", "fleet receipt validator not found")
        return 0
    with tempfile.TemporaryDirectory() as home:
        # validate_receipt.py reads ~/.claude/dfcm/receipt.schema.json. Run it
        # with a fresh HOME holding only that schema (copied from beside the
        # validator), so the check behaves the same in the F3 no-LLM court
        # environment (fresh HOME) and in an ordinary shell, and never reads
        # anything else under the caller's home.
        env = dict(os.environ)
        schema = validator.parent / "receipt.schema.json"
        if schema.is_file():
            target = Path(home) / ".claude" / "dfcm"
            target.mkdir(parents=True)
            shutil.copyfile(schema, target / schema.name)
            env["HOME"] = home
        proc = subprocess.run(
            [sys.executable, validator.as_posix(), *existing],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
    admitted = {line[len("ADMITTED ") :].strip() for line in proc.stdout.splitlines() if line.startswith("ADMITTED ")}
    for rel in existing:
        if rel not in admitted:
            errors = proc.stderr.strip().splitlines()
            said = proc.stdout.strip() or (errors[-1] if errors else "")
            refusals.add(rel, "receipt_not_admitted", f"validator exit {proc.returncode}: {short(said, 160)}")
    return len(admitted & set(existing))


# ── commands ─────────────────────────────────────────────────────────────────


def default_root(ledger: Path) -> Path:
    proc = subprocess.run(
        ["git", "-C", ledger.resolve().parent.as_posix(), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    return Path(proc.stdout.strip()) if proc.returncode == 0 and proc.stdout.strip() else Path.cwd()


def default_validator() -> Path:
    env = os.environ.get("DFCM_VALIDATOR")
    return Path(env) if env else Path.home() / ".claude" / "dfcm" / "validate_receipt.py"


def cmd_render(args: argparse.Namespace) -> int:
    refusals = Refusals()
    ledger = load_ledger(Path(args.ledger), refusals)
    text = render(ledger, refusals) if ledger else None
    if refusals or text is None:
        sys.stdout.write(refusals.render())
        sys.stdout.write(f"RENDER REFUSED: {len(refusals.items)} refusal(s); {args.out} not written\n")
        return 1
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    tmp.write_bytes(text.encode("utf-8"))
    os.replace(tmp, out)
    words = len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'’.-]*", text))
    sys.stdout.write(f"RENDER: {args.out} sha256:{sha256_hex(text.encode('utf-8'))} ({words} words)\n")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    refusals = Refusals()
    ledger_path = Path(args.ledger)
    root = Path(args.root) if args.root else default_root(ledger_path)
    ledger = load_ledger(ledger_path, refusals)
    try:
        proposal_bytes = Path(args.proposal).read_bytes()
        proposal = proposal_bytes.decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        refusals.add(args.proposal, "proposal_unreadable", str(exc))
        proposal_bytes, proposal = b"", None
    scan: dict = {}
    admitted = 0
    if ledger is not None:
        paths = check_claims(ledger, root, refusals)
        admitted = validate_receipts(paths, root, Path(args.validator) if args.validator else default_validator(), refusals)
        if proposal is not None:
            scan = scan_proposal(proposal, ledger, refusals)
            expected = render(ledger, Refusals())
            if expected is not None and expected.encode("utf-8") != proposal_bytes:
                refusals.add(args.proposal, "projection_drift", f"bytes differ from `render --ledger {args.ledger}`")
    classes = {k: 0 for k in CLASSES}
    kinds = {k: 0 for k in EVIDENCE_KINDS}
    for c in (ledger.claims.values() if ledger else []):
        if len(c["classes"]) == 1 and c["classes"][0] in classes:
            classes[c["classes"][0]] += 1
        if c["classes"] == ["SUPPLIED"] and len(c["evidence_kinds"]) == 1 and c["evidence_kinds"][0] in kinds:
            kinds[c["evidence_kinds"][0]] += 1
    summary = {
        "check": "FAILED" if refusals else "OK",
        "claims": len(ledger.claims) if ledger else 0,
        "classes": classes,
        "supplied_evidence_kinds": kinds,
        "receipts_admitted": admitted,
        "refusals": len(refusals.items),
        "ledger_sha256": "sha256:" + sha256_hex(ledger_path.read_bytes()) if ledger_path.is_file() else None,
        "proposal_sha256": "sha256:" + sha256_hex(proposal_bytes),
        **scan,
    }
    if args.summary:
        Path(args.summary).parent.mkdir(parents=True, exist_ok=True)
        Path(args.summary).write_text(json.dumps(summary, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    if refusals:
        sys.stdout.write(refusals.render())
        sys.stdout.write(f"CHECK FAILED: {len(refusals.items)} refusal(s)\n")
        return 1
    tally = " ".join(f"{k}={v}" for k, v in classes.items())
    sys.stdout.write(
        f"CHECK OK: {summary['claims']} claims ({tally}); {scan.get('sentences', 0)} sentences, "
        f"{scan.get('marked_sentences', 0)} marked; {admitted} receipts ADMITTED; proposal == render(ledger)\n"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wd_claims.py", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    r = sub.add_parser("render")
    r.add_argument("--ledger", required=True)
    r.add_argument("--out", required=True)
    c = sub.add_parser("check")
    c.add_argument("--ledger", required=True)
    c.add_argument("--proposal", required=True)
    c.add_argument("--root", help="directory receipt/supplied paths resolve against (default: the ledger's git toplevel)")
    c.add_argument("--validator", help="fleet receipt validator (default: $DFCM_VALIDATOR or ~/.claude/dfcm/validate_receipt.py)")
    c.add_argument("--summary", help="write the verified tally (sorted JSON) to this path")
    args = parser.parse_args(argv)
    return cmd_render(args) if args.command == "render" else cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
