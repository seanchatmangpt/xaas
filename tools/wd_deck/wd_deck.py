from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Annotated, Literal
import xml.etree.ElementTree as ET

import typer

app = typer.Typer(no_args_is_help=True, add_completion=False, help="Manufacture and verify the WD Case Study 2 PowerPoint from its semantic deck ontology.")

THIS_DIR = Path(__file__).resolve().parent
REPO_ROOT = THIS_DIR.parents[1]
ONTOLOGY_DIR = REPO_ROOT / "docs/case-studies/wd-fa/presentation"
DEFAULT_BUILD = REPO_ROOT / "tmp/wd-deck"
DEFAULT_OUT = DEFAULT_BUILD / "wd_case_study_2_presentation_notes.pptx"
PACK_NAME = "pptx-presentation-pack"
MARKETPLACE_REPO = "seanchatmangpt/ggen-marketplace"
MARKETPLACE_COMMIT = "05011be534f647d1b5aef18a2080cb61bfcf7951"
PPTXGENJS_VERSION = "4.0.1"
RENDER_PARTS = tuple(f"render.part{i}.mjs.eex" for i in range(4))

Audience = Literal["all", "interview"]


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _run(cmd: list[str], *, cwd: Path = REPO_ROOT, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    typer.echo("+ " + " ".join(str(x) for x in cmd))
    result = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True)
    if result.stdout:
        typer.echo(result.stdout.rstrip())
    if result.returncode != 0:
        if result.stderr:
            typer.echo(result.stderr.rstrip(), err=True)
        raise typer.Exit(result.returncode)
    return result


def _pack_dir(explicit: Path | None, build: Path) -> Path:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    if os.environ.get("GGEN_PPTX_PACK_DIR"):
        candidates.append(Path(os.environ["GGEN_PPTX_PACK_DIR"]))
    candidates.append(REPO_ROOT.parent / "ggen-marketplace" / "packs" / PACK_NAME)

    for candidate in candidates:
        p = candidate.expanduser().resolve()
        if (p / "pack.toml").is_file() and (p / "ontology.ttl").is_file():
            observed = _pack_commit(p)
            if observed != MARKETPLACE_COMMIT:
                typer.echo(
                    f"REFUSED:PACK_COMMIT_DRIFT: {p} expected {MARKETPLACE_COMMIT} "
                    f"observed {observed or 'UNKNOWN'} (write .marketplace-commit via "
                    "`wd-deck materialize`, or checkout the pinned commit)",
                    err=True,
                )
                raise typer.Exit(8)
            return p

    typer.echo(
        "BLOCKED:PACK_NOT_MATERIALIZED: provide --pack-dir, set GGEN_PPTX_PACK_DIR, "
        "or checkout ggen-marketplace as a sibling at the pinned commit",
        err=True,
    )
    raise typer.Exit(3)



def _pack_commit(pack: Path) -> str | None:
    """The marketplace commit a materialized pack came from.

    A `git archive` materialization carries a `.marketplace-commit` marker; a
    git checkout of ggen-marketplace answers with its HEAD. Anything else is
    unknown and refused by `_pack_dir`.
    """
    marker = pack / ".marketplace-commit"
    if marker.is_file():
        return marker.read_text(encoding="utf-8").strip()
    result = subprocess.run(
        ["git", "-C", str(pack), "rev-parse", "HEAD"], text=True, capture_output=True
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return None


def _ontology_sources() -> list[Path]:
    return sorted(ONTOLOGY_DIR.glob("*.ttl"))


def _materialize_ontology(build: Path) -> Path:
    sources = _ontology_sources()
    if not sources:
        typer.echo(f"BLOCKED:ONTOLOGY_SOURCES_MISSING: {ONTOLOGY_DIR}", err=True)
        raise typer.Exit(3)
    target = build / "generated" / "deck.ttl"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(p.read_text() for p in sources))
    return target


