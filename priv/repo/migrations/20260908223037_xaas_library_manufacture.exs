defmodule Xaas.Repo.Migrations.XaasLibraryManufacture do
  @moduledoc """
  Updates resources based on their most recent snapshots for Xaas.Library domain.
  """
  use Ecto.Migration

  def up do
    create table(:library_books, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :title, :text, null: false
      add :author, :text, null: false
      add :isbn, :text
      add :grade_level, :bigint, null: false
      add :genres, {:array, :text}, null: false, default: []
      add :synopsis, :text
      add :available_copies, :bigint, null: false, default: 1
      add :total_copies, :bigint, null: false, default: 1
      add :embedding, {:array, :float}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:library_curations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :curated_by, :text, null: false
      add :grade_band, :text, null: false
      add :reason, :text
      add :active, :boolean, null: false, default: true

      add :book_id,
          references(:library_books,
            column: :id,
            name: "library_curations_book_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:library_checkouts, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :borrowed_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :returned_at, :utc_datetime_usec
      add :status, :text, null: false, default: "borrowed"

      add :book_id,
          references(:library_books,
            column: :id,
            name: "library_checkouts_book_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "library_checkouts_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    drop table(:library_checkouts)
    drop table(:library_curations)
    drop table(:library_books)
  end
end
