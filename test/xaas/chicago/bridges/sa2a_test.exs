defmodule Xaas.Chicago.Bridges.Sa2aTest do
  @moduledoc """
  The UNKNOWN provenance law for the SA2A evidence reader:

    * no receipt file  -> standing UNKNOWN, provenance :receipt_not_found;
    * receipt whose subject SHA differs from the pin -> UNKNOWN with
      :receipt_subject_mismatch naming BOTH SHAs — never relabelled;
    * receipt matching the pin -> still UNKNOWN (a read is not an execution);
      the receipt's own standing is reported verbatim, never adopted;
    * unreadable receipt content -> UNKNOWN, provenance :receipt_unreadable.

  The reader never synthesizes evidence refs; every evidence_ref names the
  actual file that was read.
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges.Sa2a

  @pin String.duplicate("a", 40)
  @other_sha String.duplicate("b", 40)

  describe "no receipt" do
    test "missing file is UNKNOWN with :receipt_not_found provenance" do
      {:unknown, envelope} =
        Sa2a.court_receipt(path: "/tmp/l7-definitely-missing-court-receipt.json", pin: @pin)

      assert envelope.standing == "UNKNOWN"
      assert envelope.state == :unknown
      assert envelope.authority_ceiling == :none
      assert envelope.evidence_ref == nil
      assert envelope.provenance.reason == :receipt_not_found
      assert envelope.provenance.pin == @pin
    end
  end

  describe "stale receipt" do
    setup do
      %{path: receipt_file(@other_sha, "ALIVE")}
    end

    test "subject mismatch is UNKNOWN and names both SHAs", %{path: path} do
      {:unknown, envelope} = Sa2a.court_receipt(path: path, pin: @pin)

      assert envelope.standing == "UNKNOWN"
      assert envelope.provenance.reason == :receipt_subject_mismatch
      assert envelope.provenance.receipt_subject_sha == @other_sha
      assert envelope.provenance.pin == @pin
      # never relabel: the receipt claims ALIVE, the reader still says UNKNOWN
      refute envelope.standing == "ALIVE"
    end

    test "evidence_ref names the actual file that was read", %{path: path} do
      {:unknown, envelope} = Sa2a.court_receipt(path: path, pin: @pin)
      assert envelope.evidence_ref == "sa2a.court_receipt:" <> path
    end
  end

  describe "matching receipt" do
    test "match reports the receipt verbatim but keeps UNKNOWN standing" do
      path = receipt_file(@pin, "ALIVE")

      {:unknown, envelope} = Sa2a.court_receipt(path: path, pin: @pin)

      assert envelope.standing == "UNKNOWN"
      assert envelope.provenance.reason == :receipt_subject_match
      assert envelope.provenance.receipt_standing == "ALIVE"
      assert envelope.provenance.pin == @pin
    end
  end

  test "unreadable JSON is UNKNOWN with :receipt_unreadable provenance" do
    path = Path.join(System.tmp_dir!(), "l7-broken-receipt-#{System.unique_integer()}.json")
    File.write!(path, "{not json")

    on_exit(fn -> File.rm(path) end)

    {:unknown, envelope} = Sa2a.court_receipt(path: path, pin: @pin)

    assert envelope.standing == "UNKNOWN"
    assert envelope.provenance.reason == :receipt_unreadable
  end

  test "nil pin (unresolvable HEAD) with matching-looking receipt still mismatches" do
    path = receipt_file(@pin, "ALIVE")
    {:unknown, envelope} = Sa2a.court_receipt(path: path, pin: nil)

    assert envelope.provenance.reason == :receipt_subject_mismatch
    assert envelope.provenance.pin == nil
    assert envelope.standing == "UNKNOWN"
  end

  defp receipt_file(subject_sha, standing) do
    path = Path.join(System.tmp_dir!(), "l7-court-receipt-#{System.unique_integer()}.json")

    File.write!(
      path,
      Jason.encode!(%{
        "subject_sha" => subject_sha,
        "standing" => standing,
        "receipt_hash" => String.duplicate("c", 64)
      })
    )

    on_exit(fn -> File.rm(path) end)
    path
  end
end
