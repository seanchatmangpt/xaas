"""Crown-loop label normalization (W6-A8 seed subject).

Contract (tests/test_w6_crown_seed.py): strip surrounding whitespace,
lowercase, and collapse inner whitespace runs (tabs, repeated spaces) to a
single space.

W7-A8 crown-v2 seed subject: ``dedup_labels`` — Contract
(tests/test_w7_crown_seed.py): normalize every label through
``normalize_label`` first, then keep the FIRST occurrence of each distinct
normalized label, preserving original order.
"""


def normalize_label(value: str) -> str:
    return " ".join(value.split()).lower()


def dedup_labels(values: list[str]) -> list[str]:
    # Contract (tests/test_w7_crown_seed.py): every label goes through
    # normalize_label BEFORE the first-occurrence dedup, so labels differing
    # only in surrounding/inner whitespace collapse to one entry.
    return list(dict.fromkeys(normalize_label(value) for value in values))
