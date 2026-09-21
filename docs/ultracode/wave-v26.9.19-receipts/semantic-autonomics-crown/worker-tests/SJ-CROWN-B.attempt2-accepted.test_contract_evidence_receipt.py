"""Unit tests for contracts/evidence-receipt.schema.json.

Every fixture below is a hardcoded literal receipt; expected outcomes are
fixed here and never derived from the schema under test, so weakening the
schema cannot silently weaken these tests.
"""

import json
import pathlib
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACTS_DIR = ROOT / "contracts"
SCHEMA_PATH = CONTRACTS_DIR / "evidence-receipt.schema.json"

VALID_INPUT_DIGEST = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
VALID_RESULT_DIGEST = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


def _base_receipt():
    return {
        "receiptId": "urn:uuid:7c9e6679-7425-40de-944b-e07fc1f90ae7",
        "sourceCoordinate": "https://w3id.org/chatman/aps/v26.8.24#repository",
        "inputDigest": VALID_INPUT_DIGEST,
        "contractRef": "https://w3id.org/chatman/aps/v26.8.24/knowledge-contract.schema.json",
        "executorRef": "urn:aps:executor:zcode-dispatch",
        "observation": {"exit_code": 0},
        "resultDigest": VALID_RESULT_DIGEST,
        "standing": "ALIVE",
        "verifier": {
            "identity": "aps-dod",
            "coordinate": "urn:aps:verifier:aps-dod",
        },
    }


def _contracts_registry():
    resources = []
    for schema_path in sorted(CONTRACTS_DIR.glob("*.schema.json")):
        document = json.loads(schema_path.read_text(encoding="utf-8"))
        resources.append((document["$id"], Resource.from_contents(document)))
    return Registry().with_resources(resources)


VALIDATOR = Draft202012Validator(
    json.loads(SCHEMA_PATH.read_text(encoding="utf-8")),
    registry=_contracts_registry(),
)


class EvidenceReceiptContractTest(unittest.TestCase):
    def test_valid_receipt_validates(self):
        receipt = _base_receipt()
        self.assertTrue(VALIDATOR.is_valid(receipt))
        self.assertEqual([], list(VALIDATOR.iter_errors(receipt)))

    def test_missing_receipt_id_is_invalid(self):
        receipt = _base_receipt()
        del receipt["receiptId"]
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_missing_source_coordinate_is_invalid(self):
        receipt = _base_receipt()
        del receipt["sourceCoordinate"]
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_missing_input_digest_is_invalid(self):
        receipt = _base_receipt()
        del receipt["inputDigest"]
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_missing_contract_ref_is_invalid(self):
        receipt = _base_receipt()
        del receipt["contractRef"]
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_unknown_top_level_property_is_invalid(self):
        receipt = _base_receipt()
        receipt["notInContract"] = {"note": "extra property"}
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_non_hex_input_digest_is_invalid(self):
        receipt = _base_receipt()
        receipt["inputDigest"] = "not-a-sha256-digest"
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_unknown_standing_member_is_invalid(self):
        receipt = _base_receipt()
        receipt["standing"] = "SLEEPING"
        self.assertFalse(VALIDATOR.is_valid(receipt))

    def test_verifier_without_identity_is_invalid(self):
        receipt = _base_receipt()
        receipt["verifier"] = {"coordinate": "urn:aps:verifier:aps-dod"}
        self.assertFalse(VALIDATOR.is_valid(receipt))


if __name__ == "__main__":
    unittest.main()
