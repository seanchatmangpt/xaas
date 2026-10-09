#!/usr/bin/env python3
"""Generate docs/reference/xaasweb-router-routes.md from the real router source.

Deterministic extraction of every route declaration in
lib/xaas_web/router.ex (XaasWeb.Router): verb + path + controller/plug +
action, each row traced to its exact source line. No hand-typed routes.

Run:  python3 scripts/gen_router_route_table.py
Check (byte-identical re-extract):  python3 scripts/gen_router_route_table.py --check
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROUTER = ROOT / "lib" / "xaas_web" / "router.ex"
OUT = ROOT / "docs" / "reference" / "xaasweb-router-routes.md"

VERB_MACROS = {"get", "post", "put", "patch", "delete", "options", "live"}
HEADER_MACROS = {"scope", "forward", "live_dashboard", "ash_admin"}


def join_path(prefix, path):
    if prefix.endswith("/") and path.startswith("/"):
        return prefix + path[1:]
    return prefix + path


def parse_router(lines):
    """Yield (lineno, kind, verb, full_path, target, action) tuples."""
    scope_stack = []  # (indent, prefix)
    for lineno, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())

        m = re.match(r'scope\s+"([^"]*)"(?:,\s*([\w.]+))?\s+do', stripped)
        if m:
            scope_stack.append((indent, m.group(1)))
            continue
        if stripped == "end" and scope_stack:
            while scope_stack and scope_stack[-1][0] >= indent:
                scope_stack.pop()
            continue

        # pop shallower scope ends: match indent to the scope's own indent
        if scope_stack and stripped == "end" and scope_stack[-1][0] >= indent:
            scope_stack.pop()
            continue

        prefix = "".join(p for _, p in scope_stack)

        m = re.match(
            r"(get|post|put|patch|delete|options)\(\s*\"([^\"]+)\"\s*,\s*"
            r"([\w.]+)\s*,\s*:([\w!?]+)",
            stripped,
        )
        if m and scope_stack:
            verb, path, ctrl, action = m.groups()
            yield lineno, "route", verb, join_path(prefix, path), ctrl, action
            continue

        m = re.match(r"live\(\s*\"([^\"]+)\"\s*,\s*([\w.]+)", stripped)
        if m and scope_stack:
            path, target = m.groups()
            yield lineno, "route", "live", join_path(prefix, path), target, ""
            continue

        m = re.match(r"forward\(\s*\"([^\"]*)\"\s*,\s*([\w.]+)", stripped)
        if m and scope_stack:
            path, target = m.groups()
            yield lineno, "forward", "forward", join_path(prefix, path), target, ""
            continue

        m = re.match(r"live_dashboard\(\s*\"([^\"]+)\"", stripped)
        if m and scope_stack:
            yield lineno, "route", "live_dashboard", join_path(prefix, m.group(1)), "Phoenix.LiveDashboard", ""
            continue

        m = re.match(r"ash_admin\(\s*\"([^\"]*)\"\s*\)", stripped)
        if m and scope_stack:
            yield lineno, "route", "mount", join_path(prefix, m.group(1)), "AshAdmin.Router (ash_admin mount)", ""
            continue

        m = re.match(r"mount\(\s*\)", stripped)
        if m and scope_stack:
            yield lineno, "route", "mount", join_path(prefix, "/*"), "XaasWeb.McpScope (forwards AshAi.Mcp.Router)", ""
            continue


def main():
    check = "--check" in sys.argv
    lines = ROUTER.read_text().splitlines(keepends=True)
    routes = list(parse_router(lines))

    out = []
    out.append("# XaasWeb.Router route table\n")
    out.append("GENERATED — do not edit. Source of truth: `lib/xaas_web/router.ex`.\n")
    out.append("Regenerate: `python3 scripts/gen_router_route_table.py`.\n")
    out.append("Verify: `python3 scripts/gen_router_route_table.py --check` (byte-identical re-extract).\n")
    out.append("\n")
    out.append("| Line | Verb | Path | Controller / Plug | Action |\n")
    out.append("|---|---|---|---|---|\n")
    for lineno, kind, verb, path, target, action in routes:
        out.append(f"| {lineno} | {verb} | `{path}` | `{target}` | {action or '—'} |\n")
    out.append(
        f"\nTotal: {len(routes)} route declarations "
        f"({sum(1 for r in routes if r[1] == 'route')} verb/live routes, "
        f"{sum(1 for r in routes if r[1] == 'forward')} forwards/mounts).\n"
    )
    body = "".join(out)

    if check:
        if OUT.read_text() != body:
            sys.stderr.write("STALE: docs/reference/xaasweb-router-routes.md does not match router source\n")
            sys.exit(1)
        print(f"OK: {len(routes)} route declarations match")
        return

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(body)
    print(f"wrote {OUT} ({len(routes)} route declarations)")


if __name__ == "__main__":
    main()
