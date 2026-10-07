# W413 Receipt — ggen-marketplace toolchain pin (.tool-versions)

Lane: W413, v26.10.6 campaign
Subject: /Users/sac/ggen-marketplace (canonical checkout, uncommitted new file)
Closes: w365 typed finding (no .tool-versions)

## Version derivation

- CI (`/Users/sac/ggen-marketplace/.github/workflows/publish.yml:49`): `python-version: "3.12"` — the only version the repo names.
- `pyproject.toml`: `requires-python = ">=3.12,<4.0"` — floor confirmed.
- `scripts/marketplace.py`: `#!/usr/bin/env python3`, `from __future__ import annotations`; no syntax newer than 3.12 required (f-strings/dataclasses only).
- Local `python3 --version` is 3.14.3 (not the repo-named version; not used for the pin).
- No other tools required by scripts (no node/terraform/etc. in validate path).

## File content

`/Users/sac/ggen-marketplace/.tool-versions` (NEW):

```
python 3.12.8
```

(3.12.8 = latest 3.12.x patch line at pin time; CI pins the 3.12 minor.)

## Verification

`python3 scripts/marketplace.py validate` with the pin file present:

```
validated packs=305 manifests=305 ontologies=502 templates=1819 native_gates=1868 verifier_gates=21 profiles={"project":101,"projection":158,"semantic":46} diataxis=20
EXIT=0
```

## asdf-interpretation

The asdf python plugin is not installed locally (no output from `asdf plugin list | grep python`; no `~/.asdf/installs/python`). The file remains the correct declarative pin: any asdf/mise consumer cloning the repo now resolves python to 3.12.x, matching CI. Local validate ran on system 3.14.3 and passes (>=3.12 floor satisfied).

## Status

w365 finding CLOSED. No commits made (per lane contract).
