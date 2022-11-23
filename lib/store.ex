defmodule Projectionist.Store do
  @moduledoc """
  Module for creating stores to query for projections.

  Stores combine data sources and possible snapshot streams along with
  projections to provide an API to query for a projections by entity id.

  If a store is configured with a snapshot reader it will query the newest
  snapshot and then query the data source for all events that follow the
  snapshot. It will then run these values through the projection. When no
  snapshot exists the store will query the data source from the first event and
  stream those into the projection.

  > See the different `Projectionist.Reader` implementations for their usage

  ## Fields

    * `name` (optional) - Name of the store process
    * `projection` - What projection behaviour to run when querying projection
    * `snapshot` (optional) - A `Projectionist.Reader` for querying snapshot data
    * `source` - `Projectionist.Reader` for querying data source stream

  ## Example

    defmodule MyApp.Accounts.AvailableBalance.V1.Store do
      def start_link(_opts) do
        Projectionist.Store.start_link(
          name: __MODULE__,
          projection: MyApp.Accounts.AvailableBalance.V1.Projection,
          # for snapshotting supply a `Projectionist.Reader` here
          snapshot: nil,
          source: Projectionist.Reader.SQL.new(
            repo: MyApp.Repo,
            queryable: MyApp.Transaction,
            id: :account_id,
            versioning_key: :initial_datetime
          )
        )
      end
    end

    Projectionist.Store.get(MyApp.Accounts.AvailableBalance.V1.Store, account_id)
  """
  use Agent
  alias Projectionist.Reader
  alias Projectionist.Window

  @doc false
  defmacro __using__(_opts) do
    quote do
      def child_spec(arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [arg]}
        }
      end
    end
  end

  @spec start_link(list()) :: {:ok, pid()}
  @doc """
  Start a `Projectionist.Store` process.
  """
  def start_link(config) do
    Agent.start_link(fn -> Map.new(config) end, name: config[:name])
  end

  @callback get(pid() | atom(), any(), keyword()) :: Projectionist.projection()
  @doc """
  Use `store` to run projection for `entity_id`
  """
  def get(store, entity_id, opts \\ []) do
    opts = Keyword.put_new(opts, :window, Window.single())

    store
    |> get_store()
    |> run_projection(entity_id, opts)
  end

  # no snapshot configured, stream from data source from beginning
  defp run_projection(
         %{snapshot: nil, projection: projection, source: source_reader},
         entity_id,
         opts
       ) do
    {:ok, initial_state} = projection.init()

    Reader.stream(
      source_reader,
      %Reader.Read{
        id: entity_id,
        position: :FIRST,
        count: :infinity,
        until: opts[:until],
        through: opts[:through]
      },
      fn stream ->
        Window.materialize(opts[:window], stream, projection, initial_state)
      end
    )
  end

  # snapshot exists, query it and then use its version to stream all records that follow the snapshot
  defp run_projection(
         %{snapshot: snapshot_reader, projection: projection, source: source_reader} = config,
         entity_id,
         opts
       ) do
    # it doesn't matter if we use until or through with before as we just need a snapshot
    # before the given time to start building a projection off.
    snapshot_read =
      case {opts[:until], opts[:through]} do
        {until, _through} when not is_nil(until) ->
          Reader.Read.new(id: entity_id, position: {:before, until}, count: 1)

        {_until, through} when not is_nil(through) ->
          Reader.Read.new(id: entity_id, position: {:before, through}, count: 1)

        {_until, _through} ->
          Reader.Read.new(id: entity_id, position: :LAST, count: 1)
      end

    case Reader.read(snapshot_reader, snapshot_read) do
      # snapshot is configured but current entity does not yet have one stored
      # can be treated the same as a snapshot not being configured at all
      [] ->
        run_projection(%{config | snapshot: nil}, entity_id, opts)

      [snapshot] ->
        version = Map.get(snapshot, :version)

        data_source_read =
          Reader.Read.new(
            id: entity_id,
            position: {:after, version},
            count: :infinity,
            until: opts[:until],
            through: opts[:through]
          )

        Reader.stream(source_reader, data_source_read, fn stream ->
          Window.materialize(opts[:window], stream, projection, snapshot.data)
        end)
    end
  end

  defp get_store(server) do
    Agent.get(server, & &1)
  end
end
