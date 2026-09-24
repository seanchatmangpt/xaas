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
MARKETPLACE_COMMIT = "76774bbaf83ec92e6e52b81ceb6a165b00de8b93"
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
            return p

    typer.echo(
        "BLOCKED:PACK_NOT_MATERIALIZED: provide --pack-dir, set GGEN_PPTX_PACK_DIR, "
        "or checkout ggen-marketplace as a sibling at the pinned commit",
        err=True,
    )
    raise typer.Exit(3)



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

    receipt = {
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
            "slide count differs", "expected title absent", "expected speaker notes absent"
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


if __name__ == "__main__":
    app()
