"""Tests for sprtool — run with: python3 -m unittest discover -s tests"""

import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import sprtool

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The repo's own SPR corpus must validate clean.
CORPUS = [
    "examples/SPR.md",
    "examples/HMCS.md",
    "examples/implied_cognition.md",
    "examples/systems_thinking.md",
]

VALID = """Some preamble prose that is context, not payload.
- First statement asserts a core concept.
- Second statement carries an association.
- Third statement completes the priming set.
"""

VALID_STAR = """* Star bullets parse identically.
* Second statement of the star variant.
* Third statement for the minimum count.
"""


class TestParse(unittest.TestCase):
    def test_parses_statements_and_context(self):
        doc = sprtool.parse(VALID)
        self.assertEqual(len(doc["statements"]), 3)
        self.assertEqual(len(doc["context"]), 1)
        self.assertEqual(doc["statements"][0][1], "First statement asserts a core concept.")

    def test_star_bullets_accepted(self):
        doc = sprtool.parse(VALID_STAR)
        self.assertEqual(len(doc["statements"]), 3)

    def test_no_statements_raises(self):
        with self.assertRaises(sprtool.SprError):
            sprtool.parse("Just prose, no bullets here at all.")

    def test_statement_line_numbers(self):
        doc = sprtool.parse(VALID)
        self.assertEqual([lineno for lineno, _ in doc["statements"]], [2, 3, 4])


class TestValidate(unittest.TestCase):
    def test_valid_document(self):
        self.assertEqual(sprtool.validate(sprtool.parse(VALID)), [])

    def test_corpus_validates_clean(self):
        for rel in CORPUS:
            with self.subTest(rel=rel):
                doc = sprtool.load(os.path.join(REPO, rel))
                self.assertEqual(sprtool.validate(doc), [])

    def test_too_few_statements(self):
        doc = sprtool.parse("- Only one statement exists here.\n- And a second one.")
        violations = sprtool.validate(doc)
        self.assertTrue(any(v.startswith("S1:") for v in violations))

    def test_oversized_statement(self):
        text = "\n".join(
            ["- " + " ".join("word%d" % i for i in range(sprtool.MAX_WORDS + 1))]
            + ["- Short statement here.", "- Another valid statement."]
        )
        violations = sprtool.validate(sprtool.parse(text))
        self.assertTrue(any(v.startswith("S3:") for v in violations))

    def test_duplicate_statement(self):
        text = (
            "- The same idea repeated.\n"
            "- A distinct second statement.\n"
            "- THE SAME IDEA REPEATED.\n"
        )
        violations = sprtool.validate(sprtool.parse(text))
        self.assertTrue(any(v.startswith("S4:") for v in violations))

    def test_single_word_statement(self):
        text = "- Singleton.\n- A real statement follows.\n- Another real statement."
        violations = sprtool.validate(sprtool.parse(text))
        self.assertTrue(any(v.startswith("S2:") for v in violations))


class TestRender(unittest.TestCase):
    def test_round_trip_is_stable(self):
        doc = sprtool.parse(VALID)
        first = sprtool.render(doc)
        second = sprtool.render(sprtool.parse(first))
        self.assertEqual(first, second)
        self.assertTrue(first.startswith("- First statement"))
        self.assertTrue(first.endswith("priming set.\n"))

    def test_unreadable_path_raises_spr_error(self):
        # Files reach render() through load(), which documents SprError on
        # unreadable input.
        with self.assertRaisesRegex(sprtool.SprError, "cannot read"):
            sprtool.render(sprtool.load(os.path.join(REPO, "no_such_file.md")))

    def test_statement_free_content_raises_spr_error(self):
        # Zero bullet statements violate the document contract; parse()
        # rejects the document before render() can be handed it.
        with self.assertRaisesRegex(sprtool.SprError, "no SPR statements"):
            sprtool.render(sprtool.parse("Just prose, no bullets here at all."))

    def test_short_document_round_trip_flags_s1_violation(self):
        # render() itself does not gate content; re-validating its output
        # must name the documented S1 violation for a too-short document.
        doc = sprtool.parse("- Only one statement exists here.\n- And a second one.")
        violations = sprtool.validate(sprtool.parse(sprtool.render(doc)))
        self.assertTrue(any(v.startswith("S1:") for v in violations))


class TestCli(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, os.path.join(REPO, "sprtool.py")] + list(args),
            capture_output=True,
            text=True,
        )

    def test_validate_valid_file_exits_zero(self):
        result = self.run_cli("validate", os.path.join(REPO, "examples/SPR.md"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("OK", result.stdout)

    def test_validate_invalid_file_exits_one(self):
        bad = os.path.join(REPO, "tests", "_invalid_spr.md")
        with open(bad, "w") as handle:
            handle.write("- Lone duplicate.\n- Lone duplicate.\n")
        try:
            result = self.run_cli("validate", bad)
        finally:
            os.unlink(bad)
        self.assertEqual(result.returncode, 1)
        self.assertIn("S1:", result.stderr)
        self.assertIn("S4:", result.stderr)

    def test_validate_missing_file_exits_one(self):
        result = self.run_cli("validate", os.path.join(REPO, "no_such_file.md"))
        self.assertEqual(result.returncode, 1)

    def test_render_exits_zero_and_outputs_bullets(self):
        result = self.run_cli("render", os.path.join(REPO, "examples/HMCS.md"))
        self.assertEqual(result.returncode, 0)
        for line in result.stdout.splitlines():
            self.assertTrue(line.startswith("- "))

    def test_json_valid_exits_zero(self):
        result = self.run_cli("json", os.path.join(REPO, "examples/SPR.md"))
        self.assertEqual(result.returncode, 0)
        self.assertIn('"statements"', result.stdout)


if __name__ == "__main__":
    unittest.main()
