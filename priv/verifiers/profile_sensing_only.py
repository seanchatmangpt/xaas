#!/usr/bin/env python3
"""Backlog-script sentinel for repos whose sensing is owned by a registered profile.

    python3 profile_sensing_only.py --repo PATH

Deliberately exits 2 without deriving anything. `Xaas.Ultracode.Autonomic`'s
fallback law (sense_one/4) treats a non-zero backlog-script exit as "no script
applies" and hands the repo to its registry entry's `sensing:` profile over the
same provisioned tree. Registering this script for an alias is how a repo opts
out of the default `aps_backlog.py`, which would otherwise exit 0 with an empty
item list on any repo and shadow the profile.
"""
from __future__ import annotations

import argparse
import sys


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--repo", required=True)
    p.parse_args()
    print("no backlog script: sensing is owned by the registry entry's profile", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
