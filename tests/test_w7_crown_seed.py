"""W7 crown-v2 seed: bounded failing condition (the producer).

Seeded by the W7-A8 closed-loop qualification crown, not by product intent.
The observation -> work-order -> worker -> verifier -> reconciliation loop
consumes this failure as its signal. A worker must make this pass WITHOUT
weakening, skipping, or deleting it: implement ``eds.crown.dedup_labels``
exactly per the contract asserted below.

Distinct from the W6 seed: different function (dedup_labels, not
normalize_label), different dimension (normalization-before-dedup +
first-occurrence order, not whitespace collapse).
"""

from eds.crown import dedup_labels


def test_dedup_labels_normalizes_before_comparing():
    assert dedup_labels(["  Hello  ", "hello"]) == ["hello"]


def test_dedup_labels_preserves_first_occurrence_order():
    assert dedup_labels(["B", "a", "b", " A\t"]) == ["b", "a"]


def test_dedup_labels_receipt_guard_casefolds_caseless_equivalents():
    # Receipt-bound regression guard for CROWN2-001 (W9 crown): the repaired
    # normalize-before-dedup contract must hold under Unicode CASELESS
    # matching, not ASCII lowercasing. ``Straße`` and ``STRASSE`` denote the
    # same label, so the fold must be ``str.casefold()``-strength: labels
    # that are casefold-equivalent collapse to the first occurrence.
    assert dedup_labels(["Straße", "STRASSE"]) == ["strasse"]
    assert dedup_labels(["ẞ", "ss"]) == ["ss"]
