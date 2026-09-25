#!/usr/bin/env python3
"""sprtool — parser, validator, and renderer for Sparse Priming Representations (SPR).

An SPR document (per this repo's README) is "a distilled list of succinct
statements, assertions, associations, concepts, analogies, and metaphors",
written as short, complete sentences for an LLM audience.

Document model
--------------
* Statements are markdown bullet lines ("- " or "* ").
* Non-bullet lines are context (preamble/interstitial prose) and are carried
  through unchanged by render() but are not part of the SPR payload.

Validation rules (bounds derived from the example corpus in examples/:
8..54 statements, 4..12 words per statement; fences below are the generous
envelope around that evidence)
------------------------------------------------------------------------------
S1  at least MIN_STATEMENTS bullet statements
S2  every statement is non-empty and has at least MIN_WORDS words
S3  succinctness: no statement exceeds MAX_WORDS words
S4  no duplicate statements (case-insensitive)

Exit codes: 0 = valid / success, 1 = invalid or error. Diagnostics on stderr.
"""

import json
import re
import sys

MIN_STATEMENTS = 3
MIN_WORDS = 2
# Corpus maximum observed is 12 words (examples/HMCS.md); 20 is the fence.
MAX_WORDS = 20

_BULLET_RE = re.compile(r"^(?:-|\*)\s+(.*)$")


class SprError(Exception):
    """Raised on unreadable input or malformed document structure."""


def parse(text):
    """Parse SPR text into {"statements": [...], "context": [...]}.

    Raises SprError if the input contains no bullet statements at all (a
    document with zero statements cannot be an SPR).
    """
    statements = []
    context = []
    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip()
        match = _BULLET_RE.match(line)
        if match:
            statements.append((lineno, match.group(1).strip()))
        elif line.strip():
            context.append((lineno, line))
    if not statements:
        raise SprError("no SPR statements found (no '- ' bullet lines)")
    return {"statements": statements, "context": context}


def validate(doc):
    """Validate a parsed document. Returns a list of violation strings."""
    violations = []
    statements = doc["statements"]

    if len(statements) < MIN_STATEMENTS:
        violations.append(
            "S1: too few statements: %d (minimum %d)" % (len(statements), MIN_STATEMENTS)
        )

    seen = {}
    for lineno, statement in statements:
        words = statement.split()
        if not statement or len(words) < MIN_WORDS:
            violations.append(
                "S2: line %d: statement below %d words: %r" % (lineno, MIN_WORDS, statement)
            )
        if len(words) > MAX_WORDS:
            violations.append(
                "S3: line %d: statement is %d words (max %d): %r"
                % (lineno, len(words), MAX_WORDS, statement)
            )
        key = re.sub(r"\s+", " ", statement.lower())
        if key in seen:
            violations.append(
                "S4: line %d: duplicate of line %d: %r" % (lineno, seen[key], statement)
            )
        else:
            seen[key] = lineno
    return violations


def render(doc):
    """Render a parsed document back to canonical SPR form (one '- ' bullet
    per statement, in order). Round-trip stable for the statement payload."""
    return "\n".join("- " + statement for _, statement in doc["statements"]) + "\n"


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return parse(handle.read())
    except OSError as err:
        raise SprError("cannot read %s: %s" % (path, err))


def _cmd_validate(paths):
    failures = 0
    for path in paths:
        try:
            doc = load(path)
        except SprError as err:
            print("%s: ERROR: %s" % (path, err), file=sys.stderr)
            failures += 1
            continue
        violations = validate(doc)
        if violations:
            for violation in violations:
                print("%s: %s" % (path, violation), file=sys.stderr)
            failures += 1
        else:
            print(
                "%s: OK (%d statements, %d context lines)"
                % (path, len(doc["statements"]), len(doc["context"]))
            )
    return 1 if failures else 0


def _cmd_render(path):
    try:
        doc = load(path)
    except SprError as err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 1
    sys.stdout.write(render(doc))
    return 0


def _cmd_json(path):
    try:
        doc = load(path)
    except SprError as err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 1
    payload = {
        "statements": [statement for _, statement in doc["statements"]],
        "violations": validate(doc),
    }
    print(json.dumps(payload, indent=2))
    return 0 if not payload["violations"] else 1


def main(argv):
    usage = "usage: sprtool.py {validate|render|json} <file> [file ...]"
    if len(argv) < 3:
        print(usage, file=sys.stderr)
        return 1
    command, paths = argv[1], argv[2:]
    if command == "validate":
        return _cmd_validate(paths)
    if command == "render":
        return _cmd_render(paths[0])
    if command == "json":
        return _cmd_json(paths[0])
    print(usage, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
