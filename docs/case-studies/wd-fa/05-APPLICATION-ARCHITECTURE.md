# Application Architecture

## Logical services

```
Source adapters
    ↓
Canonical evidence graph / OCEL
    ↓
Retrieval + candidate ranking
    ↓
Deterministic admission
    ↓
sJira work projection
    ↓
SA2A bounded capabilities
    ↓
Human / manager / architecture views
    ↓
Receipt + replay
```

## Reference implementation

The Friday reference implementation runs in XaaS/Ash and reuses:

- Ash resources;
- Postgres;
- OCEL persistence;
- sJira work semantics;
- SA2A capability/authority boundaries;
- Phoenix LiveView;
- Chicago-style tests;
- Playwright.

No second WD-specific persistence stack is required for the reference court.

## Generated implementation target

A separate ggen path SHOULD be able to project the same admitted semantics into:

- FastAPI;
- Pydantic;
- Next.js;
- Zod;
- browser court.

The generated application is not a second architecture. It is another projection.

## Human surface

The primary operator view is the **FA Morning Brief**:

```
what needs judgment
what is blocked
what is missing
what the system already constructed
what remains UNKNOWN
```

This is intentionally different from a chat-first UX.
