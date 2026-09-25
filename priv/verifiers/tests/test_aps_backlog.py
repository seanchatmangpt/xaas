"""Chicago-style tests for aps_backlog.py: real APS checkout, real subprocess, real git."""
import json
import subprocess
import sys
import unittest

import aps_fixture as fx


def _resolve(doc, pointer):
    cur = doc
    if pointer == "":
        return cur
    for raw in pointer[1:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        cur = cur[int(key)] if isinstance(cur, list) else cur[key]
    return cur


@unittest.skipUnless(fx.APS, fx.SKIP_REASON)
class BacklogTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = fx.sh(sys.executable, fx.BACKLOG, "--repo", fx.APS)
        cls.doc = json.loads(cls.raw)
        cls.items = {i["id"]: i for i in cls.doc["items"]}

    def test_derives_one_item_per_thinly_tested_contract_sorted_by_id(self):
        expected = sorted(f"contract-{p.name[:-len('.schema.json')]}" for p in (fx.APS / "contracts").glob("*.schema.json"))
        self.assertEqual(expected, [i["id"] for i in self.doc["items"]])
        self.assertEqual(6, len(expected))
        self.assertEqual("aps-backlog/1", self.doc["schemaVersion"])
        self.assertEqual(fx.sh("git", "-C", fx.APS, "rev-parse", "HEAD"), self.doc["head"])

    def test_output_is_byte_identical_across_runs(self):
        again = fx.sh(sys.executable, fx.BACKLOG, "--repo", fx.APS)
        self.assertEqual(self.raw, again)

    def test_every_mutant_pointer_resolves_into_the_real_schema_and_is_applicable(self):
        for item in self.doc["items"]:
            schema = json.loads((fx.APS / item["schema"]).read_text())
            self.assertTrue(item["mutants"], item["id"])
            for m in item["mutants"]:
                obj = _resolve(schema, m["pointer"])
                if m["kind"] == "schema-drop-required":
                    self.assertIn(m["property"], obj["required"])
                elif m["kind"] == "schema-widen-additional":
                    self.assertIs(False, obj["additionalProperties"])
                elif m["kind"] == "schema-drop-enum-value":
                    self.assertIn(m["value"], obj["enum"])
                else:
                    self.fail(f"unexpected mutant kind {m['kind']}")

    def test_mutants_follow_the_schema_shape_and_caps(self):
        er = self.items["contract-evidence-receipt"]
        self.assertEqual(
            ["receiptId", "sourceCoordinate", "inputDigest", "contractRef"],
            [m["property"] for m in er["mutants"] if m["kind"] == "schema-drop-required"],
        )
        self.assertEqual(1, sum(m["kind"] == "schema-widen-additional" for m in er["mutants"]))
        standing = self.items["contract-standing"]
        self.assertEqual(["schema-drop-enum-value"], [m["kind"] for m in standing["mutants"]])
        self.assertEqual("ALIVE", standing["mutants"][0]["value"])

    def test_goal_is_self_contained_and_states_the_acceptance_criteria(self):
        item = self.items["contract-actuation-intent"]
        goal = item["goal"]
        self.assertEqual(["tests/test_contract_actuation_intent.py"], item["allowed_paths"])
        self.assertEqual(4, item["min_new_tests"])
        self.assertIn("tests/test_contract_actuation_intent.py", goal)
        self.assertIn("contracts/actuation-intent.schema.json", goal)
        self.assertIn('git commit -m "test(contract): actuation-intent"', goal)
        for banned in fx.BANNED_TOKENS:
            self.assertIn(banned, goal)
        for m in item["mutants"]:
            if m["kind"] == "schema-drop-required":
                self.assertIn(f"`{m['property']}` removed from `required`", goal)
        self.assertIn("additionalProperties", goal)

    def test_a_contract_with_enough_negative_fixtures_is_not_emitted(self):
        root = fx.tempdir()
        self.addCleanup(fx.cleanup, root)
        cand = fx.Candidate(root)
        cand.write("tests/test_existing_standing.py", '''import unittest
import jsonschema


class T(unittest.TestCase):
    def test_bad_one(self):
        with self.assertRaises(jsonschema.ValidationError):
            jsonschema.validate("nope", {"$ref": "contracts/standing.schema.json"})

    def test_bad_two(self):
        self.assertFalse(jsonschema.Draft202012Validator({}).is_valid("x") and "standing.schema.json" in "x")

    def test_bad_three(self):
        self.assertEqual([], [e for e in [] if "standing.schema.json" and "invalid"])
''')
        cand.commit("add negatives")
        ids = set(fx.backlog_items(cand.path))
        self.assertNotIn("contract-standing", ids)
        self.assertEqual(5, len(ids))
        self.assertEqual(set(), set(fx.backlog_items(cand.path, "--min-negatives", "0")))

    def test_missing_contracts_directory_is_an_error(self):
        root = fx.tempdir()
        self.addCleanup(fx.cleanup, root)
        proc = subprocess.run([sys.executable, str(fx.BACKLOG), "--repo", str(root)], capture_output=True, text=True)
        self.assertEqual(2, proc.returncode)
        self.assertEqual("", proc.stdout)
        self.assertIn("no contracts/ directory", proc.stderr)


if __name__ == "__main__":
    unittest.main()
