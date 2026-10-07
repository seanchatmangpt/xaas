#!/usr/bin/env python3
"""W614 default agent leg: echo stub (real subprocess, no mocks).

Echoes the candidate prompt back as the agent reply. Replaced by the
real Goose CLI when present; absent today (GOOSE-ABSENT), so AGENT_CMD
plugs any real agent command.
"""
import sys

if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else ""
    print("ECHO: " + prompt)
