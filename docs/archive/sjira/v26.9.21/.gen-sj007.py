"""Regenerate this milestone's work orders INTO THIS CHECKOUT (SJ-007 replay helper).

The default OUT in generate.py is the main ~/xaas checkout (unchanged); this wrapper
points it at the directory this file lives in, so a worktree/session can re-render
001-012 + index.json and byte-compare against the committed projection:

    python3 docs/sjira/v26.9.21/.gen-sj007.py

Then admit the set through the real kernel (from ~/ggen_igniter):

    WO=/tmp/sj007-wo.json mix run docs/sjira/v26.9.21/admit.exs

Expected: 010-012 byte-identical to committed; 007 differs only in the agent-layer
History append. Added by SJ-007 (2026-09-21); python/mix execution was gated in that
session, so this replay is the falsifier for the hand-rendered emission claim in
receipts/sj-007-verification.json.
"""
import os, runpy
here = os.path.dirname(os.path.abspath(__file__))
os.environ["OUT"] = here
os.environ.setdefault("WO_JSON", "/tmp/sj007-wo.json")
runpy.run_path(os.path.join(here, "generate.py"), run_name="__main__")