def _sync_template(pack: Path, ontology: Path, template: str, out: Path, build: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    _run([
        "mix", "ggen_igniter.sync",
        "--engine", "sparql",
        "--pack-dir", str(pack),
        "--ontology", str(ontology),
        "--template", str(pack / "templates" / template),
        "--out", str(out),
    ])


def _assemble_renderer(build: Path) -> Path:
    generated = build / "generated"
    renderer = generated / "render.mjs"
    part_paths = [generated / f"render.part{i}.mjs" for i in range(4)]
    missing = [str(p) for p in part_paths if not p.is_file()]
    if missing:
        typer.echo("REFUSED:RENDERER_FRAGMENT_MISSING: " + ", ".join(missing), err=True)
        raise typer.Exit(4)
    renderer.write_bytes(b"".join(p.read_bytes() for p in part_paths))
    return renderer


def _runtime_package() -> Path:
    return THIS_DIR / "node_modules" / "pptxgenjs" / "package.json"


def _assert_runtime() -> None:
    package = _runtime_package()
    if not package.is_file():
        typer.echo("BLOCKED:PPTXGENJS_MISSING: run `wd-deck bootstrap`", err=True)
        raise typer.Exit(5)
    version = json.loads(package.read_text())["version"]
    if version != PPTXGENJS_VERSION:
        typer.echo(f"REFUSED:PPTXGENJS_VERSION_DRIFT: expected {PPTXGENJS_VERSION}, observed {version}", err=True)
        raise typer.Exit(5)


def _slides_for(spec: dict, audience: Audience) -> list[dict]:
    slides = sorted(spec["slides"], key=lambda s: int(s["order"]))
    if audience == "interview":
        slides = [s for s in slides if s.get("audience") != "internal"]
    return slides


BLOCK_OF = re.compile(r"^\s*pres:blockOf\s+wddeck:(slide-\d+)\s*;", re.MULTILINE)
BLOCK_DECL = re.compile(r"\sa\s+pres:Block\s*;")


def _source_block_counts() -> dict:
    """Blocks per slide as declared in the source TTL (what the deck must carry)."""
    counts: dict = {"__failures__": []}
    declared = 0
    for path in _ontology_sources():
        text = path.read_text(encoding="utf-8")
        declared += len(BLOCK_DECL.findall(text))
        if "pres:lockOf" in text:
            counts["__failures__"].append(f"{path.name}_uses_pres:lockOf")
        for sid in BLOCK_OF.findall(text):
            counts[sid] = counts.get(sid, 0) + 1
    linked = sum(v for k, v in counts.items() if k != "__failures__")
    if declared != linked:
        counts["__failures__"].append(f"blocks_declared={declared} blocks_linked={linked}")
    return counts


def _xml_text(data: bytes) -> str:
    root = ET.fromstring(data)
    ns = {"a": "http://schemas.openxmlformats.org/drawingml/2006/main"}
    return "".join(t.text or "" for t in root.findall(".//a:t", ns))


def _numbered(names: list[str], prefix: str) -> list[str]:
    pat = re.compile(re.escape(prefix) + r"(\d+)\.xml$")
    numbered = []
    for n in names:
        m = pat.search(n)
        if m:
            numbered.append((int(m.group(1)), n))
    return [n for _, n in sorted(numbered)]


def _verify(pptx: Path, spec_path: Path, audience: Audience, receipt_path: Path) -> dict:
    if not pptx.is_file():
        typer.echo(f"BLOCKED:PPTX_MISSING: {pptx}", err=True)
        raise typer.Exit(6)
    spec = json.loads(spec_path.read_text())
    expected = _slides_for(spec, audience)
    failures: list[str] = []
    with zipfile.ZipFile(pptx) as z:
        names = z.namelist()
        slide_xmls = _numbered(names, "ppt/slides/slide")
        note_xmls = _numbered(names, "ppt/notesSlides/notesSlide")
        if len(slide_xmls) != len(expected):
            failures.append(f"slide_count expected={len(expected)} observed={len(slide_xmls)}")
        expected_notes = sum(1 for s in expected if s.get("notes"))
        if len(note_xmls) != expected_notes:
            failures.append(f"note_count expected={expected_notes} observed={len(note_xmls)}")
        for i, slide in enumerate(expected):
            if i >= len(slide_xmls):
                break
            observed = _xml_text(z.read(slide_xmls[i])).replace("\n", " ")
            title = slide.get("title", "").replace("\n", " ")
            # OOXML may split title runs but should preserve all significant words.
            for token in [t for t in re.split(r"\s+", title) if len(t) >= 4][:4]:
                if token not in observed:
                    failures.append(f"slide_{i+1}_title_token_missing={token!r}")
                    break
            if slide.get("notes") and i < len(note_xmls):
                note_text = _xml_text(z.read(note_xmls[i]))
                anchor = slide["notes"][:48]
                if anchor not in note_text:
                    failures.append(f"slide_{i+1}_notes_anchor_missing")

    source_blocks = _source_block_counts()
    failures.extend(source_blocks.pop("__failures__"))
    block_counts = {}
    for slide in expected:
        sid = slide.get("slide_id", "")
        observed_blocks = len(slide.get("blocks", []))
        block_counts[sid] = observed_blocks
        if observed_blocks != source_blocks.get(sid, 0):
            failures.append(
                f"{sid}_block_count expected={source_blocks.get(sid, 0)} observed={observed_blocks}"
            )

    receipt = {
        "block_counts": block_counts,
        "subject": str(pptx.relative_to(REPO_ROOT) if pptx.is_relative_to(REPO_ROOT) else pptx),
        "standing": "ALIVE_REPO_LOCAL" if not failures else "BLOCKED",
        "audience": audience,
        "ontology_sources": [str(p.relative_to(REPO_ROOT)) for p in _ontology_sources()],
        "ontology_source_sha256": {str(p.relative_to(REPO_ROOT)): _sha256(p) for p in _ontology_sources()},
        "deck_spec_sha256": _sha256(spec_path),
        "pptx_sha256": _sha256(pptx),
        "marketplace_pack": f"{MARKETPLACE_REPO}@{MARKETPLACE_COMMIT}:{PACK_NAME}",
        "pptxgenjs": PPTXGENJS_VERSION,
        "expected_slides": len(expected),
        "expected_notes": sum(1 for s in expected if s.get("notes")),
        "failures": failures,
        "non_claims": [
            "WD_ACCEPTANCE", "PRODUCTION_DEPLOYMENT", "CUSTOMER_AUTHORITY", "EXTERNAL_STANDING"
        ],
        "falsifiers": [
            "ontology hash differs", "pack commit differs", "renderer runtime version differs",
            "slide count differs", "expected title absent", "expected speaker notes absent",
            "a source pres:Block is missing from the projected slide"
        ],
    }
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    if failures:
        typer.echo(json.dumps(receipt, indent=2), err=True)
        raise typer.Exit(7)
    typer.echo(json.dumps(receipt, indent=2))
    return receipt


@app.command()
def bootstrap() -> None:
    """Install the exact PptxGenJS runtime declared by this tool."""
    npm = shutil.which("npm")
    if not npm:
        typer.echo("BLOCKED:NPM_MISSING", err=True)
        raise typer.Exit(5)
    _run([npm, "install", "--prefix", str(THIS_DIR), "--ignore-scripts", "--no-audit", "--no-fund", "--no-package-lock"])
    _assert_runtime()
    typer.echo(f"PPTXGENJS_ALIVE={PPTXGENJS_VERSION}")


@app.command()
def sync(
    pack_dir: Annotated[Path | None, typer.Option(help="Local pptx-presentation-pack directory.")] = None,
    build_dir: Annotated[Path, typer.Option()] = DEFAULT_BUILD,
) -> None:
    """Project RDF deck facts into deck JSON and a generated renderer using ggen_igniter."""
    build = build_dir.resolve()
    pack = _pack_dir(pack_dir, build)
    ontology = _materialize_ontology(build)
    generated = build / "generated"
    _sync_template(pack, ontology, "deck.json.eex", generated / "deck.json", build)
    for i, template in enumerate(RENDER_PARTS):
        _sync_template(pack, ontology, template, generated / f"render.part{i}.mjs", build)
    renderer = _assemble_renderer(build)
    typer.echo(json.dumps({
        "ontology": str(ontology), "ontology_sources": [str(p) for p in _ontology_sources()], "pack": str(pack), "deck": str(generated / "deck.json"),
        "renderer": str(renderer), "marketplace_commit": MARKETPLACE_COMMIT,
    }, indent=2))


@app.command()
def render(
    audience: Annotated[Audience, typer.Option()] = "all",
    output: Annotated[Path, typer.Option()] = DEFAULT_OUT,
    pack_dir: Annotated[Path | None, typer.Option(help="Local pptx-presentation-pack directory.")] = None,
    build_dir: Annotated[Path, typer.Option()] = DEFAULT_BUILD,
) -> None:
    """Regenerate the PowerPoint and speaker notes from the semantic deck ontology."""
    _assert_runtime()
    build = build_dir.resolve()
    sync(pack_dir=pack_dir, build_dir=build)
    generated = build / "generated"
    out = output.resolve()
    env = os.environ.copy()
    env["NODE_PATH"] = str(THIS_DIR / "node_modules")
    _run(["node", str(generated / "render.mjs"), "--spec", str(generated / "deck.json"), "--out", str(out), "--audience", audience], env=env)
    _verify(out, generated / "deck.json", audience, build / "receipt.json")


@app.command()
def verify(
    pptx: Annotated[Path, typer.Option()] = DEFAULT_OUT,
    audience: Annotated[Audience, typer.Option()] = "all",
    spec: Annotated[Path, typer.Option(help="Generated deck.json to verify against.")] = DEFAULT_BUILD / "generated/deck.json",
    receipt: Annotated[Path, typer.Option()] = DEFAULT_BUILD / "receipt.json",
) -> None:
    """Verify slide count, titles, speaker notes, hashes and evidence ceiling from OOXML."""
    _verify(pptx.resolve(), spec.resolve(), audience, receipt.resolve())


@app.command(name="inspect")
def inspect_deck(
    spec: Annotated[Path, typer.Option()] = DEFAULT_BUILD / "generated/deck.json",
    audience: Annotated[Audience, typer.Option()] = "all",
) -> None:
    """Print the generated semantic projection used by the renderer."""
    data = json.loads(spec.read_text())
    for s in _slides_for(data, audience):
        typer.echo(f"{int(s['order']):02d} [{s.get('audience','interview')}] {s['layout']}: {s['title'].replace(chr(10),' / ')}")


@app.command()
def materialize(
    dest: Annotated[Path, typer.Option(help="Directory to extract packs/<pack> into.")] = REPO_ROOT / "tmp/ggen-marketplace-pinned",
    marketplace: Annotated[Path, typer.Option(help="Local ggen-marketplace git repository.")] = REPO_ROOT.parent / "ggen-marketplace",
) -> None:
    """Extract the pinned pack with `git archive` (no second checkout) and mark its commit."""
    repo = marketplace.expanduser().resolve()
    probe = subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{MARKETPLACE_COMMIT}^{{commit}}"], capture_output=True)
    if probe.returncode != 0:
        _run(["git", "-C", str(repo), "fetch", "origin", MARKETPLACE_COMMIT])
    out = dest.expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    archive = subprocess.run(
        ["git", "-C", str(repo), "archive", MARKETPLACE_COMMIT, f"packs/{PACK_NAME}"], capture_output=True, check=True
    ).stdout
    subprocess.run(["tar", "-x", "-C", str(out)], input=archive, check=True)
    pack = out / "packs" / PACK_NAME
    expected = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", MARKETPLACE_COMMIT, f"packs/{PACK_NAME}"], text=True, capture_output=True, check=True
    ).stdout.split("\n")
    expected_blobs = sorted(line.split()[2] + "  " + line.split("\t", 1)[1] for line in expected if line.strip())
    observed_blobs = []
    for f in sorted(p for p in pack.rglob("*") if p.is_file() and p.name != ".marketplace-commit"):
        blob = subprocess.run(["git", "hash-object", str(f)], text=True, capture_output=True, check=True).stdout.strip()
        observed_blobs.append(f"{blob}  {f.relative_to(out)}")
    if sorted(observed_blobs) != expected_blobs:
        typer.echo("REFUSED:PACK_TREE_MISMATCH", err=True)
        raise typer.Exit(8)
    (pack / ".marketplace-commit").write_text(MARKETPLACE_COMMIT + "\n", encoding="utf-8")
    typer.echo(json.dumps({"pack": str(pack), "marketplace_commit": MARKETPLACE_COMMIT, "files": len(observed_blobs)}, indent=2))


