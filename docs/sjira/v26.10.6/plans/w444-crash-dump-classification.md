# W444 — erl_crash.dump classification (v26.10.6)

File: `/Users/sac/xaas/erl_crash.dump` (51,099,221 bytes, mtime Oct 6 17:55)

## Dump header excerpt

```
=erl_crash_dump:0.5
Tue Oct  6 17:55:27 2026
Slogan: Runtime terminating during boot ({badarg,[{io,put_chars,
  [standard_error,[<<"** (EXIT from #PID<0.94.0>) an exception was raised:
  ** (ArgumentError) errors were found at the given arguments:
  1st argument: the device does not exist
  (stdlib 7.3) io.erl:202: :io.put_chars(:standard_error, ...)">>,...]]}])
System version: Erlang/OTP 28 [erts-16.4.0.2] ...
Current Process: <0.0.0> Running, program counter init:boot_loop/2 + 84
```

Decoded slogan binary: `** (EXIT from #PID<0.94.0>) an exception was raised: ** (ArgumentError) errors were found at the given arguments: 1st argument: the device does not exist (stdlib 7.3) io.erl:202: :io.put_chars(:standard_error, ...)`.

## Correlation

- Terminating process is `<0.0.0>` in `init:boot_loop/2` — the error_handler printing a boot-time crash report to `standard_error` found the device gone (stderr fd closed). This is the closed-fd crash-dump class, not a supervisor/application failure.
- Timestamp 17:55:27 sits in the 17:5x window of lane teardown/TaskStop activity (W316 kill, lane server teardown). A SIGKILL of a lane beam whose mix/test subprocess still held the inherited stderr produces exactly this: the next boot-time error print hits a dead fd and the runtime writes erl_crash.dump while terminating boot.
- No application module frames, no supervisor restart chain, no Elixir app crash in the traceback — the ArgumentError is the io device itself, not domain code.

## Verdict

CLASSIFIED — cause (a/c) fd-closure during lane teardown (w299b class), benign infrastructure kill artifact. NOT a real product crash. No FINDING frames (traceback contains only `init:boot_loop/2` and `<terminate process normally>`).

## Recommendation

DELETE-SAFE: YES. 51 MB dump of a boot-time stderr write to a closed fd. No product information lost.

Mitigation note: mix test lanes still inherit parent fds (PW servers already mitigated); lane launches should detach/redirect stderr (`</dev/null >&- 2>&-` or `Setsid`-style detach) so teardown kills cannot mint further dumps.
