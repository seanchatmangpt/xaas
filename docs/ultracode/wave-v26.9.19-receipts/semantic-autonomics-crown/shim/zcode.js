#!/usr/bin/env node
// Stand-in for `zcode gall-work --lease <file>` until zcode-cli PR #3 (src/gall-work.ts) is
// merged into the CLI checkout that has a runtime. It produces exactly the invocation
// gallWorkInvocation() produces and runs it through the real CLI; everything else is passed through.
"use strict";
const { readFileSync } = require("node:fs");
const { spawn } = require("node:child_process");
const path = require("node:path");

const REAL_CLI = process.env.ZCODE_REAL_CLI_DIR || "/Users/sac/dev/zcode-cli";
const args = process.argv.slice(2);
let runArgs = args;
let env = { ...process.env };

if (args[0] === "gall-work") {
  if (args.length !== 3 || args[1] !== "--lease") {
    console.error("Usage: zcode gall-work --lease <descriptor.json>");
    process.exit(2);
  }
  const lease = JSON.parse(readFileSync(args[2], "utf8"));
  if (lease.schema !== "gall.work-lease/1") {
    console.error("Unsupported GALL work lease schema.");
    process.exit(2);
  }
  if (!path.isAbsolute(lease.worktree)) {
    console.error("worktree must be an absolute path.");
    process.exit(2);
  }
  const prompt =
    "/xaas Call claim_next with provider_worker_id exactly " + JSON.stringify(lease.worker_id) +
    " and epoch_id exactly " + JSON.stringify(lease.epoch_id) + "; do not use any other values.";
  runArgs = ["--prompt", prompt, "--cwd", lease.worktree, "--json"];
  env = {
    ...env,
    XAAS_WORKER: "1",
    XAAS_LEASE_CWD: lease.worktree,
    GALL_WORK_ORDER_IRI: lease.work_order_iri,
    GALL_CHECKPOINT_IRI: lease.checkpoint_iri,
    GALL_GRAPH_DIGEST: lease.graph_digest,
    GALL_REPOSITORY_IDENTITY: lease.repository_identity,
    GALL_BASE_SHA: lease.base_sha,
  };
}

const child = spawn(process.execPath, [path.join(REAL_CLI, "bin", "zcode.js"), ...runArgs], {
  cwd: REAL_CLI,
  env,
  stdio: "inherit",
});
child.on("exit", (code, signal) => process.exit(code ?? (signal ? 128 : 1)));
