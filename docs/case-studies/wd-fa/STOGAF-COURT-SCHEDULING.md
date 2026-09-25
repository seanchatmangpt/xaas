# STOGAF Court Scheduling

The dedicated STOGAF workflow is PR-synchronized rather than push+PR duplicated.

It uses a concurrency group keyed to the PR and `cancel-in-progress: true`, so an obsolete head cannot hold scarce CI capacity ahead of the latest architecture subject.

This is an evidence-integrity choice: the only run that matters for promotion is the exact current subject.
