defmodule Xaas.Zoe.PrivateMeetingInferenceTest do
  use ExUnit.Case, async: true

  alias Xaas.Zoe.PrivateMeetingInference

  @digest String.duplicate("a", 64)
  @requirements [
    %{"id" => "roles_and_ownership", "prompt" => "Who owns each required responsibility?"},
    %{"id" => "systems_and_access", "prompt" => "Which access gaps remain?"}
  ]

  test "repository admits local directories and refuses external model repositories" do
    dir = Path.join(System.tmp_dir!(), "zoe-private-model-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    assert {:ok, {:local, ^dir}} = PrivateMeetingInference.repository(dir)

    assert {:error, %{code: :external_model_repository_refused}} =
             PrivateMeetingInference.repository("https://huggingface.co/model")

    symlink = dir <> "-symlink"
    File.ln_s!(dir, symlink)
    on_exit(fn -> File.rm_rf!(symlink) end)

    assert {:error, %{code: :model_symlink_refused}} =
             PrivateMeetingInference.repository(symlink)
  end

  test "decoder produces a private candidate with no DO authority and no raw generated notes" do
    generated =
      Jason.encode!(%{
        "observations" => [
          %{
            "requirement_id" => "roles_and_ownership",
            "status" => "SATISFIED",
            "note" => "drop me"
          },
          %{
            "requirement_id" => "systems_and_access",
            "status" => "PARTIAL",
            "note" => "drop me too"
          }
        ],
        "novel_observations" => [%{"kind" => "NEW_REQUIRED_CAPABILITY", "note" => "discard"}],
        "process_metrics" => %{"unnecessary_minutes" => 4}
      })

    transcript = "synthetic staff-only transcript"

    assert {:ok, candidate} =
             PrivateMeetingInference.decode_output(
               generated,
               Enum.map(@requirements, & &1["id"]),
               @digest,
               transcript
             )

    assert candidate["authority"] == "OBSERVE_CONSTRUCT_ONLY"
    refute candidate["do_authority"]
    assert candidate["inference"]["mode"] == "PRIVATE_LOCAL"
    refute candidate["inference"]["external_model_provider"]
    assert candidate["inference"]["model_identity"] == "sha256:#{@digest}"
    assert candidate["process_metrics"]["unnecessary_minutes"] == 4

    assert Enum.all?(candidate["observations"], fn observation ->
             Map.keys(observation) |> Enum.sort() ==
               ["evidence_ref", "requirement_id", "status"]
           end)

    assert [%{"kind" => "NEW_REQUIRED_CAPABILITY"} = novel] = candidate["novel_observations"]
    assert Map.has_key?(novel, "id")
    assert Map.has_key?(novel, "evidence_ref")
    refute inspect(candidate) =~ "drop me"
  end

  test "decoder refuses unknown requirement ids and unsupported statuses" do
    unknown =
      Jason.encode!(%{
        "observations" => [%{"requirement_id" => "invented", "status" => "SATISFIED"}]
      })

    assert {:error, %{code: :unknown_requirement_id}} =
             PrivateMeetingInference.decode_output(unknown, ["roles_and_ownership"], @digest, "t")

    invalid =
      Jason.encode!(%{
        "observations" => [%{"requirement_id" => "roles_and_ownership", "status" => "ADMITTED"}]
      })

    assert {:error, %{code: :invalid_requirement_status}} =
             PrivateMeetingInference.decode_output(invalid, ["roles_and_ownership"], @digest, "t")
  end

  test "decoder refuses malformed model identity and malformed JSON" do
    assert {:error, %{code: :invalid_model_digest}} =
             PrivateMeetingInference.decode_output("{}", ["x"], "not-a-digest", "t")

    assert {:error, %{code: :model_output_not_json}} =
             PrivateMeetingInference.decode_output("not json", ["x"], @digest, "t")
  end

  test "decoder refuses arbitrary novel text instead of propagating model-produced PII" do
    generated =
      Jason.encode!(%{
        "observations" => [
          %{"requirement_id" => "roles_and_ownership", "status" => "SATISFIED"}
        ],
        "novel_observations" => [%{"kind" => "A named student needs a ride"}]
      })

    assert {:error, %{code: :invalid_novel_observation}} =
             PrivateMeetingInference.decode_output(
               generated,
               ["roles_and_ownership"],
               @digest,
               "t"
             )
  end

  test "model manifest recomputes local artifact digests and fails closed on drift" do
    dir =
      Path.join(
        System.tmp_dir!(),
        "zoe-private-model-manifest-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    artifact = Path.join(dir, "config.json")
    File.write!(artifact, "model-config")
    digest = :crypto.hash(:sha256, "model-config") |> Base.encode16(case: :lower)
    manifest = "#{digest}  config.json\n"
    File.write!(Path.join(dir, ".model-manifest.sha256"), manifest)

    expected_manifest_digest =
      :crypto.hash(:sha256, manifest) |> Base.encode16(case: :lower)

    assert {:ok, ^expected_manifest_digest} = PrivateMeetingInference.verify_model_manifest(dir)

    File.write!(Path.join(dir, "unbound.bin"), "not-in-manifest")

    assert {:error, %{code: :model_manifest_incomplete}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    File.rm!(Path.join(dir, "unbound.bin"))
    File.write!(artifact, "tampered")

    assert {:error, %{code: :model_artifact_digest_mismatch}} =
             PrivateMeetingInference.verify_model_manifest(dir)
  end
end
