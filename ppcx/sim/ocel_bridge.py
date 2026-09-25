"""Builds an official-OCEL-2.0-shaped JSON log directly from CycleResult
data. Independent of gymact.ocel (which is coupled to gymact's Receipt
schema per the design's own research note) -- this is a small, standalone
projection specific to ppcx's own cycle/ERC evidence.
"""

from __future__ import annotations

from typing import Any

from ppcx.sim.eds_bridge import CycleResult


def build_ocel_log(cycles: list[CycleResult]) -> dict[str, Any]:
    object_types = [
        {
            "name": "cycle",
            "attributes": [
                {"name": "historical", "type": "boolean"},
                {"name": "cycle_date", "type": "string"},
            ],
        },
        {
            "name": "erc",
            "attributes": [
                {"name": "hypothesis", "type": "string"},
            ],
        },
    ]

    seen_event_types: set[str] = {c.erc.evidence_state.value for c in cycles}
    event_types = [
        {"name": name, "attributes": []} for name in sorted(seen_event_types)
    ]

    objects = []
    events = []
    for c in cycles:
        cycle_obj_id = f"cycle-{c.cycle_no:03d}"
        erc_obj_id = c.erc.id
        objects.append(
            {
                "id": cycle_obj_id,
                "type": "cycle",
                "attributes": [
                    {"name": "historical", "time": c.cycle_date.isoformat() + "T00:00:00Z", "value": str(c.historical)},
                    {"name": "cycle_date", "time": c.cycle_date.isoformat() + "T00:00:00Z", "value": c.cycle_date.isoformat()},
                ],
                "relationships": [],
            }
        )
        objects.append(
            {
                "id": erc_obj_id,
                "type": "erc",
                "attributes": [
                    {"name": "hypothesis", "time": c.cycle_date.isoformat() + "T00:00:00Z", "value": c.erc.hypothesis},
                ],
                "relationships": [],
            }
        )
        events.append(
            {
                "id": f"event-{c.cycle_no:03d}",
                "type": c.erc.evidence_state.value,
                "time": c.cycle_date.isoformat() + "T00:00:00Z",
                "attributes": [],
                "relationships": [
                    {"objectId": cycle_obj_id, "qualifier": "cycle"},
                    {"objectId": erc_obj_id, "qualifier": "erc"},
                ],
            }
        )

    return {
        "eventTypes": event_types,
        "objectTypes": object_types,
        "events": events,
        "objects": objects,
    }
