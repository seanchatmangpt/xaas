"""Chicago-style tests for scripts/sjira/wd_claims.py (lane V23-W).

Every test builds a real git repository in a fresh temporary directory, writes
real receipt JSON bound to a real commit of that repository, runs the real
script as a subprocess (which itself runs the real fleet receipt validator,
~/.claude/dfcm/validate_receipt.py or $DFCM_VALIDATOR, as a subprocess) and
asserts on the real exit code, stdout and written bytes. No collaborator is
faked; when the validator is absent the tests skip visibly. Run from the xaas
root:

    python3 -m unittest discover -s scripts/sjira -p 'test_*.py' -v
"""

from __future__ import annotations

import hashlib
import json
import os
import site
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "wd_claims.py"
REPO = HERE.parent.parent
VALIDATOR = Path(os.environ.get("DFCM_VALIDATOR") or Path.home() / ".claude" / "dfcm" / "validate_receipt.py")

SUPPLIED_TEXT = "FA\nCASE STUDY 2\nOne product family, one site, English corpus\nCurrent MTTR by mode, and how it is measured\n"

LEDGER = """@prefix wdc: <https://ggen-igniter.dev/sjira/v26.9.23/wd-fa/claims#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

wdc:proposal a wdc:Proposal ;
    dcterms:title "Fixture proposal" ;
    wdc:status "Status: DRAFT." .

wdc:S01 a wdc:Section ;
    wdc:order 1 ;
    rdfs:label "Problem" ;
    wdc:body \"\"\"Plain framing without figures. {C1} {C2}

- {C3}
- {C4}\"\"\" .

wdc:S02 a wdc:Section ;
    wdc:order 2 ;
    rdfs:label "Unknowns" ;
    wdc:body \"\"\"{C5} Everything else waits for the operator.\"\"\" .

wdc:MI-mttr a wdc:MissingInput ;
    rdfs:label "MTTR baseline by failure mode" ;
    wdc:guardPattern "\\\\bMTTR\\\\b" .

wdc:C1 a wdc:Claim ;
    dcterms:identifier "C1" ;
    wdc:sentence "The supplied brief scopes phase one to one product family at one site." ;
    wdc:claimClass wdc:SUPPLIED ;
    wdc:evidenceKind "supplied-input" ;
    wdc:receipt "receipts/supply.json" ;
    wdc:suppliedSource "supplied/text.txt" ;
    wdc:quote "One product family, one site, English corpus" ;
    wdc:classifiedBy "test" .

wdc:C2 a wdc:Claim ;
    dcterms:identifier "C2" ;
    wdc:sentence "The reference kernel run on commit abc passed 10 of 10 checks." ;
    wdc:claimClass wdc:SUPPLIED ;
    wdc:evidenceKind "observed-proof" ;
    wdc:receipt "receipts/proof.json" ;
    wdc:classifiedBy "test" .

wdc:C3 a wdc:Claim ;
    dcterms:identifier "C3" ;
    wdc:sentence "Pull request 170 was merged publicly." ;
    wdc:claimClass wdc:PUBLICLY_OBSERVABLE ;
    wdc:publicRef "https://github.com/example/repo/pull/170" ;
    wdc:classifiedBy "test" .

wdc:C4 a wdc:Claim ;
    dcterms:identifier "C4" ;
    wdc:sentence "The same admission rule will apply to real cases." ;
    wdc:claimClass wdc:ARCHITECTURAL_INFERENCE ;
    wdc:premise wdc:C2, wdc:C3 ;
    wdc:reasoning "C2 observes the rule; C3 shows it is public; the rule is data-independent." ;
    wdc:classifiedBy "test" .

wdc:C5 a wdc:Claim ;
    dcterms:identifier "C5" ;
    wdc:sentence "The current MTTR on known modes is not known to us." ;
    wdc:claimClass wdc:WD_DEPENDENT_UNKNOWN ;
    wdc:missingInput wdc:MI-mttr ;
    wdc:classifiedBy "test" .
"""


def git(cwd: Path, *args: str) -> str:
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True, env=env).stdout.strip()


