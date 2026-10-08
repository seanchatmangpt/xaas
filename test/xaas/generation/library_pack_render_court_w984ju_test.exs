defmodule Xaas.Generation.LibraryPackRenderCourtW984JuTest do
  @moduledoc """
  W984ju court: the priv/packs/xaas_library_pack/templates/manufacture.ex.eex template
  renders to parseable Elixir under representative assigns.

  Chicago-school: real EEx evaluation over the real template file, real
  Code.string_to_quoted! parse of the rendered output. No mocks — every
  collaborator (filesystem, EEx, Code parser) is a real in-process collaborator.
  Mutation rationale (C05): if the template's module name or EEx interpolation
  markers were deleted, the parse assertion and structural-marker assertions
  below would fail, so the court is non-vacuous.
  """

  use ExUnit.Case, async: true

  @template_path Path.join(:code.priv_dir(:xaas), "packs/xaas_library_pack/templates/manufacture.ex.eex")

  @sample_targets [
    %{
      "order" => 1,
      "mixTask" => "ash_codegen.gen_resource",
      "targetModule" => "Xaas.Library.Book",
      "domainModule" => "Xaas.Library",
      "resourceModule" => "Xaas.Library.Book",
      "mixArgs" => "--domain Xaas.Library"
    },
    %{
      "order" => 2,
      "mixTask" => "ash_codegen.gen_resource",
      "targetModule" => "Xaas.Library.Checkout",
      "domainModule" => "Xaas.Library",
      "resourceModule" => "Xaas.Library.Checkout",
      "mixArgs" => "--domain Xaas.Library"
    }
  ]

  defp strip_front_matter(template) do
    case template do
      << "---\n", rest::binary >> ->
        case :binary.split(rest, "\n---\n") do
          [_fm, body] -> body
          _ -> template
        end

      _ ->
        template
    end
  end

  defp render(template, assigns) do
    template
    |> strip_front_matter()
    |> EEx.eval_string(assigns)
  end

  test "template file exists" do
    assert File.exists?(@template_path)
  end

  test "rendered output parses as Elixir" do
    rendered = render(File.read!(@template_path), base_phase_targets: @sample_targets, core_phase_targets: @sample_targets)
    Code.string_to_quoted!(rendered)
  end

  test "rendered output carries structural markers" do
    rendered = render(File.read!(@template_path), base_phase_targets: @sample_targets, core_phase_targets: @sample_targets)

    assert rendered =~ "defmodule Mix.Tasks.Xaas.Library.Manufacture do"
    assert rendered =~ "def base_targets, do: @base_targets"
    assert rendered =~ "def core_targets, do: @core_targets"
    assert rendered =~ "defp run_base_phase("
    assert rendered =~ "defp run_core_phase("
    # EEx interpolation actually landed (non-vacuity on the loop assigns)
    assert rendered =~ ~S(mix_task: "ash_codegen.gen_resource")
    assert rendered =~ ~S(target_module: "Xaas.Library.Book")
  end

  test "sorted target rows appear in order" do
    unsorted = Enum.shuffle(@sample_targets)
    rendered = render(File.read!(@template_path), base_phase_targets: unsorted, core_phase_targets: unsorted)

    book_pos = String.split(rendered, ~S(target_module: "Xaas.Library.Book")) |> hd() |> String.length()
    checkout_pos = String.split(rendered, ~S(target_module: "Xaas.Library.Checkout")) |> hd() |> String.length()

    assert book_pos < checkout_pos
  end
  @tag :w984ju_head_baseline
  test "HEAD baseline of the template also parses" do
    {head_template, 0} = System.cmd("git", ["show", "HEAD:priv/packs/xaas_library_pack/templates/manufacture.ex.eex"])

    assigns = [base_phase_targets: @sample_targets, core_phase_targets: @sample_targets]
    head_rendered = render(head_template, assigns)
    Code.string_to_quoted!(head_rendered)
  end
end
