# Strategy B ultracode-run runtime (preserved alternative)

Branch `law/XAAS-26922-26-rt-B` (commits daa2aa1b, cbb3c435) implemented `ultracode-run.mjs`
as an independent "strategy B" runtime. `main` carries strategy A (`law/XAAS-26922-26-rt-A`)
at the live paths. Both edited the same three files from the same base, so the B versions
are kept here verbatim instead of overwriting or discarding either side.

## Files

- `templates/script-ultracode-run.mjs.tmpl` — strategy B template body
- `marketplace/xaas-fabric/scripts/ultracode-run.mjs` — strategy B rendered copy
- `test/ultracode-scripted-agent.mjs` — strategy B scripted agent backend

## See Also

- `HANDWRITTEN.md` — handwritten-residue rows for the ultracode-run runtime
