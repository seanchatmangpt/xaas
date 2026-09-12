# Workflow Serialization Guard (RCA fix, vision-2030-2026-09-09-0020)

## Real problem observed this session

Launching multiple concurrent `Workflow` runs against this same repo caused real,
reproducible `mix compile` build-lock contention: agents blocked indefinitely on
"Waiting for lock on the build directory," some (`next-read-finish-orthogonal`'s
`checkout-actuation-wrap`/`library-policy-hardening` tasks) reported being unable to
complete their own verification at all as a direct result. A separate, worse incident
in the same session: a stray `asdf`-installed Elixir 1.18 process was found racing a
homebrew Elixir 1.19 `mix compile` on the same `_build`/`deps` tree, corrupting
protocol-consolidation artifacts and producing misleading, non-reproducible compile
errors (`RDF.XSD.true/0 is undefined`, `Nx.Container.Any` load failures, ambiguous
imports) that looked like real code bugs but were purely an execution-environment race.

## The guard (a real, minimal file lock — not a new service)

Any workflow script (or any Bash-driven compile loop) planning to run `mix compile`
concurrently with other agents against this repo should:

1. Before a compile-heavy stage, check for `/Users/sac/xaas/.claude/.workflow-compile.lock`.
   If present and its PID (`cat` the file) is a live process, wait/back off rather than
   compiling concurrently.
2. Write `<pid>:<timestamp>:<label>` to that lock file before a real `mix compile
   --force` / `mix test` run that needs the full `_build` tree to itself.
3. Remove the lock file when done (a `trap` or equivalent in a real shell script).
4. Prefer designing workflow batches so only ONE stage (typically the final `Verify`
   phase) does a full-repo `mix compile --force` — earlier implementation batches
   should make their edits and do a cheap syntax check (`elixir -e
   'Code.string_to_quoted!(File.read!(path))'` per touched file) rather than each
   independently racing a full recompile.

Steps 1-3 are now backed by a real helper: `.claude/workflow-compile-lock.sh`
(acquire/release/check functions, atomic `noclobber` file creation, PID-liveness-based
stale-lock reclaim, and an EXIT/INT/TERM trap for automatic release). Source it and
call `workflow_lock_acquire "<label>"` before a compile-heavy stage, run the stage,
then either let the trap release it on exit or call `workflow_lock_release`
explicitly. It also runs standalone: `.claude/workflow-compile-lock.sh
{acquire <label> [timeout_s]|release|check}`.

## See also

- `docs/vision/vision-2030-2026-09-09-0020.md` — the cycle this guard was written for.
