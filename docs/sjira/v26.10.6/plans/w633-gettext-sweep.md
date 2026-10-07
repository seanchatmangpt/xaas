# W633 — gettext stale doc-comment sweep

- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, lane build root `_build-laneW633`
- Scope honored: only `lib/xaas_web/gettext.ex` (doc-comment ~:29) + this receipt.

## Diff (one hunk, comment-only)

```diff
--- a/lib/xaas_web/gettext.ex
+++ b/lib/xaas_web/gettext.ex
@@ -29 +29 @@
-  New code should prefer `use Gettext, backend: KanbanWeb.Gettext`. The local
+  New code should prefer `use Gettext, backend: XaasWeb.Gettext`. The local
```

Instructional intent preserved (compatibility-macro guidance unchanged); stale
`KanbanWeb.Gettext` reference replaced with the c5f127cc rename target
`XaasWeb.Gettext`.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW633 mix compile
```

Result (observed 2026-10-06, cold lane build root):

```
Generated xaas app
exit=0
```

Compile exit 0; one-hunk comment-only diff confirmed above.
