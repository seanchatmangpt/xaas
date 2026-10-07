# W81 — ggen Cargo.lock settle via real bounded build

- subject: /Users/sac/ggen @ 000bffb8f365c3d1d7ccef7dd8aec85ba34c08f3 (workspace 26.10.6)
- command: `cargo check --workspace` (2m 13s)

## cargo check result (tail -15, verbatim)

```
    Checking ggen-config v26.10.6 (/Users/sac/ggen/crates/ggen-config)
    Checking bcinr-pddl v26.6.26 (/Users/sac/ggen/crates/bcinr-pddl)
   Compiling ggen v26.10.6 (/Users/sac/ggen)
    Checking ggen-cheat-scanner v26.10.6 (/Users/sac/ggen/crates/ggen-cheat-scanner)
    Checking pm4pytest-cli v26.10.6 (/Users/sac/ggen/crates/pm4pytest-cli)
warning: ggen@26.10.6: Discovered 75 templates
warning: ggen@26.10.6: Discovered 12 core ontologies
    Checking praxis-graphlaw v26.7.9 (/Users/sac/ggen/crates/praxis-graphlaw)
    Checking praxis-core v26.7.2 (/Users/sac/ggen/crates/praxis-core)
    Checking ggen-marketplace v26.10.6 (...)
    Checking ggen-engine v26.10.6 (...)
    Checking ggen-lsp v26.10.6 (...)
    Checking ggen-cli-lib v26.10.6 (...)
    Checking ggen-mcp v0.1.0 (...)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 2m 13s
```

Exit: success (`Finished`). Zero compile errors. Only benign build-script warnings
(75 templates / 12 core ontologies discovered).

## Lock state

- `grep -c '26.10.6' Cargo.lock` → 9
- `git status --short Cargo.lock` → ` M Cargo.lock` (modified = lock settled)

## Classification

- Compile errors: none.
- LOCK_STALE (W50): RESOLVED — cargo rewrote Cargo.lock during the check and the
  file now shows as modified, with 9 entries at 26.10.6.
- Standing: ALIVE (real bounded build executed on exact subject 000bffb8).
