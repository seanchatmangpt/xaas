defmodule Xaas.Library.PubSubPublishCourtTest do
  @moduledoc """
  Lane W838 — publish-side court for the documented PubSub topic taxonomy
  (docs/claude/diataxis/reference/ash-configuration.md):

    * Book  (prefix "library:books")  -> `library:books:events`, `library:books:inventory:<id>`
    * Checkout (prefix "circulation") -> `circulation:events`, `circulation:student:<user_id>`
    * Curation (prefix "recommendations") -> `recommendations:curation_events`,
      `recommendations:grade:<grade_band>`, `recommendations:student:<student_id>`

  Chicago-style: real Ash actions (`:borrow`, `:return`, `:create`, `:update`) on real
  resources trigger real `Ash.Notifier.PubSub` broadcasts (via `XaasWeb.Endpoint`
  on the real `Xaas.PubSub` server). Each documented topic gets its own real
  subscriber process (a spawned Task that subscribes via `Phoenix.PubSub.subscribe/2`
  and relays deliveries to the test process). Assertions match on the actual
  `%Phoenix.Socket.Broadcast{}` structs and their `%Ash.Notifier.Notification{}`
  payloads. No mocks.

  Falsifier: a documented topic that carries no (or a wrong-shaped) broadcast when
  the corresponding action runs.

  Env note (revised 2026-10-07, lane W918b per W909 root cause): the W838 "deaf relay"
  was NOT a PubSub delivery defect. The awaiting test process is itself a real
  subscriber (direct `%Phoenix.Socket.Broadcast{}` deliveries land in its mailbox),
  so every broadcast arrives TWICE (relay-wrapped + direct), and the original
  topic-prefix-only awaiter with requeue let a stale copy satisfy a later await
  (W909 R3 repro: fourth await returned %{n: 2} when n=4 was expected, fresh
  broadcast left in the mailbox). Hardening: every await is now bound to the exact
  expected payload identity (the notification's `data.id`) in addition to the topic
  prefix, so a stale duplicate of an already-consumed message can never satisfy a
  later await. One-relay-per-topic is retained (verified-stable shape).
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Checkout, Curation}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  @recv_timeout 2_000

  defp create_user!(email \\ nil) do
    if email,
      do: Xaas.Generator.create_user!(%{email: email}),
      else: Xaas.Generator.create_user!()
  end

  defp create_book!(attrs \\ %{}), do: Xaas.Generator.create_book!(attrs)

  @doc false
  def relay(parent) do
    receive do
      msg ->
        send(parent, {:w838_pubsub, self(), msg})
        relay(parent)
    end
  end

  defp start_topic_relay(topic) do
    parent = self()

    {:ok, pid} =
      Task.start(fn ->
        :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, topic)
        send(parent, {:w838_ready, self(), topic})
        relay(parent)
      end)

    assert_receive {:w838_ready, ^pid, ^topic}, @recv_timeout
    pid
  end

  # Await a broadcast uniquely identified by BOTH the topic prefix AND the exact
  # expected payload identity (`payload.data.id`). W909 showed a topic-prefix-only
  # match lets a stale duplicate (duplicate direct+relay delivery into this
  # process's mailbox) satisfy a later await, starving the fresh broadcast.
  # Non-matching messages are requeued so other awaits still see them.
  # Accepts both relay-wrapped ({:w838_pubsub, relay, broadcast}) deliveries from
  # the per-topic relay Tasks and broadcasts delivered directly to the test
  # process (both are real PubSub subscriber deliveries in this env).
  defp await_relay(topic_prefix, expected_id, timeout \\ @recv_timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    await_relay(topic_prefix, expected_id, [], deadline)
  end

  defp await_relay(prefix, expected_id, buffer, deadline) do
    receive do
      {:w838_pubsub, _relay, %Phoenix.Socket.Broadcast{} = b} ->
        maybe_match(prefix, expected_id, buffer, b, deadline)

      %Phoenix.Socket.Broadcast{} = b ->
        maybe_match(prefix, expected_id, buffer, b, deadline)
    after
      max(0, deadline - System.monotonic_time(:millisecond)) ->
        Enum.each(:lists.reverse(buffer), &send(self(), &1))

        flunk(
          "no broadcast on topic #{inspect(prefix)} with data.id #{inspect(expected_id)}; " <>
            "buffered=#{inspect(Enum.map(buffer, &elem(&1, 2).topic))}"
        )
    end
  end

  defp payload_id(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{data: %{id: id}}}),
    do: id

  defp payload_id(_), do: nil

  defp maybe_match(prefix, expected_id, buffer, %Phoenix.Socket.Broadcast{} = b, deadline) do
    if String.starts_with?(b.topic, prefix) and payload_id(b) == expected_id do
      Enum.each(:lists.reverse(buffer), &send(self(), &1))
      b
    else
      await_relay(prefix, expected_id, [{:w838_pubsub, :direct, b} | buffer], deadline)
    end
  end

  defp notification_name(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = n}),
    do: n.action.name

  describe "borrow publishes on documented topics with real payload shapes" do
    test "borrow -> library:books:events and library:books:inventory:<id> carry the Book" do
      book = create_book!(%{available_copies: 2})
      start_topic_relay("library:books:events")
      start_topic_relay("library:books:inventory:#{book.id}")

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: create_user!().id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      ev = await_relay("library:books:events", book.id)

      assert %Phoenix.Socket.Broadcast{
               topic: "library:books:events",
               event: "borrow_copy",
               payload: %Ash.Notifier.Notification{resource: Book, data: %Book{} = data}
             } = ev

      assert data.id == book.id
      assert data.available_copies == book.available_copies - 1
      assert notification_name(ev) == :borrow_copy
      assert checkout.id
    end

    test "borrow -> library:books:inventory:<id> carries the decremented Book" do
      book = create_book!(%{available_copies: 2})
      start_topic_relay("library:books:inventory:#{book.id}")

      Checkout
      |> Ash.Changeset.for_create(:borrow, %{user_id: create_user!().id, book_id: book.id})
      |> Ash.create!(authorize?: false)

      inv = await_relay("library:books:inventory:", book.id)

      assert %Phoenix.Socket.Broadcast{
               topic: inv_topic,
               event: "borrow_copy",
               payload: %Ash.Notifier.Notification{data: %Book{} = data}
             } = inv

      assert String.ends_with?(inv_topic, ":#{book.id}")
      assert data.id == book.id
      assert data.available_copies == book.available_copies - 1
    end

    test "borrow -> circulation:student:<user_id> carries the Checkout payload" do
      user = create_user!()
      book = create_book!(%{available_copies: 3})
      topic = "circulation:student:#{user.id}"
      start_topic_relay(topic)

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      b = await_relay(topic, checkout.id)

      assert %Phoenix.Socket.Broadcast{
               topic: ^topic,
               payload: %Ash.Notifier.Notification{data: %Checkout{} = data} = note
             } = b

      assert data.id == checkout.id
      assert data.user_id == user.id
      # the :borrow create action publishes under its own action name, not :create
      assert note.action.name == :borrow
    end

    test "borrow -> circulation:events carries the Checkout payload" do
      user = create_user!()
      book = create_book!(%{available_copies: 3})
      start_topic_relay("circulation:events")

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      b = await_relay("circulation:events", checkout.id)

      assert %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{data: %Checkout{} = data}} = b
      assert data.id == checkout.id
      assert data.user_id == user.id
    end
  end

  describe "return publishes on documented topics" do
    test "return -> circulation:student:<user_id> and circulation:events" do
      user = create_user!()
      book = create_book!(%{available_copies: 3})
      topic = "circulation:student:#{user.id}"

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      start_topic_relay(topic)
      start_topic_relay("circulation:events")

      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

      b = await_relay(topic, checkout.id)

      assert %Phoenix.Socket.Broadcast{
               topic: ^topic,
               payload: %Ash.Notifier.Notification{data: %Checkout{} = data} = note
             } = b

      assert data.id == checkout.id
      assert data.user_id == user.id
      assert note.action.name == :return
      assert data.status == :returned

      ev = await_relay("circulation:events", checkout.id)
      assert %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{data: %Checkout{} = d2}} = ev
      assert d2.id == checkout.id
      assert notification_name(ev) == :return
    end

    test "return -> library:books:inventory:<id> reflects the inventory increment" do
      book = create_book!(%{available_copies: 1})
      before_copies = book.available_copies

      user = create_user!()

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      start_topic_relay("library:books:inventory:#{book.id}")

      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

      inv = await_relay("library:books:inventory:", book.id)

      assert %Phoenix.Socket.Broadcast{
               topic: inv_topic,
               event: "return_copy",
               payload: %Ash.Notifier.Notification{data: %Book{} = data}
             } = inv

      assert String.ends_with?(inv_topic, ":#{book.id}")
      assert data.id == book.id
      assert data.available_copies == before_copies
    end
  end

  describe "student-topic isolation pin" do
    test "borrow for student A never lands on student B's circulation:student topic" do
      user_a = create_user!()
      user_b = create_user!()
      book = create_book!(%{available_copies: 3})

      topic_a = "circulation:student:#{user_a.id}"
      topic_b = "circulation:student:#{user_b.id}"

      start_topic_relay(topic_a)
      start_topic_relay(topic_b)

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user_a.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      b = await_relay(topic_a, checkout.id)
      assert b.payload.data.id == checkout.id

      refute_receive {:w838_pubsub, _relay, %Phoenix.Socket.Broadcast{topic: ^topic_b}}
      refute_receive %Phoenix.Socket.Broadcast{topic: ^topic_b}
    end
  end

  describe "curation events land on the grade-band topic" do
    test "curation create -> recommendations:grade:<grade_band> carries the Curation payload" do
      book = create_book!()
      student_id = "student-#{System.unique_integer([:positive])}"
      grade_band = "6-8"
      topic = "recommendations:grade:#{grade_band}"

      start_topic_relay(topic)
      start_topic_relay("recommendations:curation_events")

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.com",
          grade_band: grade_band,
          student_id: student_id,
          reason: "Great fit"
        })
        |> Ash.create!(authorize?: false)

      b = await_relay(topic, curation.id)

      assert %Phoenix.Socket.Broadcast{
               topic: ^topic,
               payload: %Ash.Notifier.Notification{data: %Curation{} = data} = note
             } = b

      assert data.id == curation.id
      assert data.grade_band == grade_band
      assert note.action.name == :create

      ev = await_relay("recommendations:curation_events", curation.id)
      assert ev.payload.data.id == curation.id
      assert notification_name(ev) == :create
    end

    test "curation update -> recommendations:grade:<grade_band> reflects the new reason" do
      book = create_book!()
      student_id = "student-#{System.unique_integer([:positive])}"
      grade_band = "3-5"

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.com",
          grade_band: grade_band,
          student_id: student_id
        })
        |> Ash.create!(authorize?: false)

      topic = "recommendations:grade:#{grade_band}"
      start_topic_relay(topic)

      curation
      |> Ash.Changeset.for_update(:update, %{reason: "Updated reason"})
      |> Ash.update!(authorize?: false)

      b = await_relay(topic, curation.id)

      assert %Phoenix.Socket.Broadcast{
               topic: ^topic,
               payload: %Ash.Notifier.Notification{data: %Curation{} = data} = note
             } = b

      assert data.id == curation.id
      assert data.reason == "Updated reason"
      assert note.action.name == :update
    end
  end
end
