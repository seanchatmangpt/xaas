"""Crown-loop label normalization (W6-A8 seed subject).

Contract (tests/test_w6_crown_seed.py): strip surrounding whitespace,
lowercase, and collapse inner whitespace runs (tabs, repeated spaces) to a
single space.
"""


def normalize_label(value: str) -> str:
    return " ".join(value.split()).lower()
