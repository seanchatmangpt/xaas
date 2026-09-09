defmodule Xaas.Library.Book do
  @moduledoc """
  Ash resource for Library Books, grounded in BIBO (bibo:Book) and Schema.org (schema:Book).
  Represents library items with ISBN, grade-level reading fit, genres, formats, and availability.

  ## pgvector / ash_ai vectorize wiring: BLOCKED at infrastructure

  This resource's `vectorize` block (below) and its `embedding` attribute's
  `Ash.Vector` type are real, correct AshPostgres/ash_ai code -- they wire
  `synopsis` -> `embedding` through `Xaas.Library.EmbeddingModels.LocalNx`
  (the existing local, HTTP-free Nx embedding function in
  `Xaas.Library.Embeddings.embed/1`) using the `:after_action` strategy.

  They do **not** yet produce a working end-to-end vector column on the
  current dev database. The exact blocking hop: the running dev Postgres
  instance has zero rows for `vector` in `pg_available_extensions`
  (confirmed via `psql ... -c "select * from pg_available_extensions where
  name='vector';"` against the real dev DB), so `CREATE EXTENSION vector`
  fails at migration/runtime time. This is not a vague "infra issue" -- the
  Postgres image/host currently used for dev simply does not ship the
  pgvector extension binary at all (`default_version` and
  `installed_version` both absent from `pg_available_extensions`), and will
  not until that image/host is swapped for one that does (e.g. the
  `pgvector/pgvector` Docker image).

  Do not run/enable the generated `vector`-extension migration against the
  default dev environment until a pgvector-capable Postgres has actually
  been provisioned.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshAdmin.Resource, AshAi]

  # Brings the real `prompt/2` macro (AshAi.Actions.prompt/2) into scope for
  # the `generate_recommendation_explanation` generic action's `run` clause
  # below -- confirmed real macro at deps/ash_ai/lib/ash_ai/actions.ex.
  import AshAi.Actions

  postgres do
    table "library_books"
    repo Xaas.Repo
  end

  vectorize do
    # BLOCKED at infrastructure -- see moduledoc above. This DSL wiring is
    # real; `CREATE EXTENSION vector` fails on the current dev Postgres.
    attributes(synopsis: :embedding)
    strategy :after_action
    embedding_model Xaas.Library.EmbeddingModels.LocalNx
  end

  admin do
    # `embedding` is an Ash.Vector (384 dims, hundreds of floats once
    # populated) -- AshAdmin's default table_columns is every attribute,
    # which would render this as an unreadable wall of numbers in the
    # datatable. Hide it from the table view; it remains a normal,
    # readable attribute everywhere else (API, GraphQL, show/edit forms).
    # It is no longer client-writable (see the `vectorize` block above --
    # it is derived via the :after_action strategy).
    table_columns [
      :id,
      :title,
      :author,
      :isbn,
      :grade_level,
      :genres,
      :formats,
      :available_copies,
      :total_copies,
      :review_status,
      :inserted_at,
      :updated_at
    ]
  end

  pub_sub do
    module XaasWeb.Endpoint
    prefix "library:books"
    broadcast_type :notification

    publish :create, ["created"]
    publish :create, ["events"]
    publish :update, ["updated", :id]
    publish :update, ["events"]
    publish :borrow_copy, ["inventory", :id]
    publish :borrow_copy, ["events"]
    publish :return_copy, ["inventory", :id]
    publish :return_copy, ["events"]
  end

  json_api do
    type "library_book"

    routes do
      base "/library/books"
      get :read
      index :read
    end
  end

  graphql do
    type :library_book

    queries do
      get :library_book, :read
      list :library_books, :read
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :title,
        :author,
        :isbn,
        :grade_level,
        :genres,
        :formats,
        :synopsis,
        :available_copies,
        :total_copies,
        :cover_color,
        :review_status
      ]
    end

    update :update do
      primary? true
      accept [
        :title,
        :author,
        :isbn,
        :grade_level,
        :genres,
        :formats,
        :synopsis,
        :available_copies,
        :total_copies,
        :cover_color,
        :review_status
      ]
    end

    update :borrow_copy do
      description "Atomically decrements available shelf copies when checked out"
      validate compare(:available_copies, greater_than: 0), message: "No shelf copies currently available"
      change atomic_update(:available_copies, expr(available_copies - 1))
    end

    update :return_copy do
      description "Atomically increments available shelf copies when returned"
      change atomic_update(:available_copies, expr(available_copies + 1))
    end

    read :by_grade_band do
      argument :min_grade, :integer, allow_nil?: false
      argument :max_grade, :integer, allow_nil?: false

      filter expr(grade_level >= ^arg(:min_grade) and grade_level <= ^arg(:max_grade))
    end

    # Real ash_ai `prompt/2` generic action (AshAi.Actions.Prompt) --
    # calls Groq via ReqLLM. No DB row required, so this is a generic
    # action, not a read/create action. GROQ_API_KEY is resolved by
    # ReqLLM's Groq provider default_env_key lookup (confirmed in
    # deps/req_llm/lib/req_llm/providers/groq.ex) -- not wired here.
    #
    # Kept as a real, callable LLM path with a real template-based
    # fallback on failure -- see lib/xaas/library/explainer.ex and
    # lib/xaas/library/explainer/{groq_adapter,template_adapter}.ex.
    action :generate_recommendation_explanation, :string do
      description """
      Generates a short, grounded, student-facing sentence explaining why a
      book was recommended, given the book's metadata, the student's recent
      reading history, and the ranker's scoring factors.
      """

      argument :book_title, :string, allow_nil?: false
      argument :book_author, :string, allow_nil?: false
      argument :book_grade_level, :string, allow_nil?: false
      argument :book_genres, {:array, :string}, default: []
      argument :past_titles, {:array, :string}, default: []
      argument :factor_summary, :string, allow_nil?: false

      run prompt("groq:llama-3.3-70b-versatile",
        prompt: {
          """
          You are a school librarian writing a one-sentence, student-facing
          explanation for why a book was recommended next. Keep it under 40
          words, warm but factual, and ground it only in the inputs given --
          never invent plot details or facts not present in the inputs.
          """,
          """
          Book: <%= @input.arguments.book_title %> by <%= @input.arguments.book_author %>
          Reading level: <%= @input.arguments.book_grade_level %>
          Genres: <%= Enum.join(@input.arguments.book_genres, ", ") %>
          Student's recent reads: <%= if @input.arguments.past_titles == [], do: "none yet", else: Enum.join(@input.arguments.past_titles, ", ") %>
          Ranker factors: <%= @input.arguments.factor_summary %>

          Write the one-sentence explanation now.
          """
        }
      )
    end
  end

  policies do
    policy action_type(:read) do
      # Reads are open to any actor, including an unauthenticated guest
      # browsing persona (actor: nil) -- see
      # lib/xaas_web/a2a/next_read_user_agent.ex's documented guest-browse
      # design. No write/mutation surface is exposed to reads.
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      # Deny-by-default floor (CLAUDE.md): mutations require a real,
      # resolved actor. Callers with no actor (e.g. a guest persona) are
      # denied -- see next_read_user_agent.ex's checkout/2, which already
      # refuses to call Ash.create without a resolved actor.
      authorize_if actor_present()
    end
  end

  aggregates do
    count :active_checkouts_count, :checkouts do
      filter expr(status == :borrowed)
    end

    count :active_holds_count, :holds do
      filter expr(status == :active)
    end
  end

  calculations do
    calculate :is_available, :boolean, expr(available_copies > 0)
    calculate :has_multiple_copies, :boolean, expr(available_copies > 1)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :author, :string do
      allow_nil? false
      public? true
    end

    attribute :isbn, :string do
      allow_nil? true
      public? true
    end

    attribute :grade_level, :decimal do
      allow_nil? false
      default Decimal.new("5.0")
      public? true
    end

    attribute :genres, {:array, :string} do
      allow_nil? false
      default []
      public? true
    end

    attribute :formats, {:array, :string} do
      allow_nil? false
      default ["Print"]
      public? true
    end

    attribute :synopsis, :string do
      allow_nil? true
      public? true
    end

    attribute :available_copies, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :total_copies, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :cover_color, :string do
      allow_nil? false
      default "#23405F"
      public? true
    end

    attribute :review_status, :atom do
      constraints [one_of: [:approved, :pending_librarian_review]]
      default :approved
      allow_nil? false
      public? true
    end

    attribute :embedding, :vector do
      constraints dimensions: 384
      allow_nil? true
      # Not public: AshGraphql/AshJsonApi cannot map Ash.Type.Vector to a
      # field type without a custom graphql_type/1 on the type (see the
      # compile error this avoided). The vector remains a normal,
      # readable/writable-via-code attribute; it is simply not exposed
      # over the GraphQL/JSON:API surfaces.
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :checkouts, Xaas.Library.Checkout
    has_many :holds, Xaas.Library.HoldRequest
    has_many :curations, Xaas.Library.Curation
  end
end
