defmodule Projectionist.Snapshot.Schema do
  @moduledoc """
  Helper module for creating Ecto Schemas to persist projections as snapshots.

  Snapshots are stored at a `t:Projectionist.version/0`. This value is used to
  differentiate newer snapshots from older snapshots. This value is also used
  after querying the snapshot to then retrieve values that come after that
  version. This is a configurable option and depends on what table is the source
  of a projection. 

  ## Options

    * `table` - table name to store snapshots at
    * `projection` - `Projectionist.Projection` to store in snapshot row
    * `version_type` - Ecto type of value used to version snapshots

  ## Example

    defmodule MyApp.AvailableBalanceSnapshot do
      use Projectionist.Snapshot.Schema,
        table: "available_balances_v1",
        projection: MyApp.AvailableBalanceProjection,
        version_type: :utc_datetime
    end
  """
  defmacro __using__(opts) do
    table = opts[:table]
    projection = opts[:projection]
    version_type = opts[:version_type]
    entity_id_type = opts[:entity_id_type]

    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, Ecto.UUID, autogenerate: true}

      @type t :: %__MODULE__{
              entity_id: term(),
              version: Projectionist.version(),
              data: unquote(projection).t(),
              inserted_at: DateTime.t(),
              updated_at: DateTime.t()
            }

      schema unquote(table) do
        field :entity_id, unquote(entity_id_type)
        field :version, unquote(version_type)
        embeds_one :data, unquote(projection)
        timestamps(type: :utc_datetime)
      end

      def changeset(model, params \\ %{}) do
        model
        |> cast(params, [:entity_id, :version])
        |> cast_embed(:data, required: true)
        |> validate_required([:entity_id, :version])
      end
    end
  end
end
