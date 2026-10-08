defmodule Xaas.Conference.SpeakerCourtW984isTest do
  @moduledoc """
  W984is — dedicated state court for `Xaas.Conference.Speaker`
  (lib/xaas/conference/speaker.ex).

  W984gg's census typed Speaker INDIRECTLY-COVERED: existing tests only build
  Speaker rows as helpers for Session/Track/Registration courts — no test
  witnesses Speaker's own state-bearing branches:

  - `unique_slug` identity with `pre_check_with: Ash.DataLayer.Ets`: a second
    :create with the same slug must be refused before any row lands (mutation:
    drop the identity block and the duplicate create would succeed, killing
    this test's error assertion).
  - `allow_nil?(false)` on :name and :slug: nil inputs must be refused as
    required-attribute failures (mutation: flipping either allow_nil? to true
    lets the nil create succeed, killing the refute).
  - `keynote?` default false with the attribute accepted on :create: an
    omitted keynote? must read back false; an explicit true must persist
    (mutation: dropping the default or the accept of :keynote? flips the
    observed state).
  - default `:destroy` action: a destroyed speaker must vanish from reads
    (mutation: removing :destroy from defaults kills the post-destroy read).

  Chicago-style: real Ash actions over the resource's real private ETS table,
  zero mocks; sandbox-free because the resource is `ets private?(true)`.
  """

  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Conference.Speaker

  setup do
    wipe()
    :ok
  end

  defp wipe do
    Speaker
    |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
  end

  defp uniq, do: System.unique_integer([:positive])

  defp create_speaker!(attrs) do
    Ash.create!(
      Ash.Changeset.for_create(Speaker, :create, attrs),
      authorize?: false
    )
  end

  defp create_speaker(attrs) do
    Ash.create(
      Ash.Changeset.for_create(Speaker, :create, attrs),
      authorize?: false
    )
  end

  test "unique_slug identity: duplicate slug create is refused and no second row lands" do
    slug = "speaker-w984is-dup-#{uniq()}"
    create_speaker!(%{name: "First", slug: slug})

    {:error, _cs} = create_speaker(%{name: "Second", slug: slug})

    speakers = Ash.read!(Speaker, authorize?: false)
    assert length(speakers) == 1
    assert hd(speakers).slug == slug
  end

  test "distinct slugs coexist under the same identity" do
    a = create_speaker!(%{name: "A", slug: "speaker-w984is-a-#{uniq()}"})
    b = create_speaker!(%{name: "B", slug: "speaker-w984is-b-#{uniq()}"})
    refute a.id == b.id

    assert length(Ash.read!(Speaker, authorize?: false)) == 2
  end

  test "name and slug are required: nil inputs are refused" do
    {:error, _} = create_speaker(%{slug: "speaker-w984is-noname-#{uniq()}"})
    {:error, _} = create_speaker(%{name: "No Slug"})

    assert Ash.read!(Speaker, authorize?: false) == []
  end

  test "keynote? defaults to false and accepts explicit true on create" do
    plain = create_speaker!(%{name: "Plain", slug: "speaker-w984is-plain-#{uniq()}"})
    assert plain.keynote? == false

    keynote = create_speaker!(%{name: "Keynote", slug: "speaker-w984is-key-#{uniq()}", keynote?: true})
    assert keynote.keynote? == true

    reloaded = Ash.get!(Speaker, keynote.id, authorize?: false)
    assert reloaded.keynote? == true
  end

  test "destroy removes the speaker from subsequent reads" do
    speaker = create_speaker!(%{name: "Doomed", slug: "speaker-w984is-doomed-#{uniq()}"})

    Ash.destroy!(speaker, authorize?: false)

    assert Ash.read!(Speaker, authorize?: false) == []
    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             Ash.get(Speaker, speaker.id, authorize?: false)
  end
end
