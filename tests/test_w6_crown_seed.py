"""W6 crown seed: bounded failing condition (the producer).

Seeded by the W6-A8 closed-loop demonstration, not by product intent. The
observation -> work-order -> worker -> verifier -> reconciliation loop consumes
this failure as its signal. A worker must make this pass WITHOUT weakening,
skipping, or deleting it: implement ``eds.crown.normalize_label`` exactly per
the contract asserted below.
"""

from eds.crown import normalize_label


def test_normalize_label_strips_and_lowercases():
    assert normalize_label("  Hello World  ") == "hello world"


def test_normalize_label_collapses_inner_whitespace():
    assert normalize_label("a\tb   c") == "a b c"
