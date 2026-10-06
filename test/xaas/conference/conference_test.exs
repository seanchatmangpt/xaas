defmodule Xaas.ConferenceTest do
  @moduledoc """
  Chicago-style courts over the AGNTCon+MCPCon 2026 conference surface: real
  `Ash.DataLayer.Ets` storage, real `Ash.Changeset.for_create` + `Ash.create!`
  seeding, real `Ash.read!` queries. No mocks.

  Seed: 1 event, 11 tracks, 6 speakers, 20 sessions, 4 diamond sponsors,
  20 attendees. Courts: everything queryable at the seeded counts, sessions
  searchable by track, sponsors countable by tier.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Conference.{Attendee, Event, Session, Speaker, Sponsor, Track}

  @track_names [
    "Agents in Production",
    "Agent Interoperability (A2A)",
    "MCP Deep Dives",
    "Agentic Workflows",
    "Evaluations & Courts",
    "Security & Sandboxing",
    "Multi-Agent Orchestration",
    "LLM Ops",
    "Semantic Interfaces",
    "Developer Experience",
    "Lightning Talks"
  ]

  @speaker_names [
    "Jose Valim",
    "Chris McCord",
    "Sean Chatman",
    "Zach Daniel",
    "Marlus Saraiva",
    "Ben Wilson"
  ]

  setup do
    wipe()
    seed()
    :ok
  end

  defp wipe do
    for res <- [Session, Track, Speaker, Sponsor, Attendee, Event] do
      res
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    end
  end

  defp create!(resource, attrs) do
    resource
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  defp seed do
    event =
      create!(Event, %{
        name: "AGNTCon+MCPCon 2026",
        slug: "agntcon-mcpcon-2026",
        location: "San Francisco, CA",
        starts_at: ~U[2026-10-14 16:00:00Z],
        ends_at: ~U[2026-10-16 23:00:00Z]
      })

    tracks =
      Enum.map(@track_names, fn name ->
        create!(Track, %{
          name: name,
          slug: slug(name),
          description: "AGNTCon+MCPCon 2026 track: #{name}",
          event_id: event.id
        })
      end)

    speakers =
      Enum.map(@speaker_names, fn name ->
        create!(Speaker, %{
          name: name,
          slug: slug(name),
          bio: "Speaker bio for #{name}",
          keynote?: name in ["Jose Valim", "Sean Chatman"]
        })
      end)

    # 20 sessions round-robin across 11 tracks and 6 speakers.
    sessions =
      for i <- 1..20 do
        title = "Session #{i}: Agentic Systems in Practice"
        track = Enum.at(tracks, rem(i - 1, length(tracks)))
        speaker = Enum.at(speakers, rem(i - 1, length(speakers)))
        hour = i + 6

        create!(Session, %{
          title: title,
          slug: "session-#{i}",
          description: "Deep dive #{i} on agentic systems.",
          track_id: track.id,
          speaker_id: speaker.id,
          starts_at: DateTime.add(~U[2026-10-14 00:00:00Z], hour, :hour),
          ends_at: DateTime.add(~U[2026-10-14 00:00:00Z], hour + 1, :hour)
        })
      end

    # 4 diamond sponsors plus one of every other tier.
    diamond = ["Anthropic", "OpenAI", "Google DeepMind", "Microsoft"]

    for {name, tier} <-
          Enum.zip(diamond ++ ["Vercel", "Fly.io", "Tailwind Labs"], [:diamond, :diamond, :diamond, :diamond, :gold, :silver, :bronze]) do
      create!(Sponsor, %{
        name: name,
        slug: slug(name),
        tier: tier,
        url: "https://example.com/sponsors/#{slug(name)}"
      })
    end

    attendees =
      for i <- 1..20 do
        create!(Attendee, %{
          name: "Attendee #{i}",
          email: "attendee#{i}@example.com",
          affiliation: "Org #{rem(i - 1, 5) + 1}"
        })
      end

    %{
      event: event,
      tracks: tracks,
      speakers: speakers,
      sessions: sessions,
      attendees: attendees
    }
  end

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  @tag :conference_seed
  test "seed: every resource is queryable at the seeded counts" do
    assert [%{slug: "agntcon-mcpcon-2026"}] = Ash.read!(Event, authorize?: false)

    tracks = Ash.read!(Track, authorize?: false)
    assert length(tracks) == 11

    speakers = Ash.read!(Speaker, authorize?: false)
    assert length(speakers) == 6
    assert Enum.count(speakers, & &1.keynote?) == 2

    sessions = Ash.read!(Session, authorize?: false)
    assert length(sessions) == 20

    sponsors = Ash.read!(Sponsor, authorize?: false)
    assert length(sponsors) == 7

    attendees = Ash.read!(Attendee, authorize?: false)
    assert length(attendees) == 20
  end

  @tag :conference_seed
  test "search by track: sessions resolve through their track name" do
    target = Ash.read!(Track, authorize?: false) |> Enum.find(&(&1.slug == "mcp-deep-dives"))
    assert target

    found =
      Session
      |> Ash.Query.filter(track_id == ^target.id)
      |> Ash.read!(authorize?: false)

    assert length(found) == 2

    # Every hit belongs to the target track, and the track belongs to the event.
    assert Enum.all?(found, &(&1.track_id == target.id))

    event = Ash.get!(Event, target.event_id, authorize?: false)
    assert event.slug == "agntcon-mcpcon-2026"
  end

  @tag :conference_seed
  test "count by tier: exactly 4 diamond sponsors, one per other tier" do
    diamond =
      Sponsor
      |> Ash.Query.filter(tier == :diamond)
      |> Ash.read!(authorize?: false)

    assert length(diamond) == 4
    assert Enum.map(diamond, & &1.name) |> Enum.sort() == [
             "Anthropic",
             "Google DeepMind",
             "Microsoft",
             "OpenAI"
           ]

    for tier <- [:gold, :silver, :bronze] do
      count =
        Sponsor
        |> Ash.Query.filter(tier == ^tier)
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 1
    end
  end
end
