# Demo spec (proposal draft, not sent)

A live demonstration of the doctrine lab, run by the user from exact commits.
Each step names its command and the observation that counts as success; any
other observation is reported as observed, not explained away.

## Step 1: Materialize the exact lab commit

Command: `git -C autofde-lab archive d6becb595aedac4f18cab84f80bf5aa90e1a45e4 -- src pyproject.toml | tar -x -C lab`

Expected: The doctrine lab source tree at the bound commit, with no other checkout.

## Step 2: Run the lab with replay

Command: `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run --replay`

Expected: Exit 0; 252 episodes over 9 worlds; ledger valid; verify_run valid with no failures; authority NONE.

## Step 3: Reproduce in a second process

Command: `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run2 && shasum -a 256 run/report.json run2/report.json`

Expected: Both report.json files hash to 9f1d3a03188430dde6c8fad00c63714daff73aa3600229d9f521ec41e2edc6d4.

## Step 4: Show the equivalence clusters

Command: `python -m json.tool run/report.json`

Expected: Two primitive-equivalence clusters: sd-13 with sd-14, and sd-01 with sd-12.

## Step 5: Show the catalog boundary

Command: `python3 -m pytest tests/test_strategic_doctrine_pack.py -q -k 'not_vacuous or every_gate_returns_zero_rows'`

Expected: The no-excerpt and licensing non-claim gates pass on the catalog and fire on their mutants.

## Boundaries

- NC01: Not licensed: no license, permission or rights grant for the book or its title exists today.
- NC02: No affiliation implied: no author, publisher or rights holder has reviewed, supported or joined this work.
- NC03: No book excerpts: no text of the book appears; entries are ordinals with own short titles and own compositions.
- NC04: No real-world performance claims: all results are model-relative outputs of a repository-local fixture lab.
- NC05: Draft authored by the user: this packet is a proposal draft and has not been sent to anyone.

