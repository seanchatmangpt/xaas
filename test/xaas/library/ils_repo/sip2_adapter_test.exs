defmodule Xaas.Library.ILSRepo.SIP2AdapterTest do
  @moduledoc """
  Real TCP round-trip tests for `Xaas.Library.ILSRepo.SIP2Adapter` against
  `Xaas.Test.SIP2TestServer`, a real local `:gen_tcp` server -- not a mock
  of `ILSRepo` or of the socket. No `Mox`/`:meck`/`patch` anywhere in this
  file.
  """
  use ExUnit.Case, async: true

  alias Xaas.Library.ILSRepo.SIP2Adapter
  alias Xaas.Test.SIP2TestServer

  setup do
    {:ok, port} = SIP2TestServer.start()

    Application.put_env(:xaas, SIP2Adapter,
      host: "127.0.0.1",
      port: port,
      institution_id: "TESTLIB",
      terminal_password: "",
      timeout: 2_000
    )

    on_exit(fn -> Application.delete_env(:xaas, SIP2Adapter) end)

    :ok
  end

  describe "wire-format encoding" do
    test "encode_patron_status_request/2 produces real 23 fixed+variable SIP2 fields" do
      opts = [institution_id: "TESTLIB", terminal_password: "pw"]
      message = SIP2Adapter.encode_patron_status_request("MAYA-R-001", opts)

      assert String.starts_with?(message, "23")
      assert String.ends_with?(message, "\r")

      <<"23", language::binary-size(3), _tx_date::binary-size(18), variable::binary>> =
        String.trim_trailing(message, "\r")

      assert language == "001"

      fields = SIP2Adapter.parse_variable_fields(variable)
      assert fields["AO"] == "TESTLIB"
      assert fields["AA"] == "MAYA-R-001"
      assert fields["AC"] == "pw"
    end

    test "encode_item_information_request/2 produces real 17 fixed+variable SIP2 fields" do
      opts = [institution_id: "TESTLIB", terminal_password: ""]
      message = SIP2Adapter.encode_item_information_request("BK-1001", opts)

      assert String.starts_with?(message, "17")

      <<"17", _tx_date::binary-size(18), variable::binary>> =
        String.trim_trailing(message, "\r")

      fields = SIP2Adapter.parse_variable_fields(variable)
      assert fields["AO"] == "TESTLIB"
      assert fields["AB"] == "BK-1001"
    end

    test "parse_variable_fields/1 splits real pipe-terminated SIP2 subfields" do
      assert SIP2Adapter.parse_variable_fields("AOTESTLIB|AAMAYA-R-001|AEMaya R.|") == %{
               "AO" => "TESTLIB",
               "AA" => "MAYA-R-001",
               "AE" => "Maya R."
             }
    end
  end

  describe "real TCP round trip against the local SIP2 test server" do
    test "patron_status/1 returns real decoded state for the known patron" do
      assert {:ok, patron} = SIP2Adapter.patron_status("MAYA-R-001")
      assert patron.patron_id == "MAYA-R-001"
      assert patron.name == "Maya R."
      assert patron.valid == true
      assert patron.institution_id == "TESTLIB"
    end

    test "patron_status/1 returns a real error for an unknown patron" do
      assert {:error, :patron_not_found} = SIP2Adapter.patron_status("NOBODY-999")
    end

    test "item_information/1 returns real decoded state for the known item" do
      assert {:ok, item} = SIP2Adapter.item_information("BK-1001")
      assert item.item_id == "BK-1001"
      assert item.title == "The Salt Road Cipher"
      assert item.circulation_status == "03"
      assert item.location == "Main Branch"
      assert item.call_number == "813.6 OKO"
    end

    test "item_information/1 returns a real error for an unknown item" do
      assert {:error, :item_not_found} = SIP2Adapter.item_information("BK-9999")
    end
  end

  describe "unsupported catalog/circulation callbacks" do
    test "get_catalog/1 is not supported by SIP2" do
      assert {:error, :not_supported_by_sip2} = SIP2Adapter.get_catalog("any-school")
    end

    test "get_circulation_history/1 is not supported by SIP2" do
      assert {:error, :not_supported_by_sip2} = SIP2Adapter.get_circulation_history("any-student")
    end
  end
end
