"""Charter §9: R_E = receipt(claim, artifact, source, environment, inputs,
execution, outputs, validators). A receipt's digest makes it independently
checkable — tamper with any field and the digest no longer matches."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any


def _canonical_body(d: dict[str, Any]) -> bytes:
    body = {k: v for k, v in d.items() if k != "digest"}
    return json.dumps(body, sort_keys=True, separators=(",", ":")).encode("utf-8")


def compute_digest(d: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(_canonical_body(d)).hexdigest()


@dataclass
class Receipt:
    id: str
    claim_id: str
    artifact_reference: str
    source_revision: str
    execution_command: str
    outputs: str
    inputs: str = ""
    environment: dict[str, str] = field(default_factory=dict)
    validators: tuple[str, ...] = field(default_factory=tuple)
    supports_proposition: str = ""
    timestamp: str = ""

    def to_dict(self, with_digest: bool = True) -> dict[str, Any]:
        d = asdict(self)
        d["validators"] = list(self.validators)
        if with_digest:
            d["digest"] = compute_digest(d)
        return d

    def verify_digest(self, claimed_digest: str) -> bool:
        """Chicago-style check: recompute the digest from the real fields and
        compare — no mock, the actual hash function runs."""
        recomputed = compute_digest(self.to_dict(with_digest=False))
        return recomputed == claimed_digest

    def write(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n")
        return path

    @classmethod
    def read(cls, path: Path) -> "Receipt":
        d = json.loads(Path(path).read_text())
        if "digest" not in d:
            # A real receipt written by write()/to_dict() always carries a
            # digest. Its absence is not a lesser, digest-less receipt — it
            # is indistinguishable from an attacker stripping the digest key
            # specifically to bypass verify_digest() below (previously this
            # silently skipped the check instead of raising, the exact
            # tamper-detection bypass the module docstring claims doesn't
            # exist). Treat a missing digest as tampering, not an optional
            # field.
            raise ValueError(f"receipt {path}: missing digest — cannot verify, treating as tampered")
        stored_digest = d.pop("digest")
        d["validators"] = tuple(d.get("validators", ()))
        d = {k: v for k, v in d.items() if k in cls.__dataclass_fields__}
        receipt = cls(**d)
        if not receipt.verify_digest(stored_digest):
            raise ValueError(f"receipt {path}: digest mismatch — record has been altered")
        return receipt
