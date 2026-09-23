// @ts-check
const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  use: {
    // Real, already-running dev server (mix phx.server), not a mock.
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "http://localhost:4000",
  },
});
