"""Chicago-style tests for scripts/sjira/prose_spans.py.

Every test runs the real script as a subprocess over real files in a fresh
temporary directory and asserts on its real exit code, stdout and the bytes it
wrote. No collaborator is faked. Run from the xaas root:

    python3 -m unittest discover -s scripts/sjira -p 'test_*.py' -v
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "prose_spans.py"
REPO = HERE.parent.parent

# Non-ASCII before the quotes on purpose: offsets must be UTF-8 byte offsets.
PROSE = """# Future — prose

The gate “GC23-0” shall admit a complete semantic projection.

The runner shall refuse a mutated tuple digest.

Twice: the court repeats. Twice: the court repeats.

Bootstrap reconstructs state without chat.
"""

EXTRACT = [
    {
        "kind": "Postcondition",
        "statement": "GC23-0 admits a complete semantic projection.",
        "quote": "shall admit a complete semantic projection.",
        "required_by": "GC23-0",
        "boundary_class": "FirstMile",
        "hints": {
            "postcondition": "complete admitted projection exists",
            "acceptance": "check exits 0",
            "falsifier": ["delete the only GC23-0 candidate", "mutate one byte"],
        },
    },
    {
        "kind": "Falsifier",
        "statement": "A mutated tuple digest is refused.",
        "quote": "The runner shall refuse a mutated tuple digest.",
        "required_by": ["GC23-1"],
        "boundary_class": "Core",
    },
    {
        "kind": "Invariant",
        "statement": "The court repeats.",
        "quote": "Twice: the court repeats.",
        "occurrence": 2,
        "boundary_class": "Successor",
    },
    {
        "kind": "Postcondition",
        "statement": "Bootstrap reconstructs state without chat.",
        "quote": "Bootstrap reconstructs state without chat.",
        "required_by": "GC23-1",
        "boundary_class": "Bootstrap",
    },
]


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, check=False)


class ProseSpansTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.source = self.dir / "docs" / "prose.md"
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(PROSE.encode("utf-8"))
        self.extract = self.dir / "extract.json"
        self.write_extract(EXTRACT)
        self.ttl = self.dir / "out" / "candidates.ttl"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write_extract(self, items: list, path: Path | None = None) -> Path:
        path = path or self.extract
        path.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
        return path

    def emit(self, extract: Path | None = None, out: Path | None = None) -> subprocess.CompletedProcess:
        return run(
            "emit",
            "--source",
            str(self.source),
            "--extract",
            str(extract or self.extract),
            "--out",
            str(out or self.ttl),
            "--source-path",
            "docs/prose.md",
            "--extracted-by",
            "llm:test@unit",
        )

    def check(self, *extra: str) -> subprocess.CompletedProcess:
        return run("check", "--source", str(self.source), "--candidates", str(self.ttl), "--require-gates", "2", *extra)

    def emitted(self) -> str:
        result = self.emit()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return self.ttl.read_text(encoding="utf-8")

    def assert_refused(self, result: subprocess.CompletedProcess, code: str) -> None:
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertRegex(result.stdout, rf"REFUSED [^\n]*: {code}: ")

    # ── emit ────────────────────────────────────────────────────────────────

    def test_emit_then_check_passes_with_byte_offsets(self) -> None:
        text = self.emitted()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("CHECK OK: 4 candidates", result.stdout)
        self.assertIn("GC23-0=1 GC23-1=2", result.stdout)
        data = PROSE.encode("utf-8")
        quote = "shall admit a complete semantic projection.".encode("utf-8")
        start = data.find(quote)
        self.assertNotEqual(start, PROSE.find("shall admit"), "fixture must make byte and char offsets differ")
        self.assertIn(f"sj:sourceStart {start} ;", text)
        self.assertIn(f"sj:sourceEnd {start + len(quote)} ;", text)
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        local = "P-" + hashlib.sha256(f"{digest}:{start}:{start + len(quote)}:Postcondition".encode()).hexdigest()[:16]
        self.assertIn(f"v23:{local} a sj:Proposition ;", text)
        self.assertIn(f'sj:sourceSha256 "{digest}" ;', text)
        self.assertIn('sj:candidateStanding "UNKNOWN" ;', text)
        self.assertIn('sj:extractedBy "llm:test@unit" .', text)
        self.assertIn(f"v23:{local}-falsifier-2 a sj:Falsifier ;", text)

    def test_emit_is_byte_identical_and_order_independent(self) -> None:
        first = self.emitted().encode("utf-8")
        second_out = self.dir / "again.ttl"
        self.assertEqual(self.emit(out=second_out).returncode, 0)
        self.assertEqual(first, second_out.read_bytes())
        # Same items in reverse order and different JSON whitespace: only the
        # extraction digest comment may differ; every candidate block is equal.
        reordered = self.dir / "reordered.json"
        reordered.write_text(json.dumps(list(reversed(EXTRACT)), ensure_ascii=False), encoding="utf-8")
        third_out = self.dir / "reordered.ttl"
        self.assertEqual(self.emit(extract=reordered, out=third_out).returncode, 0)
        strip = lambda b: re.sub(rb"# extraction: sha256:[0-9a-f]{64}", b"", b)  # noqa: E731
        self.assertEqual(strip(first), strip(third_out.read_bytes()))
        starts = [int(m) for m in re.findall(r"sj:sourceStart (\d+) ;", first.decode("utf-8"))]
        self.assertEqual(starts, sorted(starts))

    def test_quote_with_two_occurrences_needs_an_index(self) -> None:
        items = [dict(EXTRACT[2])]
        del items[0]["occurrence"]
        result = self.emit(extract=self.write_extract(items))
        self.assert_refused(result, "quote_ambiguous")
        self.assertIn("2 matches", result.stdout)
        self.assertFalse(self.ttl.exists(), "a refused emit must not write output")
        items[0]["occurrence"] = 2
        self.assertEqual(self.emit(extract=self.write_extract(items)).returncode, 0)
        data = PROSE.encode("utf-8")
        needle = b"Twice: the court repeats."
        second = data.find(needle, data.find(needle) + 1)
        self.assertIn(f"sj:sourceStart {second} ;", self.ttl.read_text(encoding="utf-8"))
        items[0]["occurrence"] = 3
        self.assert_refused(self.emit(extract=self.write_extract(items)), "occurrence_out_of_range")

    def test_emit_refuses_missing_quote_bad_kind_and_unknown_key(self) -> None:
        items = [
            dict(EXTRACT[0], quote="this sentence is not in the prose"),
            dict(EXTRACT[1], kind="Wish"),
            dict(EXTRACT[3], requiredBy="GC23-1"),
            dict(EXTRACT[3], boundary_class="Middle", quote="Bootstrap"),
        ]
        result = self.emit(extract=self.write_extract(items))
        self.assertEqual(result.returncode, 1)
        for code in ("quote_not_found", "kind_invalid", "item_unknown_key", "boundary_class_invalid"):
            self.assertIn(f": {code}: ", result.stdout)
        self.assertFalse(self.ttl.exists())

    def test_emit_refuses_duplicate_span_and_kind(self) -> None:
        result = self.emit(extract=self.write_extract([EXTRACT[1], dict(EXTRACT[1], statement="Again.")]))
        self.assert_refused(result, "duplicate_candidate")

    # ── check: each single mutation is refused and named ────────────────────

    def test_one_source_byte_mutated_is_refused(self) -> None:
        self.emitted()
        data = bytearray(self.source.read_bytes())
        at = data.find(b"refuse a mutated")
        data[at] = ord("R")
        self.source.write_bytes(bytes(data))
        result = self.check()
        self.assert_refused(result, "source_sha256_mismatch")
        self.assert_refused(result, "source_text_mismatch")

    def test_one_source_text_mutated_is_refused(self) -> None:
        text = self.emitted()
        self.ttl.write_text(
            text.replace('sj:sourceText "Bootstrap reconstructs', 'sj:sourceText "Bootstrap rebuilds', 1),
            encoding="utf-8",
        )
        self.assert_refused(self.check(), "source_text_mismatch")

    def test_one_offset_mutated_is_refused(self) -> None:
        text = self.emitted()
        start = int(re.search(r"sj:sourceStart (\d+) ;", text).group(1))
        self.ttl.write_text(
            text.replace(f"sj:sourceStart {start} ;", f"sj:sourceStart {start + 1} ;", 1), encoding="utf-8"
        )
        result = self.check()
        self.assert_refused(result, "source_text_mismatch")
        self.assert_refused(result, "iri_mismatch")

    def test_one_kind_mutated_is_refused(self) -> None:
        text = self.emitted()
        swapped = self.dir / "swapped.ttl"
        swapped.write_text(
            text.replace('sj:propositionKind "Falsifier"', 'sj:propositionKind "Invariant"', 1), encoding="utf-8"
        )
        self.ttl.write_text(
            text.replace('sj:propositionKind "Falsifier"', 'sj:propositionKind "Wish"', 1), encoding="utf-8"
        )
        self.assert_refused(self.check(), "kind_invalid")
        self.ttl.write_bytes(swapped.read_bytes())
        self.assert_refused(self.check(), "iri_mismatch")

    def test_deleting_only_candidate_for_required_gate_is_refused(self) -> None:
        text = self.emitted()
        blocks = text.split("\n\n")
        kept = [
            b
            for b in blocks
            if "sj:requiredBy v23:GC23-0" not in b and "-acceptance-1 a" not in b and "-falsifier-" not in b
        ]
        self.assertEqual(len(blocks) - len(kept), 4, "the GC23-0 candidate and its 3 hint nodes")
        self.ttl.write_text("\n\n".join(kept), encoding="utf-8")
        result = self.check()
        self.assert_refused(result, "gate_uncovered")
        self.assertIn("REFUSED https://ggen-igniter.dev/sjira/v26.9.23#GC23-0: gate_uncovered", result.stdout)
        self.assertEqual(run("check", "--source", str(self.source), "--candidates", str(self.ttl)).returncode, 0)

    def test_boundary_standing_and_stray_triples_are_refused(self) -> None:
        text = self.emitted()
        self.ttl.write_text(text.replace("sj:boundaryClass sj:Core", "sj:boundaryClass sj:Middle", 1), encoding="utf-8")
        self.assert_refused(self.check(), "boundary_class_invalid")
        # The header comment also names sj:candidateStanding; mutate the triple, not the comment.
        self.assertIn('    sj:candidateStanding "UNKNOWN" ;', text)
        self.ttl.write_text(
            text.replace('    sj:candidateStanding "UNKNOWN" ;', '    sj:candidateStanding "ALIVE" ;', 1),
            encoding="utf-8",
        )
        self.assert_refused(self.check(), "candidate_standing_invalid")
        self.ttl.write_text(text + '\nv23:extra sj:standing "ALIVE" .\n', encoding="utf-8")
        self.assert_refused(self.check(), "stray_subject")
        self.ttl.write_text(
            text.replace(" a sj:Proposition ;", ' a sj:Proposition ;\n    sj:standing "ALIVE" ;', 1), encoding="utf-8"
        )
        self.assert_refused(self.check(), "unknown_predicate")

    def test_statement_edit_is_projection_drift(self) -> None:
        text = self.emitted()
        self.assertEqual(self.check("--extract", str(self.extract)).returncode, 0)
        self.ttl.write_text(text.replace("A mutated tuple digest is refused.", "Anything goes.", 1), encoding="utf-8")
        self.assertEqual(self.check().returncode, 0, "statement is not span-bound; only re-emit sees it")
        self.assert_refused(self.check("--extract", str(self.extract)), "projection_drift")

    # ── check --summary: receipt numbers come from the checked artifact ─────

    def summary(self, *extra: str) -> tuple[subprocess.CompletedProcess, dict]:
        path = self.dir / "summary.json"
        result = self.check("--summary", str(path), *extra)
        return result, json.loads(path.read_text(encoding="utf-8"))

    def test_summary_tallies_verified_candidates(self) -> None:
        self.emitted()
        result, summary = self.summary()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(summary["check"], "OK")
        self.assertEqual(summary["candidates"], 4)
        self.assertEqual(summary["verified"], 4)
        self.assertEqual(summary["kinds"], {"Falsifier": 1, "Invariant": 1, "Postcondition": 2})
        self.assertEqual(summary["required_by"], {"GC23-0": 1, "GC23-1": 2})
        self.assertEqual((summary["required"], summary["not_required"], summary["multi_required"]), (3, 1, 0))
        self.assertEqual(summary["candidates_sha256"], "sha256:" + hashlib.sha256(self.ttl.read_bytes()).hexdigest())
        self.assertIn(
            "TALLY: required 3 + not_required 1 = 4 (multi_required 0); requiredBy GC23-0=1 GC23-1=2", result.stdout
        )
        # A candidate required by the gate and by the root counts once per target, once in `required`.
        items = [dict(EXTRACT[0], required_by=["GC23-0", "GC-26.9.23"]), *EXTRACT[1:]]
        self.assertEqual(self.emit(extract=self.write_extract(items)).returncode, 0)
        result, summary = self.summary()
        self.assertEqual(summary["required_by"], {"GC-26.9.23": 1, "GC23-0": 1, "GC23-1": 2})
        self.assertEqual((summary["required"], summary["not_required"], summary["multi_required"]), (3, 1, 1))
        # Summary bytes are a pure function of the checked inputs.
        first = (self.dir / "summary.json").read_bytes()
        self.summary()
        self.assertEqual(first, (self.dir / "summary.json").read_bytes())

    def test_summary_of_a_refused_graph_says_failed(self) -> None:
        text = self.emitted()
        self.ttl.write_text(
            text.replace('sj:propositionKind "Falsifier"', 'sj:propositionKind "Wish"', 1), encoding="utf-8"
        )
        result, summary = self.summary()
        self.assert_refused(result, "kind_invalid")
        self.assertEqual((summary["check"], summary["candidates"], summary["verified"]), ("FAILED", 4, 3))
        self.assertEqual(summary["required_by"], {"GC23-0": 1, "GC23-1": 1})
        self.assertGreater(summary["refusals"], 0)

    # ── the committed v26.9.23 artifacts ───────────────────────────────────

    def test_committed_prd_ard_candidates_verify_and_reproject(self) -> None:
        source = REPO / "docs/sjira/v26.9.23/prd-ard.md"
        ttl = REPO / "docs/sjira/v26.9.23/candidates/prd-ard.ttl"
        extract = REPO / "docs/sjira/v26.9.23/candidates/prd-ard.extract.json"
        self.assertEqual(
            hashlib.sha256(source.read_bytes()).hexdigest(),
            "7c8797b2bc9130fc4c8fce9138cc8140cb704e0633715807398451c660658212",
            "the accepted prose is byte-identical to the operator text",
        )
        result = run(
            "check",
            "--source",
            str(source),
            "--candidates",
            str(ttl),
            "--require-gates",
            "13",
            "--extract",
            str(extract),
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        out = self.dir / "prd-ard.ttl"
        emitted = run(
            "emit",
            "--source",
            str(source),
            "--extract",
            str(extract),
            "--out",
            str(out),
            "--source-path",
            "docs/sjira/v26.9.23/prd-ard.md",
            "--extracted-by",
            "llm:claude-opus-5-5@wave-B0/V23-X",
        )
        self.assertEqual(emitted.returncode, 0, emitted.stdout)
        self.assertEqual(out.read_bytes(), ttl.read_bytes())
        # The tally agrees with a count taken straight from the extraction JSON (the receipt's
        # extraction numbers are copied from this summary, never typed).
        summary_path = self.dir / "prd-ard.summary.json"
        tallied = run("check", "--source", str(source), "--candidates", str(ttl), "--summary", str(summary_path))
        self.assertEqual(tallied.returncode, 0, tallied.stdout)
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        items = json.loads(extract.read_text(encoding="utf-8"))
        targets: dict[str, int] = {}
        for item in items:
            rb = item.get("required_by")
            for t in [rb] if isinstance(rb, str) else rb or []:
                targets[t] = targets.get(t, 0) + 1
        self.assertEqual(summary["required_by"], targets)
        self.assertEqual(summary["not_required"], sum(1 for i in items if not i.get("required_by")))
        self.assertEqual(summary["required"] + summary["not_required"], summary["candidates"])
        self.assertEqual(summary["candidates"], len(items))


if __name__ == "__main__":
    unittest.main()
