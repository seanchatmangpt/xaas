defmodule Xaas.Graphlaw.LimitSeamsTest do
  @moduledoc """
  Lane W981k (SPEC-10 continuation) court — the remaining engine limits
  wired at their true consumption seams in `Xaas.Bridges.Graphlaw.assess/2`:

  - `max_request_bytes` (abi scope) — the JSON request (data + steps)
    rendered for `AshGraphLaw.law/3`;
  - `n3_max_term_bytes` (n3 scope) — the largest single N-Triples line in
    the rendered facts;
  - `n3_max_total_bytes` (n3 scope) — total facts bytes fed to the n3 step.

  Chicago-style: real EngineLimit rows on real sandboxed Postgres, real
  bridge calls against a dead server (the dead host isolates the gate from
  the engine: a gate refusal is `:limit_exceeded`, a gate pass-through is
  the host layer's `:host_not_started`). No mocks.

  Falsifier: a recorded engine limit on the rendered request/facts bytes
  must REFUSE a real over-limit payload with the typed `:limit_exceeded`
  verdict naming the limit's `refusal_name` — an EngineLimit row is not a
  projection only.

  Mutation rationale: deleting `gate_engine_limits/3` (restoring direct
  engine dispatch in `do_assess/3`) flips every exceedance court here RED —
  the over-limit payloads would sail to the dead host and return
  `:host_not_started` instead of the typed limit refusal. The under-limit
  and row-absent courts pin the W976 fail-open semantic (no recorded limit
  ⇒ no enforcement) so the gate cannot silently flip fail-closed.
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges.Graphlaw
  alias Xaas.Graphlaw.EngineLimit
  alias Xaas.Graphlaw.LimitGate

  @dead_server :w981k_graphlaw_host_never_started
  @subject Xaas.Bridges.subject()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_limit(attrs) do
    EngineLimit
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  # A claim whose rendered amount term is `chars` characters long: the
  # amount N-Triple line carries it byte-for-byte (US-ASCII here, so
  # bytes == characters).
  defp fat_claim(chars), do: %{"amount" => String.duplicate("9", chars), "limit" => 5}

  defp facts_bytes(claim), do: claim |> Graphlaw.purchase_facts(@subject) |> byte_size()

  defp assess(claim) do
    Graphlaw.assess(claim, server: @dead_server, subject: @subject)
  end

  ## (a) n3_max_term_bytes — largest single N-Triples line

  test "over-limit term bytes refuse typed at the bridge seam" do
    create_limit(%{
      name: "n3_max_term_bytes",
      value: 120,
      scope: "n3",
      source: "src/law.rs",
      unit: "bytes",
      refusal_name: "n3_term_bytes"
    })

    # Sanity: the fat claim's longest line really exceeds 120 bytes.
    fat = fat_claim(200)
    longest = fat |> Graphlaw.purchase_facts(@subject) |> String.split("\n", trim: true)
                 |> Enum.map(&byte_size/1) |> Enum.max()
    assert longest > 120

    assert {:refused, refusal} = assess(fat)
    assert refusal.code == :limit_exceeded
    assert refusal.class == :refused_admission
    assert refusal.limit == "n3_max_term_bytes"
    assert refusal.limit_value == 120
    assert refusal.refusal_name == "n3_term_bytes"
    assert refusal.broken_term == :mu_on_O
    assert refusal.message =~ "n3_max_term_bytes"
  end

  test "within-limit term bytes pass through to engine dispatch" do
    create_limit(%{
      name: "n3_max_term_bytes",
      value: 65_536,
      scope: "n3",
      source: "src/law.rs",
      unit: "bytes",
      refusal_name: "n3_term_bytes"
    })

    assert {:refused, refusal} = assess(%{"amount" => 10, "limit" => 5})
    assert refusal.code == :host_not_started
  end

  ## (b) n3_max_total_bytes — total facts bytes

  test "over-limit total facts bytes refuse typed at the bridge seam" do
    create_limit(%{
      name: "n3_max_total_bytes",
      value: 100,
      scope: "n3",
      source: "src/law.rs",
      unit: "bytes",
      refusal_name: "n3_total_bytes"
    })

    fat = fat_claim(200)
    assert facts_bytes(fat) > 100

    assert {:refused, refusal} = assess(fat)
    assert refusal.code == :limit_exceeded
    assert refusal.limit == "n3_max_total_bytes"
    assert refusal.limit_value == 100
    assert refusal.refusal_name == "n3_total_bytes"
  end

  test "within-limit total facts bytes pass through to engine dispatch" do
    create_limit(%{
      name: "n3_max_total_bytes",
      value: 268_435_456,
      scope: "n3",
      source: "src/law.rs",
      unit: "bytes",
      refusal_name: "n3_total_bytes"
    })

    assert {:refused, refusal} = assess(%{"amount" => 10, "limit" => 5})
    assert refusal.code == :host_not_started
  end

  ## (c) max_request_bytes — the rendered engine request (data + steps)

  test "over-limit request bytes refuse typed at the bridge seam" do
    create_limit(%{
      name: "max_request_bytes",
      value: 300,
      scope: "abi",
      source: "src/abi.rs",
      unit: "bytes",
      refusal_name: "request_bytes"
    })

    fat = fat_claim(200)
    request_bytes =
      Jason.encode!(%{
        "data" => %{"text" => Graphlaw.purchase_facts(fat, @subject), "dialect" => "ntriples"},
        "steps" => [
          %{"step" => "n3", "rules" => Graphlaw.rules()},
          %{"step" => "shacl", "shapes" => Graphlaw.purchase_shapes(@subject)}
        ]
      })
      |> byte_size()

    assert request_bytes > 300

    assert {:refused, refusal} = assess(fat)
    assert refusal.code == :limit_exceeded
    assert refusal.limit == "max_request_bytes"
    assert refusal.limit_value == 300
    assert refusal.refusal_name == "request_bytes"
  end

  test "within-limit request bytes pass through to engine dispatch" do
    create_limit(%{
      name: "max_request_bytes",
      value: 16_777_216,
      scope: "abi",
      source: "src/abi.rs",
      unit: "bytes",
      refusal_name: "request_bytes"
    })

    assert {:refused, refusal} = assess(%{"amount" => 10, "limit" => 5})
    assert refusal.code == :host_not_started
  end

  ## (d) row-absent fail-open (the W976 semantic, now court-pinned at these seams)

  test "no recorded limit rows: all three seams fail open and reach the engine" do
    assert {:refused, refusal} = assess(fat_claim(200))
    assert refusal.code == :host_not_started
  end

  test "limit row for a different scope does not gate (scope isolation)" do
    create_limit(%{
      name: "n3_max_term_bytes",
      value: 10,
      scope: "hooks",
      source: "src/hooks.rs",
      unit: "bytes",
      refusal_name: "n3_term_bytes"
    })

    assert {:refused, refusal} = assess(fat_claim(200))
    assert refusal.code == :host_not_started
  end

  ## (e) the depth gate from W976 still stands alongside the new gates

  test "json depth gate still refuses at the abi seam after the byte gates landed" do
    create_limit(%{
      name: "max_json_depth",
      value: 64,
      scope: "abi",
      source: "src/abi.rs",
      unit: "count",
      refusal_name: "json_depth"
    })

    assert {:refused, refusal} = assess(LimitGate.nest(64))
    assert refusal.code == :limit_exceeded
    assert refusal.limit == "max_json_depth"
  end
end
