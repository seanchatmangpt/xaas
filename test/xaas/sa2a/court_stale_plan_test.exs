defmodule Xaas.Sa2a.CourtStalePlanTest do
  @moduledoc """
  Qualification of the stale-plan preimage fence as a `Xaas.Sa2a.Court.admit/2`
  pre-check (XA-3007).

  The fence steps run BEFORE any port call, so these tests run against the real
  court with an explicit policy and no `Xaas.Sa2a.Bridge` port, no database and
  no mocks: every assertion lands on a typed refusal (or the refusal the chain
  produces right after the fence passes), proving both the fence's decisions and
  that plans without preimage fields take the unchanged path.
  """

  use ExUnit.Case, async: true

  alias Xaas.Planning.StalePlanGate
  alias Xaas.Sa2a.Court

  @policy %{
    classes: [
      %{
        id: "workorder-resolution",
        match: {:prefix, "workorder:"},
        bind_work_order: true,
        max_query_bytes: 512
      }
    ],
    admitted_standings: ["KNOWN"],
    min_llm_avoidance_ratio: 1.0,
    max_compiled_rules: 64
  }

  describe "admit/2 preimage fence" do
    test "a plan without preimage fields takes the unchanged path" do
      # No fence fields: the court must refuse with the NEXT step's code
      # (:admit_receipt_missing), never with :stale_plan_refusal.
      assert {:error, {:refused, :admit_receipt_missing, _}} = Court.admit(request(), @policy)

      # A plan value that is not a map also skips the fence and fails at the same
      # step as before the fence existed.
      no_plan = Map.put(request(), "plan", 42)

      assert {:error, {:refused, :admit_receipt_missing, _}} = Court.admit(no_plan, @policy)
    end

    test "a plan whose observed preimage digest differs is refused before the receipt checks" do
      preimage = %{"candidates" => [%{"item_id" => "SJ-1"}]}
      observed = StalePlanGate.fingerprint(preimage)
      drifted = StalePlanGate.fingerprint(%{"candidates" => [%{"item_id" => "SJ-1", "v" => 2}]})

      stale =
        request()
        |> put_in(["plan", "preimage"], preimage)
        |> put_in(["plan", "admitted_preimage_hash"], drifted)

      # The fence fires even though the request also has no admit receipt:
      # it is a pre-check that runs before the receipt steps.
      assert {:error,
              {:refused, :stale_plan_refusal,
               %{admitted_preimage_hash: ^drifted, observed_preimage_hash: ^observed}}} =
               Court.admit(stale, @policy)
    end

    test "a present-but-unusable fence refuses closed" do
      preimage = %{"candidates" => [%{"item_id" => "SJ-1"}]}

      # digest without preimage content: the observed side is missing -> malformed
      no_content =
        put_in(request(), ["plan", "admitted_preimage_hash"], String.duplicate("a", 64))

      assert {:error, {:refused, :stale_plan_refusal, :malformed_hash}} =
               Court.admit(no_content, @policy)

      # preimage content without a digest: the admitted side is missing -> malformed
      no_digest = put_in(request(), ["plan", "preimage"], preimage)

      assert {:error, {:refused, :stale_plan_refusal, :malformed_hash}} =
               Court.admit(no_digest, @policy)

      # malformed digest string alongside real content
      bad_digest =
        request()
        |> put_in(["plan", "preimage"], preimage)
        |> put_in(["plan", "admitted_preimage_hash"], "NOT-A-DIGEST")

      assert {:error, {:refused, :stale_plan_refusal, :malformed_hash}} =
               Court.admit(bad_digest, @policy)
    end

    test "a matching fence passes and the chain continues to the next admission step" do
      preimage = %{"candidates" => [%{"item_id" => "SJ-1"}], "plan_id" => "p1"}

      fresh =
        request()
        |> put_in(["plan", "preimage"], preimage)
        |> put_in(["plan", "admitted_preimage_hash"], StalePlanGate.fingerprint(preimage))

      # The fence is not the refusal: the court proceeds to the (port-free) admit
      # receipt step, which is the next refusal for this receipt-less request.
      assert {:error, {:refused, :admit_receipt_missing, _}} = Court.admit(fresh, @policy)
    end
  end

  defp request do
    id = "SJ-XA3007-#{System.unique_integer([:positive])}"

    %{
      "work_order_id" => id,
      "work_order_digest" =>
        "sha256:" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
      "query" => "workorder:#{id} resolve",
      "plan" => %{
        "plan_hash" => String.duplicate("a", 64),
        "candidates" => [%{"item_id" => id}]
      }
    }
  end

  describe "normalize/1 malformed-request refusal" do
    test "a JSON-unencodable value refuses with a structured detail map, not a raw message string" do
      # A pid cannot be Jason-encoded, so normalize/1 rescues Jason.EncodeError.
      assert {:error, {:refused, :malformed_request, detail}} =
               Court.normalize(%{"query" => self(), "work_order_id" => "wo-1"})

      assert is_map(detail)
      assert Map.keys(detail) |> Enum.sort() == [:exception_type, :original, :reason]
      assert detail.reason == :not_json_encodable
      # Jason raises Protocol.UndefinedError for unencodable terms (the
      # Jason.Encoder protocol is what's missing).
      assert detail.exception_type == "Protocol.UndefinedError"
      assert is_binary(detail.original) and detail.original != ""
    end

    test "a non-map request still refuses malformed_request (inspect detail path)" do
      assert {:error, {:refused, :malformed_request, detail}} = Court.normalize(:not_a_map)
      assert is_binary(detail)
    end
  end
end
