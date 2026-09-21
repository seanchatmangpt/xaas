import json
import pathlib
import unittest

import jsonschema

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "contracts" / "standing.schema.json"

# Hardcoded expectation: the standing vocabulary is exactly these seven members.
# Deliberately not derived from the schema under test, so weakening the schema
# cannot silently weaken these fixtures.
EXPECTED_STANDING_MEMBERS = (
    "ALIVE",
    "PARTIAL_ALIVE",
    "BLOCKED",
    "BUILD_BROKEN",
    "UNKNOWN",
    "UNSUPPORTED",
    "REFUSED",
)


class StandingContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with SCHEMA_PATH.open("r", encoding="utf-8") as handle:
            schema = json.load(handle)
        cls.validator = jsonschema.Draft202012Validator(schema)

    def test_alive_member_validates(self):
        self.assertTrue(self.validator.is_valid("ALIVE"))
        self.assertIsNone(self.validator.validate("ALIVE"))

    def test_every_admitted_member_validates(self):
        for member in EXPECTED_STANDING_MEMBERS:
            with self.subTest(member=member):
                self.assertTrue(self.validator.is_valid(member))

    def test_integer_is_rejected_as_type_violation(self):
        self.assertFalse(self.validator.is_valid(3))
        keywords = {error.validator for error in self.validator.iter_errors(3)}
        self.assertIn("type", keywords)

    def test_null_is_rejected_as_type_violation(self):
        self.assertFalse(self.validator.is_valid(None))
        keywords = {error.validator for error in self.validator.iter_errors(None)}
        self.assertIn("type", keywords)

    def test_array_is_rejected_as_type_violation(self):
        self.assertFalse(self.validator.is_valid(["ALIVE"]))
        keywords = {error.validator for error in self.validator.iter_errors(["ALIVE"])}
        self.assertIn("type", keywords)

    def test_non_member_string_is_rejected_as_enum_violation(self):
        for value in ("alive", "REFUSED_NO_AUTHORITY"):
            with self.subTest(value=value):
                self.assertFalse(self.validator.is_valid(value))
                keywords = {error.validator for error in self.validator.iter_errors(value)}
                self.assertIn("enum", keywords)


if __name__ == "__main__":
    unittest.main()
