#!/usr/bin/env python3
"""Generate docs/reference/config-surface.md from the real Elixir sources.

Deterministic extraction of the atom/string-key config surface of the xaas
OTP app, in three sections, each row traced to its exact source line:

1. Application config keys — every `Application.get_env/fetch_env!/put_env`
   call targeting the :xaas app with a literal atom key, across lib/.
2. EU AI Act refusal atoms — the REFUSED_EUAIA_* typed refusal atoms declared
   in the @typedref_atoms list of Xaas.Semantics.EuAiActAdmission, plus their
   string-key form in Xaas.Semantics.AiroRiskMapping.
3. Frontier-evidence actuation verdict atoms — every `{:error, :atom}` /
   `{:error, {:atom, ...}}` reason atom emitted by
   Xaas.Actuation.FrontierEvidence.

Run:  python3 scripts/gen_config_surface_ref.py
Check (byte-identical re-extract):  python3 scripts/gen_config_surface_ref.py --check
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
OUT = ROOT / "docs" / "reference" / "config-surface.md"

ENV_CALL = re.compile(
    r"Application\.(get_env|fetch_env!|get_env\?|put_env)\(\s*:xaas\s*,\s*:([a-z0-9_]+)"
)
TYPEDREF = re.compile(r"^\s*:(REFUSED_EUAIA_[A-Z_]+),?\s*$")
AIRO_STRING_KEY = re.compile(r'^\s*\{"(REFUSED_EUAIA_[A-Z_]+)",')
ERROR_ATOM = re.compile(r"\{:error, :([a-z0-9_]+)")
ERROR_TUPLED = re.compile(r"\{:error, \{:([a-z0-9_]+),")


def scan(pattern, path, group=1, pred=lambda m: True):
    rows = []
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        for m in pattern.finditer(line):
            if pred(m):
                rows.append((lineno, m.group(group), line.strip()))
    return rows


def rel(path):
    return path.relative_to(ROOT).as_posix()


def main():
    check = "--check" if "--check" in sys.argv else None

    # Section 1: application config keys (dedup per key, first call site wins)
    env_rows = {}
    for path in sorted(LIB.rglob("*.ex")):
        for lineno, key, _ in scan(ENV_CALL, path, group=2):
            env_rows.setdefault(key, (rel(path), lineno))
    env_keys = sorted(env_rows)

    # Section 2: EU AI Act refusal atoms (declared list, in declaration order)
    eu_file = LIB / "xaas" / "semantics" / "eu_ai_act_admission.ex"
    eu_seen = {}
    for ln, atom, _ in scan(TYPEDREF, eu_file):
        eu_seen.setdefault(atom, ln)
    eu_atoms = sorted(eu_seen.items(), key=lambda kv: kv[1])

    # String-key form of the same atoms in the AIRO risk mapping
    airo_file = LIB / "xaas" / "semantics" / "airo_risk_mapping.ex"
    airo_map = {atom: ln for ln, atom, _ in scan(AIRO_STRING_KEY, airo_file)}

    # Section 3: frontier-evidence verdict atoms (source order)
    fe_file = LIB / "xaas" / "actuation" / "frontier_evidence.ex"
    fe_atoms = []
    for lineno, line in enumerate(fe_file.read_text().splitlines(), 1):
        for m in ERROR_ATOM.finditer(line):
            fe_atoms.append((lineno, m.group(1), "bare"))
        for m in ERROR_TUPLED.finditer(line):
            fe_atoms.append((lineno, m.group(1), "tupled"))

    out = []
    out.append("# Config surface reference\n")
    out.append("GENERATED — do not edit. Source of truth: `lib/` (Elixir sources).\n")
    out.append("Regenerate: `python3 scripts/gen_config_surface_ref.py`.\n")
    out.append("Verify: `python3 scripts/gen_config_surface_ref.py --check` (byte-identical re-extract).\n")
    out.append(
        "\nEvery documented key traces to a real source line. This is the atom/string-key\n"
        "config surface of the xaas OTP app — the coverage denominator for key-set\n"
        "coverage gates (the [109]-class atom/string-key surface items).\n"
    )

    out.append("\n## Application config keys (`:xaas`)\n")
    out.append(
        "\nEvery `Application.get_env/fetch_env!/put_env(:xaas, :key, ...)` call site,"
        " deduped per key (first call site listed).\n"
    )
    out.append("\n| Key | First call site |\n|---|---|\n")
    for key in env_keys:
        f, ln = env_rows[key]
        out.append(f"| `:{key}` | `{f}:{ln}` |\n")
    out.append(f"\nTotal: {len(env_keys)} config keys.\n")

    out.append("\n## EU AI Act refusal atoms (`Xaas.Semantics.EuAiActAdmission`)\n")
    out.append(
        "\nThe typed refusal atoms declared in `@typedref_atoms`"
        " (declaration order), with their string-key form in the AIRO risk mapping.\n"
    )
    out.append("\n| Atom | String form | Declared | AIRO mapping |\n|---|---|---|---|\n")
    for _, atom in eu_atoms:
        airo_ln = airo_map.get(atom)
        out.append(
            f"| `:{atom}` | `{atom}` | `lib/xaas/semantics/eu_ai_act_admission.ex` | "
            + (f"`lib/xaas/semantics/airo_risk_mapping.ex:{airo_ln}`" if airo_ln else "—")
            + " |\n"
        )
    out.append(
        f"\nTotal: {len(eu_atoms)} refusal atoms"
        " (8 Art. 5(1) partitions + `REFUSED_EUAIA_MALFORMED_CANDIDATE`).\n"
    )

    out.append("\n## Frontier-evidence actuation verdict atoms (`Xaas.Actuation.FrontierEvidence`)\n")
    out.append(
        "\nEvery `{:error, :atom}` / `{:error, {:atom, ...}}` reason atom in the module,"
        " in source order.\n"
    )
    out.append("\n| Line | Atom | Form |\n|---|---|---|\n")
    for lineno, atom, form in fe_atoms:
        out.append(f"| {lineno} | `:{atom}` | {form} |\n")
    out.append(f"\nTotal: {len(fe_atoms)} verdict-atom occurrences.\n")

    body = "".join(out)

    if check == "--check":
        if OUT.read_text() != body:
            sys.stderr.write(
                "STALE: docs/reference/config-surface.md does not match lib/ sources\n"
            )
            sys.exit(1)
        print(
            f"OK: {len(env_keys)} config keys, {len(eu_atoms)} refusal atoms,"
            f" {len(fe_atoms)} verdict atoms match"
        )
        return

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(body)
    print(
        f"wrote {OUT} ({len(env_keys)} config keys, {len(eu_atoms)} refusal atoms,"
        f" {len(fe_atoms)} verdict atoms)"
    )


if __name__ == "__main__":
    main()