# ---------------------------------------------------------------- case study

SEMANTIC_PACK = REPO_ROOT / "priv/packs/wd_cs2_pack"
CASE_STUDY_PACK = REPO_ROOT / "priv/packs/wd_cs2_case_study_pack"
CASE_STUDY_DIR = REPO_ROOT / "docs/case-studies/wd-fa"
CASE_STUDY_SOURCES = ("case-study.ttl", "claims.ttl", "stogaf-core.ttl")
CASE_STUDY_PROJECTIONS = (
    ("case-study.json.eex", "case-study.json"),
    ("claims-ledger.json.eex", "claims-ledger.json"),
    ("slide-evidence-map.json.eex", "SLIDE-EVIDENCE-MAP.json"),
)
CASE_NS = "urn:xaas:case-study:"


def _case_sources() -> list[Path]:
    sources = [SEMANTIC_PACK / name for name in CASE_STUDY_SOURCES] + _ontology_sources()
    missing = [str(p) for p in sources if not p.is_file()]
    if missing:
        typer.echo("BLOCKED:CASE_SOURCES_MISSING: " + ", ".join(missing), err=True)
        raise typer.Exit(3)
    return sources


def _case_revision(sources: list[Path]) -> tuple[str, str]:
    """(case IRI, sha256 of the canonical sorted N-Triples of the case sources)."""
    try:
        from rdflib import Graph, RDF, URIRef
        from rdflib.compare import to_canonical_graph
    except ImportError:
        typer.echo("BLOCKED:RDFLIB_MISSING: pip install 'rdflib>=7,<8'", err=True)
        raise typer.Exit(5)
    graph = Graph()
    for path in sources:
        graph.parse(path, format="turtle")
    cases = sorted(str(c) for c in graph.subjects(RDF.type, URIRef(CASE_NS + "CaseStudy")))
    if len(cases) != 1:
        typer.echo(f"REFUSED:CASE_STUDY_CARDINALITY: {cases}", err=True)
        raise typer.Exit(4)
    lines = sorted(
        line for line in to_canonical_graph(graph).serialize(format="nt").splitlines() if line.strip()
    )
    return cases[0], hashlib.sha256(("\n".join(lines) + "\n").encode("utf-8")).hexdigest()