def receipt(repo: Path, sha: str, standing: str, extra: dict | None = None) -> dict:
    body = {
        "identity": {"subject": "fixture", "repo": repo.as_posix(), "subject_sha": sha, "base_sha": sha},
        "authority": {"ceiling": "OBSERVE", "grant": "NONE", "actor": "test"},
        "consequence": {"commits": [], "files_changed": [], "remote_effects": []},
        "replay": {"commands": [{"cmd": "true", "exit": 0, "cwd": repo.as_posix()}]},
        "standing": {"value": standing, "derived_from": "test fixture"},
    }
    body.update(extra or {})
    return body


@unittest.skipUnless(VALIDATOR.is_file(), f"fleet receipt validator absent at {VALIDATOR}")
class WdClaimsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "repo"
        self.root.mkdir()
        git(self.root, "init", "-q")
        (self.root / "supplied").mkdir()
        (self.root / "supplied" / "text.txt").write_text(SUPPLIED_TEXT, encoding="utf-8")
        git(self.root, "add", ".")
        git(self.root, "commit", "-q", "-m", "fixture")
        self.sha = git(self.root, "rev-parse", "HEAD")
        digest = "sha256:" + hashlib.sha256(SUPPLIED_TEXT.encode("utf-8")).hexdigest()
        (self.root / "receipts").mkdir()
        self.write_receipt("supply.json", receipt(self.root, self.sha, "ALIVE", {"supplied": {"supplied/text.txt": digest}}))
        self.write_receipt("proof.json", receipt(self.root, self.sha, "ALIVE"))
        self.write_receipt("partial.json", receipt(self.root, self.sha, "PARTIAL_ALIVE"))
        bad = receipt(self.root, self.sha, "ALIVE")
        del bad["authority"]
        self.write_receipt("bad.json", bad)
        self.write_receipt("unbound.json", receipt(self.root, self.sha, "ALIVE"))
        self.ledger = self.root / "claims.ttl"
        self.proposal = self.root / "proposal.md"
        self.write_ledger(LEDGER)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write_receipt(self, name: str, body: dict) -> None:
        (self.root / "receipts" / name).write_text(json.dumps(body, indent=1), encoding="utf-8")

    def write_ledger(self, text: str) -> None:
        self.ledger.write_text(text, encoding="utf-8")

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, SCRIPT.as_posix(), *args],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            env=dict(os.environ, DFCM_VALIDATOR=VALIDATOR.as_posix()),
        )

    def render(self) -> subprocess.CompletedProcess:
        return self.run_script("render", "--ledger", self.ledger.as_posix(), "--out", self.proposal.as_posix())

    def check(self, *extra: str) -> subprocess.CompletedProcess:
        return self.run_script(
            "check", "--ledger", self.ledger.as_posix(), "--proposal", self.proposal.as_posix(), *extra
        )

    def codes(self, proc: subprocess.CompletedProcess) -> set[str]:
        return {line.split(": ")[1] for line in proc.stdout.splitlines() if line.startswith("REFUSED ")}

    def refused_with(self, code: str) -> subprocess.CompletedProcess:
        proc = self.check()
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn(code, self.codes(proc), proc.stdout)
        return proc

    # -- admitted ledger --------------------------------------------------

    def test_render_then_check_admits_and_is_byte_stable(self) -> None:
        first = self.render()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        bytes_one = self.proposal.read_bytes()
        self.assertEqual(self.render().returncode, 0)
        self.assertEqual(self.proposal.read_bytes(), bytes_one)
        text = bytes_one.decode("utf-8")
        self.assertIn("The reference kernel run on commit abc passed 10 of 10 checks [C2].", text)
        self.assertIn("- Pull request 170 was merged publicly [C3].", text)
        summary = self.root / "summary.json"
        proc = self.check("--summary", summary.as_posix())
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("CHECK OK: 5 claims", proc.stdout)
        tally = json.loads(summary.read_text(encoding="utf-8"))
        self.assertEqual(tally["classes"], {"SUPPLIED": 2, "PUBLICLY_OBSERVABLE": 1, "ARCHITECTURAL_INFERENCE": 1, "WD_DEPENDENT_UNKNOWN": 1})
        self.assertEqual(tally["supplied_evidence_kinds"], {"supplied-input": 1, "observed-proof": 1})
        self.assertEqual(tally["receipts_admitted"], 2)
        self.assertEqual(tally["referenced_claims"], 5)

    # -- proposal-side refusals ------------------------------------------

    def test_hand_edit_of_the_projection_is_refused(self) -> None:
        self.render()
        text = self.proposal.read_text(encoding="utf-8")
        self.proposal.write_text(text.replace("Plain framing", "Plainer framing"), encoding="utf-8")
        self.refused_with("projection_drift")

    def test_unmarked_number_or_claim_verb_sentence_is_refused(self) -> None:
        self.render()
        text = self.proposal.read_text(encoding="utf-8")
        for added in ("The pilot takes 90 days.", "The assistant will be faster.", "This is proven already."):
            with self.subTest(added=added):
                self.proposal.write_text(text.replace("Plain framing without figures.", added), encoding="utf-8")
                proc = self.refused_with("unmarked_claim_sentence")
                self.assertIn(added[:12], proc.stdout)

    def test_unresolved_malformed_and_double_markers_are_refused(self) -> None:
        self.render()
        text = self.proposal.read_text(encoding="utf-8")
        cases = {
            "marker_unresolved": text.replace("[C3]", "[C99]"),
            "marker_malformed": text.replace("[C3]", "[c3]"),
            "sentence_multi_claim": text.replace("merged publicly [C3].", "merged publicly [C3] [C1]."),
        }
        for code, mutated in cases.items():
            with self.subTest(code=code):
                self.proposal.write_text(mutated, encoding="utf-8")
                self.refused_with(code)

    def test_marked_sentence_must_equal_the_ledger_sentence(self) -> None:
        self.render()
        text = self.proposal.read_text(encoding="utf-8")
        self.proposal.write_text(text.replace("10 of 10 checks [C2]", "11 of 10 checks [C2]"), encoding="utf-8")
        self.refused_with("sentence_mismatch")

    def test_claim_without_a_proposal_sentence_is_refused(self) -> None:
        self.write_ledger(
            LEDGER
            + """
wdc:C6 a wdc:Claim ;
    dcterms:identifier "C6" ;
    wdc:sentence "An orphan claim is never shown." ;
    wdc:claimClass wdc:PUBLICLY_OBSERVABLE ;
    wdc:publicRef "https://example.org/x" ;
    wdc:classifiedBy "test" .
"""
        )
        self.render()
        self.refused_with("claim_unreferenced")

    # -- ledger-side refusals --------------------------------------------

    def test_claim_needs_exactly_one_class(self) -> None:
        self.write_ledger(LEDGER.replace("wdc:claimClass wdc:PUBLICLY_OBSERVABLE ;", "wdc:claimClass wdc:PUBLICLY_OBSERVABLE, wdc:SUPPLIED ;"))
        self.render()
        self.refused_with("class_count")

    def test_supplied_receipt_must_be_admitted_by_the_real_validator(self) -> None:
        self.write_ledger(LEDGER.replace('"receipts/proof.json"', '"receipts/bad.json"'))
        self.render()
        proc = self.refused_with("receipt_not_admitted")
        self.assertIn("receipts/bad.json", proc.stdout)

    def test_observed_proof_needs_an_alive_receipt(self) -> None:
        self.write_ledger(LEDGER.replace('"receipts/proof.json"', '"receipts/partial.json"'))
        self.render()
        proc = self.refused_with("proof_not_alive")
        self.assertNotIn("receipt_not_admitted", self.codes(proc))  # PARTIAL_ALIVE is schema-valid

    def test_supplied_quote_must_occur_in_the_digest_bound_text(self) -> None:
        self.write_ledger(LEDGER.replace('"One product family, one site, English corpus"', '"Two product families"'))
        self.render()
        self.refused_with("quote_not_in_supplied_source")
        self.write_ledger(LEDGER.replace('"receipts/supply.json"', '"receipts/unbound.json"'))
        self.render()
        self.refused_with("supplied_source_unbound")

    def test_inference_premises_are_known_resolved_and_acyclic(self) -> None:
        cases = {
            "inference_on_unknown": LEDGER.replace("wdc:premise wdc:C2, wdc:C3 ;", "wdc:premise wdc:C5 ;"),
            "premise_unresolved": LEDGER.replace("wdc:premise wdc:C2, wdc:C3 ;", "wdc:premise wdc:C77 ;"),
            "inference_cycle": LEDGER.replace("wdc:premise wdc:C2, wdc:C3 ;", "wdc:premise wdc:C4 ;"),
        }
        for code, ledger in cases.items():
            with self.subTest(code=code):
                self.write_ledger(ledger)
                self.render()
                self.refused_with(code)

    def test_unsupplied_wd_fact_must_stay_unknown(self) -> None:
        mutated = LEDGER.replace(
            'wdc:sentence "Pull request 170 was merged publicly." ;',
            'wdc:sentence "Pull request 170 lowers MTTR by half." ;',
        )
        self.write_ledger(mutated)
        self.render()
        proc = self.refused_with("unsupplied_wd_fact")
        self.assertIn("[C3]", proc.stdout)
        # the same sentence typed WD_DEPENDENT_UNKNOWN naming the input is admitted
        fixed = mutated.replace(
            'wdc:claimClass wdc:PUBLICLY_OBSERVABLE ;\n    wdc:publicRef "https://github.com/example/repo/pull/170" ;',
            "wdc:claimClass wdc:WD_DEPENDENT_UNKNOWN ;\n    wdc:missingInput wdc:MI-mttr ;",
        ).replace("wdc:premise wdc:C2, wdc:C3 ;", "wdc:premise wdc:C2 ;")
        self.write_ledger(fixed)
        self.render()
        proc = self.check()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_missing_validator_is_a_typed_refusal(self) -> None:
        self.render()
        proc = self.check("--validator", (self.root / "no-such-validator.py").as_posix())
        self.assertEqual(proc.returncode, 1)
        self.assertIn("validator_unavailable", self.codes(proc))

    def test_check_admits_under_a_fresh_home_like_the_f3_court_env(self) -> None:
        self.render()
        with tempfile.TemporaryDirectory() as home:
            proc = subprocess.run(
                [sys.executable, SCRIPT.as_posix(), "check", "--ledger", self.ledger.as_posix(), "--proposal", self.proposal.as_posix()],
                cwd=self.root,
                capture_output=True,
                text=True,
                check=False,
                # a fresh HOME hides the user site; the F3 court passes it explicitly
                env=dict(os.environ, HOME=home, DFCM_VALIDATOR=VALIDATOR.as_posix(), PYTHONUSERBASE=site.getuserbase()),
            )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("2 receipts ADMITTED", proc.stdout)

    def test_render_refuses_a_placeholder_without_a_claim(self) -> None:
        self.write_ledger(LEDGER.replace("{C5} Everything", "{C42} Everything"))
        proc = self.render()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("placeholder_unresolved", proc.stdout)
        self.assertFalse(self.proposal.exists())


@unittest.skipUnless(VALIDATOR.is_file(), f"fleet receipt validator absent at {VALIDATOR}")
class CommittedLedgerTest(unittest.TestCase):
    """The lane's committed ledger and proposal pass the court (the V23-W lane gate's second half)."""

    LEDGER = REPO / "docs/sjira/v26.9.23/wd-fa/claims.ttl"
    PROPOSAL = REPO / "docs/sjira/v26.9.23/wd-fa/proposal.md"

    @unittest.skipUnless(LEDGER.is_file() and PROPOSAL.is_file(), "wd-fa ledger/proposal not present")
    def test_committed_ledger_admits(self) -> None:
        proc = subprocess.run(
            [sys.executable, SCRIPT.as_posix(), "check", "--ledger", self.LEDGER.as_posix(), "--proposal", self.PROPOSAL.as_posix()],
            cwd=REPO,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("CHECK OK:", proc.stdout)


if __name__ == "__main__":
    unittest.main()
