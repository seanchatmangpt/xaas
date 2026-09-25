"""Charter §14: ERC = <H, A, F, E, V>. The primitive scientific unit in EDS."""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

from eds.states import EvidenceState, STATES_REQUIRING_EVIDENCE


class ERCValidationError(ValueError):
    """Raised when an ERC record violates a charter-mandated invariant."""


@dataclass
class ERC:
    id: str
    hypothesis: str  # H
    artifact_reference: str  # A
    evidence_state: EvidenceState
    falsifier: str = ""  # F
    no_falsifier: bool = False
    evidence: str = ""  # E
    verification: str = ""  # V
    source_revision: str = ""
    receipt_refs: tuple[str, ...] = field(default_factory=tuple)

    def validate(self) -> list[str]:
        """Return a list of charter violations (empty list = clean). Never
        raises for a data problem — callers decide whether to treat findings
        as fatal via ERC.require_valid()."""
        problems: list[str] = []

        # Charter §7: NoFalsifier => NoStrongEDSClaim. A claim with no
        # falsifier is not an error, but it MUST be marked, never silently
        # assumed adequate.
        if not self.falsifier and not self.no_falsifier:
            problems.append(
                "no falsifier given and no_falsifier not set — charter §7 "
                "requires an explicit falsifier or an explicit admission "
                "that none was constructed"
            )
        if self.falsifier and self.no_falsifier:
            problems.append(
                "falsifier text present but no_falsifier=True — contradictory record"
            )

        # Charter §8/§9: IMPLEMENTED != VERIFIED. A state at or above OBSERVED
        # requires real evidence text to be present, not merely claimed.
        if self.evidence_state in STATES_REQUIRING_EVIDENCE and not self.evidence.strip():
            problems.append(
                f"evidence_state={self.evidence_state.value} requires non-empty "
                "evidence (charter §8: a state cannot be claimed without the "
                "evidence that would justify it)"
            )

        return problems

    def require_valid(self) -> "ERC":
        problems = self.validate()
        if problems:
            raise ERCValidationError(
                f"ERC {self.id!r} violates EDS charter invariants: " + "; ".join(problems)
            )
        return self

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["evidence_state"] = self.evidence_state.value
        d["receipt_refs"] = list(self.receipt_refs)
        return d

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "ERC":
        d = dict(d)
        d["evidence_state"] = EvidenceState(d["evidence_state"])
        d["receipt_refs"] = tuple(d.get("receipt_refs", ()))
        # accept either the schema's nested {"artifact": {"reference": ...}}
        # shape or a flattened artifact_reference, so records produced by
        # workflow agents against erc.schema.json load without translation.
        if "artifact" in d and "artifact_reference" not in d:
            artifact = d.pop("artifact") or {}
            d["artifact_reference"] = artifact.get("reference", "")
            d.setdefault("source_revision", artifact.get("source_revision", ""))
        # Some earlier agent passes wrote "evidence" (and "verification") as
        # a list or a nested dict instead of the schema's plain string.
        # Coerce unconditionally (not just for states validate() happens to
        # check) into a real string (real flatten, not a silent drop of
        # data) rather than letting every downstream .strip()/string call
        # crash on it. This must not depend on evidence_state: validate()
        # only requires non-empty evidence for STATES_REQUIRING_EVIDENCE,
        # but every consumer (registry_sweep, this module's own str fields)
        # assumes evidence/verification are always strings regardless of
        # state.
        for field in ("evidence", "verification"):
            v = d.get(field)
            if isinstance(v, list):
                d[field] = "\n".join(str(item) for item in v)
            elif isinstance(v, dict):
                d[field] = "; ".join(f"{k}={v2!r}" for k, v2 in v.items())
        d = {k: v for k, v in d.items() if k in cls.__dataclass_fields__}
        return cls(**d)

    def write(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n")
        return path

    @classmethod
    def read(cls, path: Path) -> "ERC":
        return cls.from_dict(json.loads(Path(path).read_text()))
