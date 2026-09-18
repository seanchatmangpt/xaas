"""Chicago-style tests for aps_dod_court.py.

Real collaborators only: real `git clone --local` candidates of a real APS
checkout with real commits, the court and backlog run as real subprocesses,
real jsonschema validation of the emitted receipt, real mdbook. Assertions are
on final state: exit code, emitted receipt, gate results, and the worktree.
"""
import importlib.util
import json
import os
import pathlib
import shutil
import sys
import tempfile
import unittest

import jsonschema
from referencing import Registry, Resource

import aps_fixture as fx


def load_court_module():
    spec = importlib.util.spec_from_file_location("aps_dod_court_under_test", fx.COURT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class CourtPureFunctionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.court = load_court_module()

    def test_glob_semantics(self):
        m = self.court.matches_any
        self.assertTrue(m("tests/a.py", ["tests/*.py"]))
        self.assertFalse(m("tests/sub/a.py", ["tests/*.py"]))
        self.assertTrue(m(".github/workflows/x.yml", [".github/**"]))
        self.assertTrue(m("a/b/x.py", ["**/x.py"]))
        self.assertFalse(m("tools/verify.py.bak", ["tools/verify.py"]))

    def test_standing_is_a_pure_function_of_gate_results(self):
        def r(gid, ok, kind=None):
            return self.court.result(gid, ok, "d", kind=kind)

        ok = [r("CHI-SCOPE", True), r("CHI-MUTATION", True)]
        self.assertEqual(("ALIVE", 0), self.court.compute_standing(ok))
        self.assertEqual(("REFUSED", 1), self.court.compute_standing(ok + [r("CHI-MOCK", False)]))
        self.assertEqual(("BLOCKED", 1), self.court.compute_standing(ok + [r("CHI-MUTATION", False)]))
        self.assertEqual(("BLOCKED", 2), self.court.compute_standing(ok + [r("CHI-CANONICAL", False, "infra")]))
        # a safety refusal outranks an infra problem
        mixed = ok + [r("CHI-SCOPE", False), r("CHI-CANONICAL", False, "infra")]
        self.assertEqual(("REFUSED", 1), self.court.compute_standing(mixed))

    def test_assertion_analysis_sees_real_trivial_vacuous_helper_and_skipped_tests(self):
        src = '''import unittest


class Base(unittest.TestCase):
    def _check_bad(self, value):
        self.assertFalse(value)


class Child(Base):
    def test_uses_helper(self):
        self._check_bad(0)

    def test_real(self):
        self.assertEqual(3, len([1, 2, 3]))

    def test_trivial(self):
        self.assertTrue(True)
        assert 1 == 1

    def test_vacuous(self):
        pass

    @unittest.skip("later")
    def test_skipped(self):
        self.assertEqual(1, 2)

    def test_raises(self):
        with self.assertRaises(KeyError):
            {}["x"]


def test_module_level_is_not_collected_by_unittest():
    assert False
'''
        tests, err = self.court.analyze_test_source(src)
        self.assertIsNone(err)
        by = {t["qualname"]: t for t in tests}
        self.assertEqual(
            {"Child.test_uses_helper", "Child.test_real", "Child.test_trivial", "Child.test_vacuous",
             "Child.test_skipped", "Child.test_raises"}, set(by))
        self.assertTrue(by["Child.test_uses_helper"]["has_real"])
        self.assertTrue(by["Child.test_real"]["has_real"])
        self.assertTrue(by["Child.test_raises"]["has_real"])
        self.assertFalse(by["Child.test_trivial"]["has_real"])
        self.assertFalse(by["Child.test_vacuous"]["has_real"])
        self.assertTrue(by["Child.test_skipped"]["skips"])
        _, syntax_error = self.court.analyze_test_source("def broken(:\n")
        self.assertIn("syntax error", syntax_error)


@unittest.skipUnless(fx.APS, fx.SKIP_REASON)
class CourtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.items = fx.backlog_items(fx.APS)

    def setUp(self):
        self.root = fx.tempdir()
        self.addCleanup(fx.cleanup, self.root)
        self.cand = fx.Candidate(self.root)

    # -- candidate builders (real commits)
    def standing_good(self, extra=""):
        self.cand.write("tests/test_contract_standing.py", fx.STANDING_GOOD + extra)
        self.cand.commit("test(contract): standing")
        return self.items["contract-standing"]

    def actuation(self, body):
        self.cand.write("tests/test_contract_actuation_intent.py", body)
        self.cand.commit("test(contract): actuation-intent")
        return self.items["contract-actuation-intent"]

    def assert_gate(self, run, gate_id, ok, kind=None):
        gate = run.gates[gate_id]
        self.assertEqual(ok, gate["pass"], f"{gate_id}: {gate['detail']}")
        if kind:
            self.assertEqual(kind, gate["kind"], f"{gate_id}: {gate['detail']}")
        return gate

    def validate_receipt_independently(self, receipt):
        docs = {n: json.loads((self.cand.path / "contracts" / n).read_text())
                for n in ("evidence-receipt.schema.json", "standing.schema.json")}
        registry = Registry().with_resources([(d["$id"], Resource.from_contents(d)) for d in docs.values()])
        validator = jsonschema.Draft202012Validator(docs["evidence-receipt.schema.json"], registry=registry)
        self.assertEqual([], [e.message for e in validator.iter_errors(receipt)])

    # -------------------------------------------------------------- ALIVE
    def test_good_standing_candidate_is_alive_with_a_schema_valid_receipt(self):
        item = self.standing_good()
        head = self.cand.head()
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(0, run.rc, run.stderr[-1500:])
        r = run.receipt
        self.assertEqual("ALIVE", r["standing"])
        for gate in ("CHI-EXACT-HEAD", "CHI-INDEPENDENT", "CHI-SCOPE", "CHI-MOCK", "CHI-ASSERT",
                     "CHI-CANONICAL", "CHI-MUTATION"):
            self.assert_gate(run, gate, True, "ok")
        self.assertEqual(1.0, run.gates["CHI-MUTATION"]["kill_ratio"])
        self.assertEqual(4, r["observation"]["newTests"])
        self.assertEqual(f"aps@{head}", r["sourceCoordinate"])
        self.assertEqual("aps-ticket:contract-standing#1", r["contractRef"])
        self.assertEqual("glm-worker-1", r["executorRef"])
        self.assertEqual("aps-court-1", r["verifier"]["identity"])
        self.assertRegex(r["verifier"]["coordinate"], r"^aps_dod_court\.py@sha256:[0-9a-f]{64}$")
        self.assertRegex(r["inputDigest"], r"^[0-9a-f]{64}$")
        self.assertRegex(r["resultDigest"], r"^[0-9a-f]{64}$")
        self.validate_receipt_independently(r)
        self.assertIn("[CHI-SCOPE] PASS", run.stderr)
        # the court leaves the worktree byte-clean and at the same head
        self.assertEqual("", self.cand.status())
        self.assertEqual(head, self.cand.head())

    def test_good_actuation_intent_candidate_kills_all_five_mutants(self):
        item = self.actuation(fx.ACTUATION_HEADER + fx.ACTUATION_FULL_EXTRA)
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(0, run.rc, run.stderr[-1500:])
        mut = run.gates["CHI-MUTATION"]
        self.assertEqual(5, mut["mutant_count"])
        self.assertEqual({"killed"}, {m["status"] for m in mut["mutants"]})
        self.assertEqual("ALIVE", run.receipt["standing"])

    def test_same_inputs_give_the_same_digests(self):
        item = self.standing_good()
        ticket = self.cand.ticket(item)
        first = self.cand.run_court(ticket).receipt
        second = self.cand.run_court(ticket).receipt
        self.assertEqual(first["inputDigest"], second["inputDigest"])
        self.assertEqual(first["resultDigest"], second["resultDigest"])
        self.assertNotEqual(first["receiptId"], second["receiptId"])

    # ------------------------------------------------------ CHI-ASSERT
    def test_vacuous_tests_are_rejected(self):
        body = "import unittest\n\n\nclass T(unittest.TestCase):\n" + "".join(
            f"    def test_{n}(self):\n        pass\n\n" for n in "abcd")
        self.cand.write("tests/test_contract_standing.py", body)
        self.cand.commit("vacuous")
        run = self.cand.run_court(self.cand.ticket(self.items["contract-standing"]))
        self.assertEqual(1, run.rc)
        self.assertEqual("BLOCKED", run.receipt["standing"])
        gate = self.assert_gate(run, "CHI-ASSERT", False)
        self.assertIn("vacuous (no assertion)", gate["detail"])
        # defense in depth: the same candidate also fails the non-vacuity (mutation) gate
        self.assert_gate(run, "CHI-MUTATION", False)

    def test_trivially_true_assertions_are_rejected(self):
        body = "import unittest\n\n\nclass T(unittest.TestCase):\n" + "".join(
            f"    def test_{n}(self):\n        self.assertTrue(True)\n        assert 1 == 1\n\n" for n in "abcd")
        self.cand.write("tests/test_contract_standing.py", body)
        self.cand.commit("trivial")
        run = self.cand.run_court(self.cand.ticket(self.items["contract-standing"]))
        self.assertEqual(1, run.rc)
        self.assertIn("only trivially-true assertions", self.assert_gate(run, "CHI-ASSERT", False)["detail"])

    def test_skipped_tests_do_not_count(self):
        body = "import unittest\n\n\nclass T(unittest.TestCase):\n" + "".join(
            f"    @unittest.skip('later')\n    def test_{n}(self):\n        self.assertFalse(False and 1)\n\n" for n in "abcd")
        self.cand.write("tests/test_contract_standing.py", body)
        self.cand.commit("skipped")
        run = self.cand.run_court(self.cand.ticket(self.items["contract-standing"]))
        self.assertEqual(1, run.rc)
        self.assertIn("skipped/expected-failure", self.assert_gate(run, "CHI-ASSERT", False)["detail"])

    def test_too_few_new_tests_are_rejected(self):
        self.cand.write("tests/test_contract_standing.py", fx.STANDING_GOOD.split("    def test_lowercase")[0])
        self.cand.commit("one test")
        run = self.cand.run_court(self.cand.ticket(self.items["contract-standing"]))
        self.assertEqual(1, run.rc)
        self.assertIn("ticket requires 4", self.assert_gate(run, "CHI-ASSERT", False)["detail"])

    # -------------------------------------------------------- CHI-MOCK
    def test_test_double_machinery_is_refused(self):
        item = self.standing_good()
        self.cand.write("tests/test_contract_standing.py", fx.BANNED_IMPORT + "\n" + fx.STANDING_GOOD)
        self.cand.commit("adds a test double import")
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(1, run.rc)
        self.assertEqual("REFUSED", run.receipt["standing"])
        gate = self.assert_gate(run, "CHI-MOCK", False)
        self.assertIn("tests/test_contract_standing.py:1", gate["detail"])

    # ------------------------------------------------------- CHI-SCOPE
    def test_out_of_scope_file_is_refused(self):
        item = self.standing_good()
        self.cand.write("notes/extra.txt", "not allowed\n")
        self.cand.commit("extra file")
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(1, run.rc)
        self.assertEqual("REFUSED", run.receipt["standing"])
        self.assertIn("notes/extra.txt: outside allowed_paths", self.assert_gate(run, "CHI-SCOPE", False)["detail"])

    def test_protected_file_edit_is_refused_even_when_a_glob_would_allow_it(self):
        item = self.standing_good()
        self.cand.append("tools/verify.py", "\n# weakened\n")
        self.cand.commit("edits the court's own authority")
        ticket = self.cand.ticket(item, allowed_paths=["tests/test_contract_standing.py", "tools/*.py"])
        run = self.cand.run_court(ticket)
        self.assertEqual(1, run.rc)
        self.assertEqual("REFUSED", run.receipt["standing"])
        self.assertIn("tools/verify.py: protected path", self.assert_gate(run, "CHI-SCOPE", False)["detail"])

    def test_modifying_an_existing_test_is_refused(self):
        item = self.standing_good()
        self.cand.append("tests/test_repository.py", "\n# tampered\n")
        self.cand.commit("tampers with an existing test")
        ticket = self.cand.ticket(item, allowed_paths=["tests/*.py"])
        run = self.cand.run_court(ticket)
        self.assertEqual(1, run.rc)
        self.assertIn("existing tests are append-only",
                      self.assert_gate(run, "CHI-SCOPE", False)["detail"])

    def test_a_symlinked_test_file_is_refused(self):
        item = self.items["contract-standing"]
        os.symlink("../contracts/standing.schema.json", self.cand.path / "tests" / "test_contract_standing.py")
        self.cand.commit("symlink")
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(1, run.rc)
        self.assertIn("symlink", self.assert_gate(run, "CHI-SCOPE", False)["detail"])

    # ---------------------------------------------------- CHI-EXACT-HEAD
    def test_a_wrong_claimed_head_is_refused_and_the_rest_is_skipped(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), head=self.cand.base)
        self.assertEqual(1, run.rc)
        self.assertEqual("REFUSED", run.receipt["standing"])
        gate = self.assert_gate(run, "CHI-EXACT-HEAD", False)
        self.assertFalse(gate["checks"]["head_matches"])
        for gid in ("CHI-SCOPE", "CHI-MOCK", "CHI-ASSERT", "CHI-CANONICAL", "CHI-MUTATION"):
            self.assert_gate(run, gid, False, "skipped")

    def test_a_nonexistent_head_is_refused(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), head="0" * 39 + "1")
        self.assertEqual(1, run.rc)
        self.assertFalse(self.assert_gate(run, "CHI-EXACT-HEAD", False)["checks"]["head_exists"])

    def test_a_dirty_tree_is_refused_and_left_untouched(self):
        item = self.standing_good()
        ticket = self.cand.ticket(item)
        for dirty in ("untracked", "modified"):
            with self.subTest(dirty):
                if dirty == "untracked":
                    self.cand.write("scratch.txt", "left behind\n")
                else:
                    (self.cand.path / "scratch.txt").unlink()
                    self.cand.append("tests/test_contract_standing.py", "\n# uncommitted\n")
                before = self.cand.status()
                run = self.cand.run_court(ticket)
                self.assertEqual(1, run.rc)
                self.assertEqual("REFUSED", run.receipt["standing"])
                self.assertFalse(self.assert_gate(run, "CHI-EXACT-HEAD", False)["checks"]["clean_before"])
                self.assertEqual(before, self.cand.status())

    # -------------------------------------------------- CHI-INDEPENDENT
    def test_the_executor_cannot_be_its_own_verifier(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), executor="same-id", verifier="same-id")
        self.assertEqual(1, run.rc)
        self.assertEqual("REFUSED", run.receipt["standing"])
        self.assertIn("cannot self-attest", self.assert_gate(run, "CHI-INDEPENDENT", False)["detail"])

    # ------------------------------------------------------ CHI-MUTATION
    def test_tests_that_do_not_detect_a_weakened_schema_are_rejected(self):
        item = self.actuation(fx.ACTUATION_HEADER)
        run = self.cand.run_court(self.cand.ticket(item))
        self.assertEqual(1, run.rc)
        self.assertEqual("BLOCKED", run.receipt["standing"])
        self.assert_gate(run, "CHI-ASSERT", True)
        self.assert_gate(run, "CHI-CANONICAL", True)
        mut = self.assert_gate(run, "CHI-MUTATION", False)
        status = {m["id"].split(":", 1)[1]: m["status"] for m in mut["mutants"]}
        self.assertEqual("killed", status["drop-required:intentId"])
        self.assertEqual("killed", status["widen-additional"])
        for prop in ("contractId", "authorityRef", "executorRef"):
            self.assertEqual("survived", status[f"drop-required:{prop}"])
        self.assertAlmostEqual(0.4, mut["kill_ratio"])

    def test_an_unknown_mutant_kind_is_a_typed_failure_never_a_skip(self):
        item = self.standing_good()
        bogus = [{"id": "x", "kind": "schema-bogus", "file": "contracts/standing.schema.json"}]
        run = self.cand.run_court(self.cand.ticket(item, mutants=bogus))
        self.assertEqual(1, run.rc)
        self.assertIn("unknown mutant kind", self.assert_gate(run, "CHI-MUTATION", False)["detail"])

    def test_a_ticket_with_no_mutants_cannot_evidence_non_vacuity(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item, mutants=[]))
        self.assertEqual(1, run.rc)
        self.assertIn("declares no mutants", self.assert_gate(run, "CHI-MUTATION", False)["detail"])

    def test_a_mutant_that_does_not_apply_fails_instead_of_being_skipped(self):
        item = self.standing_good()
        wrong = [{"id": "w", "kind": "schema-drop-enum-value", "file": "contracts/standing.schema.json",
                  "pointer": "", "value": "NOT-A-MEMBER"}]
        run = self.cand.run_court(self.cand.ticket(item, mutants=wrong))
        self.assertEqual(1, run.rc)
        self.assertIn("not applicable", self.assert_gate(run, "CHI-MUTATION", False)["detail"])

    # ---------------------------------------------------- infra / exit 2
    def test_unreadable_or_invalid_tickets_exit_2_with_a_blocked_receipt(self):
        item = self.standing_good()
        good = json.loads(self.cand.ticket(item).read_text())
        cases = {
            "missing": self.root / "nope.json",
            "not-json": self.root / "notjson.json",
            "wrong-version": self.root / "wrongver.json",
            "bad-sha": self.root / "badsha.json",
        }
        cases["not-json"].write_text("{nope")
        cases["wrong-version"].write_text(json.dumps({**good, "schemaVersion": "aps-ticket/9"}))
        cases["bad-sha"].write_text(json.dumps({**good, "base_sha": "abc"}))
        for name, path in cases.items():
            with self.subTest(name):
                run = self.cand.run_court(path)
                self.assertEqual(2, run.rc)
                self.assertEqual("BLOCKED", run.receipt["standing"])
                self.assertEqual("infra", run.receipt["observation"]["gates"][0]["kind"])

    def test_a_missing_worktree_exits_2(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), worktree=self.root / "no-such-dir")
        self.assertEqual(2, run.rc)
        self.assertEqual("BLOCKED", run.receipt["standing"])

    def test_a_malformed_head_argument_exits_2_without_stdout(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), head="deadbeef")
        self.assertEqual(2, run.rc)
        self.assertEqual("", run.stdout.strip())

    def test_a_missing_mdbook_is_infra_never_a_silent_skip(self):
        item = self.standing_good()
        bindir = pathlib.Path(tempfile.mkdtemp(prefix="aps-nomdbook-", dir=self.root))
        os.symlink(shutil.which("git"), bindir / "git")
        env = {**os.environ, "PATH": str(bindir)}
        run = self.cand.run_court(self.cand.ticket(item), env=env)
        self.assertEqual(2, run.rc)
        self.assertEqual("BLOCKED", run.receipt["standing"])
        gate = self.assert_gate(run, "CHI-CANONICAL", False, "infra")
        self.assertIn("mdbook", gate["detail"])
        self.assert_gate(run, "CHI-SCOPE", True)

    def test_mdbook_output_inside_the_worktree_is_refused(self):
        item = self.standing_good()
        run = self.cand.run_court(self.cand.ticket(item), extra=("--mdbook-out", str(self.cand.path / "book")))
        self.assertEqual(2, run.rc)
        self.assertEqual("", self.cand.status())


if __name__ == "__main__":
    unittest.main()
