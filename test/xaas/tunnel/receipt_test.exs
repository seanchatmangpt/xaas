defmodule Xaas.Tunnel.ReceiptTest do
  use ExUnit.Case, async: true

  alias Xaas.Tunnel.Receipt

  # Byte-identical copies of chatgpt-cloud-elixir
  # xaas-runtime/elixir/test/fixtures/receipt_golden.{json,sha256} (origin/main 08722697).
  @fixture Path.expand("../../fixtures/tunnel/receipt_golden.json", __DIR__)
  @expected Path.expand("../../fixtures/tunnel/receipt_golden.sha256", __DIR__)
  @golden "7d98905d89388c098e14c63226356f8b4cab61d6422c1017ea77e78162ef2870"

  test "golden receipt digest equals the committed sha256 (cloud client + Python parity)" do
    value = @fixture |> File.read!() |> Jason.decode!()
    expected = @expected |> File.read!() |> String.trim()

    assert expected == @golden
    assert Receipt.digest(value) == expected
  end

  test "golden fixture file bytes equal the cloud client's copy" do
    assert :crypto.hash(:sha256, File.read!(@fixture)) |> Base.encode16(case: :lower) ==
             "2bfc8edc95678540a51a5c664456bf925f2cceebad60f3ab52ebae1cca7f770f"
  end

  test "canonical form: sorted keys, compact separators, raw UTF-8, Python escapes" do
    ls = <<0x2028::utf8>>

    assert Receipt.canonical(%{"b" => 1, "a" => [true, nil, "é/" <> ls]}) ==
             ~s({"a":[true,null,"é/) <> ls <> ~s("],"b":1})

    assert Receipt.canonical("\"\\\b\f\n\r\t\u0001\u001f\u007f") ==
             ~S("\"\\\b\f\n\r\t\u0001\u001f) <> "\u007f\""

    assert Receipt.canonical(%{"Z" => 1, "z" => 2, "é" => 3, "10" => 4, "2" => 5}) ==
             ~s({"10":4,"2":5,"Z":1,"z":2,"é":3})
  end

  test "floats, invalid UTF-8, structs and duplicate keys are refused" do
    assert_raise ArgumentError, fn -> Receipt.canonical(%{"x" => 1.0}) end
    assert_raise ArgumentError, fn -> Receipt.canonical(<<0xFF>>) end
    assert_raise ArgumentError, fn -> Receipt.canonical(%{:a => 1, "a" => 2}) end
    assert_raise ArgumentError, fn -> Receipt.canonical(%{"t" => DateTime.utc_now()}) end
  end

  test "a one-field mutation of the golden changes the digest (anti-vacuity)" do
    value = @fixture |> File.read!() |> Jason.decode!()
    refute Receipt.digest(put_in(value, ["identity", "idempotency_key"], "golden-002")) == @golden
  end

  test "verify_replay accepts the sealed digest and refuses a tampered one" do
    sealed = %{"epoch_id" => "e", "outcome" => "alive"}
    assert Receipt.verify_replay(sealed, Receipt.digest(sealed)) == :ok

    assert Receipt.verify_replay(sealed, Receipt.digest(%{sealed | "outcome" => "x"})) ==
             {:refused, :replay_digest_mismatch}

    assert Receipt.verify_replay("not a map", "d") == {:refused, :replay_digest_mismatch}
  end

  test "json_safe output survives a JSON round trip with the same digest" do
    value =
      Receipt.json_safe(%{
        at: ~U[2026-09-25 09:00:00.123456Z],
        ratio: 0.5,
        tag: :alive,
        pair: {1, "b"},
        nested: %{list: [nil, true, 9_007_199_254_740_991]}
      })

    assert value["at"] == "2026-09-25T09:00:00.123456Z"
    assert value["ratio"] == "0.5"

    assert Receipt.digest(value) ==
             value |> Jason.encode!() |> Jason.decode!() |> Receipt.digest()
  end

  test "from_ultracode projects a sealed Ultracode receipt with BRCE standing" do
    receipt = %Xaas.Ultracode.Receipt{
      id: "11111111-1111-4111-8111-111111111111",
      epoch_id: "22222222-2222-4222-8222-222222222222",
      subject: "fabric:acme-dev:k1",
      outcome: :partial_alive,
      evidence: %{"head_verified" => false, "score" => 1.5},
      sealed_at: ~U[2026-09-25 09:00:00.000000Z]
    }

    wire = Receipt.from_ultracode(receipt)

    assert wire["schema"] == "xaas.fabric-sealed-receipt/1"
    assert wire["authority"] == "CONSTRUCT"
    assert wire["standing"] == "PARTIAL_ALIVE"
    assert wire["outcome"] == "partial_alive"
    assert wire["evidence"] == %{"head_verified" => false, "score" => "1.5"}
    assert is_binary(Receipt.canonical(wire))
  end

  test "tunnel_receipt carries the five BRCE fields and a self digest" do
    r =
      Receipt.tunnel_receipt("submit", %{
        identity: %{run_id: "r", epoch_id: "e"},
        consequence: %{replay: true},
        replay: "mix xaas_runtime.fabric --idempotency-key k",
        standing: "ALIVE"
      })

    for f <- ~w(identity authority consequence replay standing), do: assert(Map.has_key?(r, f))
    assert r["authority"] == "CONSTRUCT"
    assert r["receipt_sha256"] == r |> Map.delete("receipt_sha256") |> Receipt.digest()
  end
end