def _generator_identity() -> str:
    lock = (REPO_ROOT / "mix.lock").read_text(encoding="utf-8")
    match = re.search(r'"ggen_igniter": \{:hex, :ggen_igniter, "([^"]+)"', lock)
    version = match.group(1) if match else "UNKNOWN"
    h = hashlib.sha256()
    for path in sorted(p for p in CASE_STUDY_PACK.rglob("*") if p.is_file()):
        h.update(str(path.relative_to(CASE_STUDY_PACK)).encode("utf-8") + b"\0")
        h.update(path.read_bytes() + b"\0")
    return f"ggen_igniter@{version}+engine=sparql;wd_cs2_case_study_pack=sha256:{h.hexdigest()}"


@app.command(name="case-study")
def case_study(
    check: Annotated[bool, typer.Option("--check", help="Regenerate into the build dir and byte-compare with committed projections.")] = False,
    build_dir: Annotated[Path, typer.Option()] = REPO_ROOT / "tmp/wd-case-study",
) -> None:
    """Project claims.ttl + deck TTL into case-study.json, claims-ledger.json and SLIDE-EVIDENCE-MAP.json."""
    build = build_dir.resolve()
    generated = build / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    sources = _case_sources()
    case_iri, digest = _case_revision(sources)
    identity = _generator_identity()
    revision = generated / "revision.ttl"
    revision.write_text(
        f"@prefix cs: <{CASE_NS}> .\n\n<{case_iri}> cs:caseRevisionDigest \"{digest}\" ;\n"
        f"  cs:generatorIdentity \"{identity}\" .\n",
        encoding="utf-8",
    )
    ontology = generated / "case.ttl"
    ontology.write_text("\n".join(p.read_text(encoding="utf-8") for p in sources + [revision]), encoding="utf-8")

    drift: list[str] = []
    outputs: dict[str, str] = {}
    for template, name in CASE_STUDY_PROJECTIONS:
        out = generated / name
        _run([
            "mix", "ggen_igniter.sync",
            "--engine", "sparql",
            "--pack-dir", str(CASE_STUDY_PACK),
            "--ontology", str(ontology),
            "--template", str(CASE_STUDY_PACK / "templates" / template),
            "--out", str(out),
        ])
        data = out.read_bytes()
        if not data.endswith(b"\n"):
            data += b"\n"
            out.write_bytes(data)
        json.loads(data)
        committed = CASE_STUDY_DIR / name
        outputs[name] = hashlib.sha256(data).hexdigest()
        if check:
            if not committed.is_file() or committed.read_bytes() != data:
                drift.append(name)
        else:
            committed.write_bytes(data)

    report = {
        "case_iri": case_iri,
        "case_revision_digest": digest,
        "generator_identity": identity,
        "projections_sha256": outputs,
        "mode": "check" if check else "write",
        "drift": drift,
    }
    typer.echo(json.dumps(report, indent=2, sort_keys=True))
    if drift:
        typer.echo("REFUSED:PROJECTION_DRIFT: " + ", ".join(drift), err=True)
        raise typer.Exit(9)


if __name__ == "__main__":
    app()
