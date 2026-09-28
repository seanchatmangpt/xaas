// Agent-facing lease CLI. The worker uses it to persist the claim result
// so it can recover its lease token across tool calls within this worktree
// (host-side admission is the PreToolUse gate, scripts/xaas-gate.mjs, active
// only under XAAS_WORKER=1; every admit/close call is otherwise the worker's own).
//
//   node xaas-lease.mjs save   '<claim JSON>' [--force]  # writes lease for this cwd
//   node xaas-lease.mjs get                               # prints lease JSON or null
//   node xaas-lease.mjs clear                              # drops the lease
//
// `save` refuses to clobber a still-live lease for this cwd that carries a
// DIFFERENT lease_token (exit 65) unless the existing lease has already
// expired, belongs to the same token (a renewal/re-save), or `--force` is
// passed explicitly. Without this, a second claim_next in the same worktree
// would silently overwrite the first worker's only capability with no
// warning -- the server-side claim is race-safe (lease.ex's filtered bulk
// update), but this client-side state file was not.
import { readFile, rm } from "node:fs/promises";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import path from "node:path";

const [, , cmd, payload, ...rest] = process.argv;
const force = rest.includes("--force");

const STATE_DIR = path.join(tmpdir(), "xaas-fabric");
// Per-epoch keying: when the dispatcher set XAAS_LEASE_ID, the worker's own
// state lives at the -<id>-suffixed path (zcode-cli gall-work.ts
// leaseFilePathsKeyed; the PreToolUse gate reads the same key first). This
// CLI must address the SAME key or a keyed worker cannot recover its lease
// across tool calls. The legacy per-cwd path stays as fallback so
// non-keyed sessions are byte-identical in behavior.
const hash = createHash("sha256").update(process.cwd()).digest("hex");
const leaseId = (process.env.XAAS_LEASE_ID ?? "").trim().replace(/[^A-Za-z0-9._-]/g, "_");
const keyedFile = leaseId ? path.join(STATE_DIR, `${hash}-${leaseId}.json`) : null;
const legacyFile = path.join(STATE_DIR, `${hash}.json`);
const file = keyedFile ?? legacyFile;

async function readFirstExisting() {
  for (const candidate of keyedFile ? [keyedFile, legacyFile] : [legacyFile]) {
    try {
      return await readFile(candidate, "utf8");
    } catch {
      // try the next candidate key
    }
  }
  return null;
}

async function readExistingLease() {
  try {
    const raw = await readFirstExisting();
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function isLive(lease) {
  if (!lease || typeof lease.lease_token !== "string" || !lease.lease_token) return false;
  const expiresAt = Date.parse(lease.lease_expires_at ?? "");
  return Number.isFinite(expiresAt) && expiresAt > Date.now();
}

if (cmd === "save") {
  const { writeFile, mkdir } = await import("node:fs/promises");

  let parsedPayload = null;
  try {
    parsedPayload = JSON.parse(payload);
  } catch {
    // Non-JSON payload: fall through to the write below unchanged (existing
    // behavior); there is no lease_token to compare against, so treat as
    // never conflicting rather than guessing.
  }

  if (!force && parsedPayload) {
    const existing = await readExistingLease();
    if (
      isLive(existing) &&
      existing.lease_token !== parsedPayload.lease_token
    ) {
      process.stderr.write(
        JSON.stringify({
          error: "lease_conflict",
          detail:
            `refusing to overwrite a live lease (${existing.lease_token}) for this cwd ` +
            `with a different lease (${parsedPayload.lease_token ?? "(none)"}); ` +
            "the prior lease has not expired -- wait for it to expire, close/refuse it " +
            "first, or pass --force to override deliberately.",
        }) + "\n"
      );
      process.exit(65);
    }
  }

  await mkdir(STATE_DIR, { recursive: true, mode: 0o700 });
  await writeFile(file, payload, { mode: 0o600 });
  process.stdout.write("saved\n");
} else if (cmd === "get") {
  const raw = await readFirstExisting();
  process.stdout.write(raw ?? "null\n");
} else if (cmd === "clear") {
  for (const candidate of keyedFile ? [keyedFile, legacyFile] : [legacyFile]) {
    await rm(candidate, { force: true });
  }
  process.stdout.write("cleared\n");
} else {
  process.stderr.write("usage: xaas-lease.mjs save '<json>' | get | clear\n");
  process.exit(64);
}
