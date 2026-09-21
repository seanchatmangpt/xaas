"""Unit tests for contracts/evidence-receipt.schema.json.

Every fixture and expected constant below is hardcoded on purpose: this
module never derives an expectation from the schema document it validates
against, so a weakened contract cannot silently keep these tests green.
Each negative fixture is the valid receipt with exactly one element broken,
so dropping a required property, tolerating unknown properties, or widening
a constraint must flip at least one assertion in this file.
"""

import json
import pathlib
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT_2020_12

CONTRACTS_DIR = pathlib.Path(__file__).resolve().parents[1] / "contracts"
SCHEMA_PATH = CONTRACTS_DIR / "evidence-receipt.schema.json"

VALID_STANDING = "ALIVE"

# 4 blocks of 16 hex characters = 64, matching ^[a-fA-F0-9]{64}$.
INPUT_DIGEST_64 = (
    "0123456789abcdef"
    "0123456789abcdef"
    "0123456789abcdef"
    "0123456789abcdef"
)
RESULT_DIGEST_64 = (
    "fedcba9876543210"
    "fedcba9876543210"
    "fedcba9876543210"
    "fedcba9876543210"
)
# 3 blocks of 16 hex characters = 48: hex-only but the wrong length.
INPUT_DIGEST_48 = (
    "0123456789abcdef"
    "0123456789abcdef"
    "0123456789abcdef"
)

VALID_RECEIPT = {
    "receiptId": "urn:aps:receipt:repository-verification",
    "sourceCoordinate": "urn:aps:source:aps@5c31d9d0",
    "inputDigest": INPUT_DIGEST_64,
    "contractRef": "urn:aps:contract:evidence-receipt",
    "executorRef": "urn:aps:executor:ci",
    "observation": {
        "command": "python3 tools/verify.py --no-receipt",
        "exitCode": 0,
    },
    "resultDigest": RESULT_DIGEST_64,
    "standing": VALID_STANDING,
    "verifier": {
        "identity": "aps-dod",
        "coordinate": "urn:aps:verifier:ci",
    },
}


def _contract_resources():
    resources = []
    for path in sorted(CONTRACTS_DIR.glob("*.schema.json")):
        with path.open(encoding="utf-8") as handle:
            contents = json.load(handle)
        resource = Resource.from_contents(
            contents, default_specification=DRAFT_2020_12
        )
        resources.append((contents["$id"], resource))
    return resources


class EvidenceReceiptContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with SCHEMA_PATH.open(encoding="utf-8") as handle:
            schema = json.load(handle)
        registry = Registry().with_resources(_contract_resources())
        cls.validator = Draft202012Validator(schema, registry=registry)

    def _receipt_without(self, property_name):
        case = dict(VALID_RECEIPT)
        del case[property_name]
        return case

    def test_valid_receipt_is_accepted(self):
        self.assertTrue(self.validator.is_valid(VALID_RECEIPT))

    def test_valid_receipt_with_optional_properties_is_accepted(self):
        case = dict(VALID_RECEIPT)
        case["authorityRef"] = "urn:aps:authority:operator-cut-7c3"
        case["processEventRefs"] = [
            "urn:aps:process-event:01",
            "urn:aps:process-event:02",
        ]
        self.assertTrue(self.validator.is_valid(case))

    def test_receipt_id_is_required(self):
        case = self._receipt_without("receiptId")
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "receiptId" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_source_coordinate_is_required(self):
        case = self._receipt_without("sourceCoordinate")
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "sourceCoordinate" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_input_digest_is_required(self):
        case = self._receipt_without("inputDigest")
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "inputDigest" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_contract_ref_is_required(self):
        case = self._receipt_without("contractRef")
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "contractRef" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_unknown_property_is_rejected(self):
        case = dict(VALID_RECEIPT)
        case["evidenceLedger"] = "ledger rows"
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "evidenceLedger" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_standing_must_be_admitted_enum_member(self):
        case = dict(VALID_RECEIPT)
        case["standing"] = "DEAD"
        self.assertFalse(self.validator.is_valid(case))
        self.assertTrue(
            any(
                "DEAD" in error.message
                for error in self.validator.iter_errors(case)
            )
        )

    def test_input_digest_must_be_64_hex_characters(self):
        case = dict(VALID_RECEIPT)
        case["inputDigest"] = INPUT_DIGEST_48
        self.assertFalse(self.validator.is_valid(case))


if __name__ == "__main__":
    unittest.main()
