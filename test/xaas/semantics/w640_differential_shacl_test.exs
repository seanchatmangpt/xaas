defmodule Xaas.Semantics.W640DifferentialShaclTest do
  @moduledoc """
  W640 differential-admission court (W639 design, C14 "one admission kernel"
  falsifier): the host-side hand-rolled `violations/1`
  (`Mix.Tasks.Xaas.Airo.CompileShacl`) and the guest-side `op:"shacl"` through
  the packed-u64 `gl_call` of the W637 graphlaw WASM artifact must AGREE on a
  corpus of conforming/violating AIRO instance graphs.

  Corpus (fresh root per case; the base graph is re-read, never mutated):
    - C0 `profile-bytes`   — the raw W615 profile.shacl.ttl bytes as the shapes
                             argument. Originally asserted guest TYPED refusal
                             of the illegal `airo#shapes#` IRI (W640); flipped
                             in W650f2 to guest-admission post-repair
                             (w650i finding-(b) repair, w650f stale-court
                             witness).
    - C1 `conforming`      — W982m real graph, unmodified.
    - C2 `control-unbound` — ActuationKernel's mitigatesRiskConcept triple dropped.
    - C3 `risk-uncited`    — every control binding of UnreceiptedActuationRisk
                             removed except ActuationKernel's, leaving the
                             Risk uncited while every RiskControl stays bound.
    - C4 `both`            — C2 + C3 mutations combined.

  Agreement predicate: identical conforms-boolean AND identical violated
  focus-node sets on the repaired shapes surface. Disagreement = typed
  REFUSED (failing assertion names the diverging side per focus).

  Guest-side transport (disclosed): executes on a REAL WASI store
  (`Wasmex.Store.new_wasi/1` — wasmex's native wasi_snapshot_preview1, not
  zero-value stubs) because GraphlawWasm's own zero-stub instantiation TRAPS
  on real op:"shacl" workloads (witnessed; receipt finding (c)). Artifact
  identity stays pinned via `GraphlawWasm.verify_digest/2` to the W637
  digest fc23a292… (W647 rotation, reconciled by W650n); export surface re-judged per boot.
  """

  use ExUnit.Case, async: false

  @artifact_path Path.expand("priv/graphlaw.wasm", File.cwd!())
  @pin_file Path.expand("priv/graphlaw.wasm.sha256", File.cwd!())
  @call_timeout_ms 60_000

  @base_ttl File.read!(Path.expand("priv/airo_risk_description.ttl", File.cwd!()))
  @raw_shapes File.read!(Path.expand("priv/airo/profile.shacl.ttl", File.cwd!()))

  # Minimal repair of the disclosed W615 generator defect: the `airo-sh:`
  # prefix IRI carries an illegal second `#`. `airo#shapes-` keeps every
  # generated shape IRI under the AIRO namespace family.
  @shapes String.replace(@raw_shapes, "https://w3id.org/airo#shapes#", "https://w3id.org/airo#shapes-")

  @w982m "https://xaas.chatman-ecosystem.dev/airo/xaas#"

  @kernel_line "w982m:ActuationKernel airo:mitigatesRiskConcept w982m:UnreceiptedActuationRisk , w982m:ForgedActuationArtifact .\n"

  @trc_drop_after "w982m:TypedRefusalCourt airo:detectsRiskConcept w982m:ForgedActuationArtifact ;\n    airo:mitigatesRiskConcept w982m:ForgedActuationArtifact , w982m:UnreceiptedActuationRisk ."

  @trc_keep "w982m:TypedRefusalCourt airo:detectsRiskConcept w982m:ForgedActuationArtifact ;\n    airo:mitigatesRiskConcept w982m:ForgedActuationArtifact ."

  @iaaf_block "w982m:InternalApiAuthFloor\n    airo:mitigatesRiskConcept w982m:UnauthenticatedInternalAccess , w982m:UnreceiptedActuationRisk ;\n    airo:detectsRiskConcept w982m:UnauthenticatedInternalAccess ."

  @iaaf_keep "w982m:InternalApiAuthFloor\n    airo:mitigatesRiskConcept w982m:UnauthenticatedInternalAccess ;\n    airo:detectsRiskConcept w982m:UnauthenticatedInternalAccess ."

  @freeze_binding_block """
  w982m:FreezeWindowGate airo:mitigatesRiskConcept w982m:FreezeWindowViolation ;
      airo:detectsRiskConcept w982m:FreezeWindowViolation .
  """

  # Remove every binding citation of UnreceiptedActuationRisk (kernel line +
  # TRC/IAAF mitigates objects), leaving hasResidualRisk (not a binding
  # predicate) as the only reference.
  defp uncite_risk(ttl) do
    ttl
    |> drop_exact(@kernel_line)
    |> String.replace(@trc_drop_after, @trc_keep)
    |> String.replace(@iaaf_block, @iaaf_keep)
  end

  # ---------------------------------------------------------------------
  # Cases
  # ---------------------------------------------------------------------

  # C0 history (W640 original, pre-repair): the raw W615 profile bytes carried
  # the illegal `airo#shapes#` IRI (second `#`), and the guest refused them
  # TYPED — EngineRejected / dialect Turtle / `iri-disallowed-char`. The W615
  # generator owner repaired finding (b) (w650i's profile repair →
  # `airo#shapes-`; witnessed stale-court by W650f, receipt
  # w650f-unification-verify.md), so the guest now ADMITS the raw bytes.
  # W650f2 flips C0 to the post-repair expectation:
  test "C0 profile bytes: guest ADMITS the repaired W615 profile, agreeing with the host" do
    inst = start_instance()

    # The on-disk profile is the repaired surface; @shapes is the byte-level
    # no-op witness of the old repair transform (replace finds nothing left).
    assert @shapes == @raw_shapes

    resp = invoke_raw(inst, @raw_shapes)
    assert resp["ok"] == true, "guest refuses the repaired profile: #{inspect(resp["error"])}"

    # Agreement predicate (same as C1-C4): host and guest must agree on the
    # repaired profile-bytes surface.
    host = host_violations(@raw_shapes)
    host_foci = host |> MapSet.new(& &1.focus.value)

    assert resp["conforms"] == (host_foci == MapSet.new()),
           "host/guest conforms-boolean disagreement on repaired profile bytes"
  end

  test "C1 conforming: both checkers admit the W982m graph" do
    assert [] == host_violations(@base_ttl), "host checker refuses the conforming corpus root"

    resp = guest(@base_ttl)
    assert resp["ok"] == true
    assert resp["conforms"] == true, "guest op:shacl refuses the conforming corpus root"
    assert guest_foci(@base_ttl) == MapSet.new()
  end

  test "C2 control-unbound: both refuse ActuationKernel, host sees exactly one violation" do
    ttl = drop_exact(@base_ttl, @kernel_line)

    assert [%{focus: %{value: @w982m <> "ActuationKernel"},
              constraint: :control_binds_risk_concept}] = host_violations(ttl)

    resp = guest(ttl)
    assert resp["ok"] == true
    assert resp["conforms"] == false, "guest op:shacl ADMITS a control-unbound instance"
    assert guest_foci(ttl) == MapSet.new([@w982m <> "ActuationKernel"])
  end

  # Unciting a Risk NECESSARILY removes every binding predicate to it, so the
  # controls whose last binding is dropped become unbound too: the minimal
  # uncite case fires BOTH constraint classes on both sides.
  test "C3 risk-uncited: both refuse the uncited UnreceiptedActuationRisk + the unbound kernel" do
    ttl = uncite_risk(@base_ttl)

    host = host_violations(ttl)
    host_foci = host |> MapSet.new(& &1.focus.value)

    assert host_foci ==
             MapSet.new([
               @w982m <> "ActuationKernel",
               @w982m <> "UnreceiptedActuationRisk"
             ]),
           "unexpected host violation set: #{inspect(host_foci)}"

    assert Enum.any?(host, &(&1.constraint == :control_binds_risk_concept))
    assert Enum.any?(host, &(&1.constraint == :risk_cited_by_control))

    resp = guest(ttl)
    assert resp["ok"] == true
    assert resp["conforms"] == false, "guest op:shacl ADMITS an uncited-risk instance"
    assert guest_foci(ttl) == host_foci
  end

  # C4 = C3 + dropping FreezeWindowGate's bindings of the HAZARD
  # FreezeWindowViolation (not an airo:Risk individual): the hazard is uncited
  # but must produce NO violation on either side — a negative-differential
  # witness that both checkers scope to airo:Risk, not to any uncited node.
  test "C4 hazard-uncited: uncited FreezeWindowViolation (Hazard) violates on NEITHER side" do
    ttl =
      @base_ttl
      |> uncite_risk()
      |> drop_exact(@freeze_binding_block)

    host_foci = host_violations(ttl) |> MapSet.new(& &1.focus.value)

    assert host_foci ==
             MapSet.new([
               @w982m <> "ActuationKernel",
               @w982m <> "UnreceiptedActuationRisk",
               @w982m <> "FreezeWindowGate"
             ]),
           "unexpected host violation set: #{inspect(host_foci)}"

    resp = guest(ttl)
    assert resp["ok"] == true
    assert resp["conforms"] == false

    guest = guest_foci(ttl)
    assert guest == host_foci
    refute MapSet.member?(guest, @w982m <> "FreezeWindowViolation"),
           "guest flagged the uncited Hazard"
  end

  # ---------------------------------------------------------------------
  # Host side — the hand-rolled court (real RDF.Graph, real violations/1)
  # ---------------------------------------------------------------------

  defp host_violations(ttl) do
    assert {:ok, graph} = RDF.Turtle.read_string(ttl)
    Mix.Tasks.Xaas.Airo.CompileShacl.violations(graph)
  end

  # ---------------------------------------------------------------------
  # Guest side — real op:"shacl" through packed-u64 gl_call over the
  # digest-pinned W637 artifact, WASI store (real wasmex WASI impl).
  # ---------------------------------------------------------------------

  defp guest(ttl) do
    inst = start_instance()

    case Xaas.Semantics.GraphlawWasm.invoke(
           inst,
           %{
             "op" => "shacl",
             "data" => %{"text" => ttl, "dialect" => "turtle"},
             "shapes" => @shapes
           },
           timeout: @call_timeout_ms
         ) do
      {:ok, resp} -> resp
      {:error, refusal} -> flunk("op:shacl refused: #{inspect(refusal)}")
    end
  end

  # C0 runs the raw profile bytes through the same transport.
  defp invoke_raw(inst, raw_shapes) do
    case Xaas.Semantics.GraphlawWasm.invoke(
           inst,
           %{
             "op" => "shacl",
             "data" => %{"text" => @base_ttl, "dialect" => "turtle"},
             "shapes" => raw_shapes
           },
           timeout: @call_timeout_ms
         ) do
      {:ok, resp} -> resp
      {:error, guest_refusal} -> flunk("op:shacl refused: #{inspect(guest_refusal)}")
    end
  end

  # Guest transport: wasmex with a REAL WASI store (wasmex's native
  # wasi_snapshot_preview1 implementation — real clock/random/env, not
  # zero-value stubs). Disclosed: GraphlawWasm's own zero-value WASI stubs
  # TRAP on real op:"shacl" workloads (witnessed this session; receipt
  # finding (c)), so this court executes on the real WASI implementation
  # while keeping the W637 artifact identity digest-pinned.
  defp start_instance do
    {:ok, bytes} = File.read(@artifact_path)
    pin = File.read!(@pin_file) |> String.trim() |> String.split() |> List.first()
    :ok = Xaas.Semantics.GraphlawWasm.verify_digest(bytes, pin)
    assert pin == "fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38"

    {:ok, _engine} = Wasmex.Engine.new(%Wasmex.EngineConfig{})
    {:ok, store} = Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{})
    {:ok, module} = Wasmex.Module.compile(store, bytes)
    {:ok, pid} = Wasmex.start_link(%{store: store, module: module, imports: %{}})

    exports = Wasmex.Module.exports(module)
    required = ["memory", "gl_alloc", "gl_free", "gl_call"]
    missing = Enum.reject(required, &Map.has_key?(exports, &1))
    assert missing == [], "artifact lacks required exports: #{inspect(missing)}"

    %{pid: pid, artifact_digest: Xaas.Semantics.GraphlawWasm.digest(bytes)}
  end

  defp guest_foci(ttl) do
    guest(ttl)["results"]
    |> Enum.map(& &1["focus"])
    |> Enum.map(fn focus ->
      # The guest serializes focus nodes as N-Triples IRIs: <...>.
      case focus do
        "<" <> rest -> String.trim_trailing(rest, ">")
        plain -> plain
      end
    end)
    |> MapSet.new()
  end

  # Corpus surgery: fresh root per case (base re-read, never mutated);
  # the fragment must occur exactly once.
  defp drop_exact(text, fragment) do
    case String.split(text, fragment) do
      [pre, post] -> pre <> post
      _ -> flunk("corpus surgery failed: fragment appears more than once")
    end
  end
end
