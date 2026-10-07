# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---

defmodule Xaas.MixProject do
  use Mix.Project

  # mix re-evaluates mix.exs on every invocation; an absent VERSION must
  # refuse typed at boot, not crash untyped (File.Error) before any task runs.
  version =
    case File.read("VERSION") do
      {:ok, contents} ->
        String.trim(contents)

      {:error, reason} ->
        Mix.raise(
          "REFUSED(mix_boot, detail: %{finding: \"required project boot input VERSION unreadable: #{inspect(reason)}\"})"
        )
    end

  @version version

  def project do
    [
      app: :xaas,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit, :mix],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # `mix test` is a built-in task Mix already runs under :test env by
  # convention -- a custom alias like `test.full` is not, and without
  # this it runs under :dev (real failure: `mix test.full` raised
  # "MIX_ENV=dev but the task you are running needs to be run in the
  # :test env"). Declaring it here is the real fix, not
  # MIX_ENV=test mix test.full at every call site.
  # xaas.sjira.yield (XAAS-26922-21) is a pure file fold whose stdout is one JSON
  # document piped to jq; running it in :test reuses the build `mix test` just made,
  # so no "Compiling N files" line lands on stdout ahead of the JSON.
  def cli do
    [preferred_envs: ["test.full": :test, "test.integration": :test, "xaas.sjira.yield": :test]]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Xaas.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # v26.8.21 keeps one Ash-native dependency graph. The exact resolved
  # versions remain receipt-bearing in mix.lock; constraints below describe
  # the supported compatibility envelope rather than duplicating lock state.
  defp deps do
    [
      # Real Ash deps ported verbatim from ~/dev-fresh/xaas/mix.exs -- the 89
      # real Ash.Resource modules in that repo were written against this
      # exact dep set (extensions: opentelemetry_ash, ash_ai, ash_onetime,
      # ash_iam, ash_rate_limiter, ash_cloak, ash_money/ash_double_entry,
      # ash_archival, ash_events, ash_paper_trail, ash_state_machine,
      # ash_oban, ash_admin, ash_graphql, ash_json_api, ash_authentication)
      # confirmed via a real grep of `extensions:`/`use` across those files
      # in Phase 3 -- porting only ash/ash_postgres (Phase 1's original,
      # narrower guess) would not compile against the real resource files.
      {:ash, "~> 3.0", override: true},
      {:ash_postgres, "~> 2.0"},
      {:opentelemetry_ash, "~> 0.1"},
      # Real finding, this session: only opentelemetry_api (the interface)
      # was a dependency, never opentelemetry (the actual SDK that creates
      # exportable spans) -- confirmed via `grep opentelemetry mix.lock`
      # returning only `_api`/`_ash`/`_process_propagator`. Without the
      # SDK application running, OpentelemetryAsh's real
      # OpenTelemetry.Tracer.set_attributes/1 calls run against the API
      # package's no-op default tracer -- nothing is actually exportable
      # or observable as real OTel data; OCEL v2 events only reliably
      # reached priv/ocel/ash-actions.ndjson, never a real span. Added
      # test-only to prove (or disprove) OCEL v2 data reaching a REAL
      # exported OTel span, not just the log file.
      {:opentelemetry, "~> 1.5", only: :test},
      # Re-added 2026-09-08: ash_ai 1.0.3 for the Ash MCP server
      # (mix ash_ai.gen.mcp). Verified via a real `mix deps.get` +
      # `mix compile --force` -- full xaas app + all deps compiled clean
      # (302 files, exit 0). The 0.8.2-era finch/req_llm conflict noted
      # historically here no longer reproduces against the resolved
      # finch 0.23.0 / req_llm 1.20.0.
      {:ash_ai, "~> 1.0"},
      # ash_ai's `prompt/2` generic-action impl (AshAi.Actions.Prompt) is
      # gated behind `Code.ensure_loaded?(ReqLLM)` -- it is an optional dep
      # of ash_ai (see deps/ash_ai/mix.exs) and stays unfetched/uncompiled
      # unless declared directly here. Pinned to the same "~> 1.18" range
      # ash_ai itself declares. ReqLLM resolves the Groq API key via its
      # own default env-key lookup (GROQ_API_KEY) -- no manual key wiring
      # in this app. See lib/xaas/library/explainer/groq_adapter.ex.
      {:req_llm, "~> 1.18"},
      {:ash_a2a,
       git: "https://github.com/seanchatmangpt/ash_a2a.git",
       ref: "86214551de93fc8ab395f5ed0b84d32922a5d99b",
       override: true},
      {:ash_r2rml,
       git: "https://github.com/seanchatmangpt/ash_r2rml.git",
       ref: "0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7",
       override: true},
      {:a2a, "~> 0.2"},
      # Fabric planes (law, evidence/process). Test/dev only: path deps would break the
      # Docker prod build (see the ex4pm note below); fabric adapters call them via apply/3.
      {:ash_graphlaw, path: "../ash_graphlaw", override: true},
      {:ash_surface, path: "../ash_surface"},
      {:ash_affidavit, path: "../ash_affidavit", override: true},
      {:bandit, "~> 1.5"},
      {:ash_onetime, "~> 1.0"},
      {:ash_iam, "~> 2.0"},
      {:hammer, "~> 7.0"},
      {:ash_rate_limiter, "~> 2.0"},
      {:cloak, "~> 1.0"},
      {:ash_cloak, "~> 0.3"},
      {:ex_money_sql, "~> 2.0"},
      {:ash_money, "~> 0.2"},
      {:ash_double_entry, "~> 1.0"},
      {:ash_archival, "~> 2.0"},
      {:ash_events, "~> 0.7"},
      {:ash_paper_trail, "~> 0.6"},
      {:ash_state_machine, "~> 0.2"},
      {:oban, "~> 2.0"},
      {:ash_oban, "~> 0.8"},
      {:ash_admin, "~> 1.3"},
      {:ash_graphql, "~> 1.0"},
      {:absinthe_plug, "~> 1.5"},
      {:open_api_spex, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_typescript, "~> 0.17"},
      # Real re-check this session: the original conflict was
      # ash_authentication_phoenix needing phoenix_html ~> 4.0 against a
      # then-pinned ~> 3.3. phoenix_html is now ~> 4.1 (bumped for
      # ash_admin, commit 062f3d0) -- re-attempting for real, Ash-maximal
      # per explicit user direction (prefer real Ash-ecosystem libraries
      # over hand-rolled/non-Ash equivalents, e.g. Petal's plain
      # Ecto-based auth-adjacent components). 2.9.3 -> 4.17.0 (2026-10-04):
      # upstream v3 moved to Tailwind 4 and v4 removed Alpine.js and ships
      # JS hooks -- app.css/@config wiring and app.js hook registration
      # follow the upstream UPGRADE_GUIDE.
      {:petal_components, "~> 4.0"},
      # Security floor: 2.17.4 fixes EEF-CVE-2026-86533 (CRITICAL, revoked session
      # accepted) and EEF-CVE-2026-81632 (HIGH) reported by `mix deps.get`.
      {:ash_authentication_phoenix, "~> 2.17 and >= 2.17.4"},
      {:bcrypt_elixir, "~> 3.0"},
      # Security floor: 4.15.0 fixes the 15 EEF-CVE-2026-* advisories `mix deps.get`
      # reports against 4.14.2 (5 CRITICAL: OAuth2 account takeover, remember-me
      # session replacement, magic-link replay, unenforced require_confirmed_with,
      # unchecked revoked-session jti).
      {:ash_authentication, "~> 4.15"},
      {:picosat_elixir, "~> 0.2"},
      # Real Phoenix.LiveViewTest HTML-parsing dependency (element/render
      # assertions in XaasWeb.AutofdeLab.StatusLiveTest need it).
      {:lazy_html, ">= 0.1.0", only: :test},
      {:sourceror, "~> 1.8", runtime: false},
      # :ex4pm's `use Igniter.Mix.Task` needs Igniter at compile time in every env.
      {:igniter, "~> 0.6", runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:dns_cluster, "~> 0.1.3"},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:stream_data, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:heroicons, "~> 0.5"},
      {:jason, "~> 1.2"},
      # RFC 8785 canonical JSON for cross-runtime release-closure identity.
      # Already locked transitively; explicit because deployment code calls it.
      {:jcs, "~> 0.2"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.9.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      # Next Read case study (docs/case-studies/next-read/): real local
      # Hugging Face sentence-embedding inference for the ranker's semantic
      # term (lib/xaas/library/embeddings.ex). Not ash_ai/pgvector -- ash_ai
      # stays dropped (see the ash_ai comment above); Nx/Bumblebee/EXLA have
      # no dependency conflict with the resolved Finch version and run fully
      # local/offline once weights are cached, so no student data leaves the
      # process boundary for ranking.
      {:nx, "~> 0.9"},
      {:bumblebee, "~> 0.6"},
      {:exla, "~> 0.9"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:prom_ex, "~> 1.9.0"},
      {:ex_aws, "~> 2.1"},
      {:sweet_xml, "~> 0.6"},
      # Was pinned to "~> 0.5.7" -- req_llm 1.20.0's default_attach/finch_option
      # (deps/req_llm/lib/req_llm/provider/defaults.ex) always merges `finch:
      # [name: ...]` (a keyword list) into the Req request. Req 0.5.x's
      # Req.Finch.finch_name/1 (deps/req/lib/req/finch.ex) only ever accepted
      # `:finch` as a bare atom pool name, so it fed the raw keyword list
      # straight into Registry.lookup/2 as the registry name, crashing every
      # real ash_ai `prompt/2` call with `FunctionClauseError` in
      # `Registry.lookup/2`. Req 0.7.x added first-class support for `finch:
      # [name: ..., ...]` (see `finch_name_options/1`), which is the contract
      # req_llm 1.20.0+ actually relies on -- widen the constraint so
      # `mix deps.get` can resolve the fixed Req instead of staying on 0.5.17.
      {:req, "~> 0.5"},
      # Real Stripe Elixir SDK -- webhook receiver's real
      # Stripe.Webhook.construct_event/3 signature verification (see
      # XaasWeb.StripeWebhookController).
      {:stripity_stripe, "~> 2.17"},
      # Semantic Jira bridge seam (v26.10.1-loop lane X1): hex 26.9.29 defined
      # TransitionLog.event_digest/1 as `defp`, so the bridge was pinned to the
      # post-G1 git ref. ggen_igniter 26.10.1 (hex) ships the seam: public
      # `event_digest/1` + `legacy_event_digest/1`, the snapshot-bound
      # descriptor contract, sj:targetPack, execute target_pack enforcement,
      # and the receipts v2 law. The git pin is reverted per its own contract.
      {:ggen_igniter, "~> 26.10.1"},
      {:faker, "~> 0.18", only: [:dev, :test]},
      # Real dependency on ex4pm's Ex4pm.OCEL, so OcelForwarder validates
      # the envelope with the actual downstream validator instead of a
      # hand-documented understanding of its shape (see
      # lib/xaas/telemetry/ocel_forwarder.ex).
      #
      # k8s-fortune5-hardening pass real fix: was `path: "../ex4pm"`, which
      # made the Docker image unbuildable -- the build context is `xaas/`
      # only, so `/ex4pm` never exists inside the builder stage
      # ("Cannot compile dependency :ex4pm because it isn't available"),
      # confirmed via a real failed `docker build`, not assumed. ex4pm is a
      # Hex ex4pm 26.9.9 is production-BUILD_BROKEN because its
      # generator Mix task unconditionally loads the dev/test-only Igniter
      # dependency. Until a repaired Hex artifact is published, consume the
      # exact admitted source candidate from ex4pm PR #46. The immutable ref
      # gives source identity for this candidate court; it does not imply
      # merge or publication standing for ex4pm.
      {:ex4pm,
       git: "https://github.com/seanchatmangpt/ex4pm.git",
       ref: "9f7aecda87e5110f668f824bbae760f6c97f88e1",
       override: true},
      # v26.9.27: ash_pplan owns FOND policy semantics (AshPPlan.FOND +
      # FOND.Synthesis, strong/strong-cyclic). XaaS consumes it for the
      # WaveLoop recovery policy instead of growing a second planner.
      # Ref advanced 2026-10-06 (v26.10.6 convergence): origin/main 5f10c97 — A2A durable Facade present at this ref.
      {:ash_pplan,
       git: "https://github.com/seanchatmangpt/ash_pplan.git",
       ref: "5f10c9798b783c2023a6bfaa892c000630476f05"},
      # MarketplacePplanExplorerLive parses priv/gcp/marketplace_lifecycle.ttl
      # (p-plan/prov workflow ontology) with RDF.Turtle and queries it with
      # SPARQL.ex. Both were already resolved transitively via ggen_igniter
      # (rdf 3.0.1 / sparql 0.3.12 in mix.lock); declared directly so the
      # LiveView compiles against a stable API contract.
      {:rdf, "~> 3.0"},
      {:sparql, "~> 0.3"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      # Regenerate the ash_surface projection into priv/ash_surface/ (served
      # statically at /ash_surface by XaasWeb.Endpoint). Re-runnable at any
      # time, including under MIX_ENV=prod now that the ash_surface path dep
      # is available in all environments.
      ash_surface: ["xaas.ash_surface"],
      "chicago.render": ["xaas.chicago.render"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Full/Chicago-integration suite: everything the fast default `mix
      # test` excludes (see test/test_helper.exs's `exclude:` list) --
      # real network retries against unreachable services (:external),
      # a real Groq API call requiring GROQ_API_KEY (:external_llm), real
      # nested `mix`/`git`/OS-port subprocesses (:subprocess, e.g.
      # xaas.verify_and_commit, xaas.ingest_capability_receipts,
      # demo_planner_reactor_test's real Ports+`ps` checks), real
      # property-based generative tests (:property), real
      # concurrent-connection-pool stress (:stress), real live-kind-pod
      # (:kind), and real cnv-deploy-dependent (:requires_cnv_deploy)
      # tests. Run this before merge/CI, not on every fast inner-loop run.
      "test.full": [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "test --include stress --include kind --include requires_cnv_deploy --include external --include external_llm --include subprocess --include property"
      ],
      # Chicago/integration run: the real-network (:external, :external_llm),
      # real-subprocess (:subprocess), and real property-based (:property)
      # tests that only need what's already available in a real local dev
      # environment (Postgres, network, `mix`/`git` on PATH) -- unlike
      # `test.full`, this deliberately excludes :stress
      # (connection-pool-hungry concurrency races), :kind, and
      # :requires_cnv_deploy, which need a live k8s cluster this
      # environment does not have.
      "test.integration": [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "test --include external --include external_llm --include subprocess --include property"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
