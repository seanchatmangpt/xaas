"""Single-source court for the WD deck marketplace subject.

tools/wd_deck/wd_deck.py MARKETPLACE_COMMIT is the only place the
ggen-marketplace pptx-presentation-pack subject is pinned; the deck workflow
derives MARKETPLACE_SHA from it. Real files on disk, no doubles.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WD_DECK = ROOT / "tools" / "wd_deck" / "wd_deck.py"
WORKFLOW = ROOT / ".github" / "workflows" / "wd-deck-generation.yml"

# Transient PR heads / the stale subject whose render.part2 ended "await pptx.w".
NON_DURABLE = {
    "76774bbaf83ec92e6e52b81ceb6a165b00de8b93",
    "69e7f6b256158dc0ad4dd5af7e5807279de6bba2",
}
PIN = re.compile(r'^MARKETPLACE_COMMIT = "([0-9a-f]{40})"$', re.MULTILINE)


def _pinned() -> str:
    found = PIN.findall(WD_DECK.read_text(encoding="utf-8"))
    assert len(found) == 1, found
    return found[0]


def test_wd_deck_pins_a_durable_marketplace_subject() -> None:
    assert _pinned() not in NON_DURABLE


def test_workflow_derives_marketplace_sha_from_wd_deck() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    assert re.search(r"MARKETPLACE_SHA:\s*[0-9a-f]{7,40}", workflow) is None
    for sha in NON_DURABLE:
        assert sha not in workflow
    assert "tools/wd_deck/wd_deck.py" in workflow
    assert 'echo "MARKETPLACE_SHA=$sha" >> "$GITHUB_ENV"' in workflow


def test_workflow_derivation_step_extracts_the_pin() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    line = next(l for l in workflow.splitlines() if "sed -nE" in l and "MARKETPLACE_COMMIT" in l)
    command = line.strip().removeprefix('sha="$(').removesuffix(')"')
    result = subprocess.run(
        ["bash", "-c", command], cwd=ROOT, check=True, capture_output=True, text=True
    )
    assert result.stdout.strip() == _pinned()


def _load_wd_deck():
    import importlib.util

    spec = importlib.util.spec_from_file_location("wd_deck_under_test", WD_DECK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _fake_free_pack(root: Path, marker: str | None) -> Path:
    """A real on-disk pack directory (pack.toml + ontology.ttl), outside any git repo."""
    pack = root / "packs" / "pptx-presentation-pack"
    pack.mkdir(parents=True)
    (pack / "pack.toml").write_text("[pack]\nname = \"pptx-presentation-pack\"\n", encoding="utf-8")
    (pack / "ontology.ttl").write_text("", encoding="utf-8")
    if marker is not None:
        (pack / ".marketplace-commit").write_text(marker + "\n", encoding="utf-8")
    return pack


def test_pack_dir_admits_a_pack_marked_with_the_pinned_commit(tmp_path: Path) -> None:
    wd_deck = _load_wd_deck()
    pack = _fake_free_pack(tmp_path, _pinned())
    assert wd_deck._pack_dir(pack, tmp_path) == pack.resolve()


def test_pack_dir_refuses_commit_drift(tmp_path: Path, capsys) -> None:
    import typer

    wd_deck = _load_wd_deck()
    pack = _fake_free_pack(tmp_path, "0" * 40)
    try:
        wd_deck._pack_dir(pack, tmp_path)
    except typer.Exit as exit_:
        assert exit_.exit_code == 8
    else:
        raise AssertionError("drifted pack admitted")
    assert "REFUSED:PACK_COMMIT_DRIFT" in capsys.readouterr().err


def test_pack_dir_refuses_an_unmarked_pack_outside_git(tmp_path: Path, capsys) -> None:
    import typer

    wd_deck = _load_wd_deck()
    pack = _fake_free_pack(tmp_path, None)
    try:
        wd_deck._pack_dir(pack, tmp_path)
    except typer.Exit as exit_:
        assert exit_.exit_code == 8
    else:
        raise AssertionError("unmarked pack admitted")
    assert "observed UNKNOWN" in capsys.readouterr().err
