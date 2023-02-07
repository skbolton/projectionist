defmodule Projectionist.Reader.SQL do
  @moduledoc """
  A `Projectionist.Reader` implementation using SQL that can be used for
  retrieving snapshots and/or data sources.

  ## Fields

    * `repo` - Repo to use to query for snapshot or data source stream
    * `queryabe` - Ecto.Queryable to use for source snapshot or data source
    * `id` - column in `queryable` that identifies a a given entity
      * in snapshots streams this will always be `entity_id`
      * for data source streams use whatever column is the entity id from source
    * `versioning_key` - column that puts source in deterministic order
      * snapshots use this to grab the newest snapshot
      * data sources use this to grab records after possible snapshot
    * max_rows (optional) - rows to fetch when streaming records from repo

  ## Examples

  Creating a reader for a snapshot stored in sql.

  ```elixir
  snapshot_reader = Projectionist.Reader.SQL.new(
    repo: Projectionist.Repo,
    queryable: Genesis.BankAccount.AvailableBalance.Snapshot,
    id: :entity_id,
    versioning_key: :version,
    max_rows: 1000
  )
  ```

  Creating a reader for a database table as a data source.

  ```elixir
  source_reader = Projectionist.Reader.SQL.new(
    repo: Projectionist.Repo,
    queryable: Genesis.Model.BankAccountTransaction,
    id: :bank_account_id,
    versioning_key: :initial_datetime,
    max_rows: 2500
  )
  ```
  """
  import Ecto.Query
  alias Projectionist.Reader

  @enforce_keys [:repo, :queryable, :id, :versioning_key]
  defstruct [:repo, :queryable, :id, :versioning_key, :max_rows]

  @type t :: %__MODULE__{
          repo: Ecto.Repo,
          queryable: Ecto.Queryable,
          id: term(),
          versioning_key: Projectionist.versioning_key(),
          max_rows: non_neg_integer() | nil
        }

  @doc """
  Creates a new SQL Reader
  """
  def new(params) do
    struct!(__MODULE__, params)
  end

  @doc """
  Builds query for retrieving `id` from position of stream
  """
  def build_query(%Reader.SQL{queryable: queryable} = config, %Reader.Read{
        id: id,
        position: :FIRST,
        count: count,
        until: until_key,
        through: through_key
      }) do
    versioning_key = config.versioning_key
    entity_id = config.id

    initial_query = from(i in queryable)

    initial_query
    |> where([i], field(i, ^entity_id) == ^id)
    |> order_by(asc: ^versioning_key)
    |> maybe_limit(count)
    |> maybe_until(versioning_key, until_key)
    |> maybe_through(versioning_key, through_key)
  end

  def build_query(%Reader.SQL{queryable: queryable} = config, %Reader.Read{
        id: id,
        position: :LAST,
        count: count,
        until: until_key,
        through: through_key
      }) do
    entity_id = config.id
    versioning_key = config.versioning_key

    initial_query = from(i in queryable)

    initial_query
    |> where([i], field(i, ^entity_id) == ^id)
    |> order_by(desc: ^versioning_key)
    |> maybe_limit(count)
    |> maybe_until(versioning_key, until_key)
    |> maybe_through(versioning_key, through_key)
  end

  def build_query(%Reader.SQL{queryable: queryable} = config, %Reader.Read{
        id: id,
        position: {:after, version},
        count: count,
        until: until_key,
        through: through_key
      }) do
    versioning_key = config.versioning_key

    entity_id = config.id

    initial_query = from(i in queryable)

    initial_query
    |> where([i], field(i, ^entity_id) == ^id)
    |> where([i], field(i, ^versioning_key) > ^version)
    |> order_by(asc: ^versioning_key)
    |> maybe_limit(count)
    |> maybe_until(versioning_key, until_key)
    |> maybe_through(versioning_key, through_key)
  end

  def build_query(%Reader.SQL{queryable: queryable} = config, %Reader.Read{
        id: id,
        position: {:before, version},
        count: count,
        until: until_key,
        through: through_key
      }) do
    versioning_key = config.versioning_key
    entity_id = config.id

    initial_query = from(i in queryable)

    initial_query
    |> where([i], field(i, ^entity_id) == ^id)
    |> where([i], field(i, ^versioning_key) < ^version)
    |> order_by(asc: ^versioning_key)
    |> maybe_limit(count)
    |> maybe_until(versioning_key, until_key)
    |> maybe_through(versioning_key, through_key)
  end

  defp maybe_limit(query, :infinity), do: query

  defp maybe_limit(query, count), do: limit(query, ^count)

  defp maybe_until(query, _versioning_key, nil), do: query

  defp maybe_until(query, versioning_key, until) do
    from(i in query, where: field(i, ^versioning_key) < ^until)
  end

  defp maybe_through(query, _versioning_key, nil), do: query

  defp maybe_through(query, versioning_key, through) do
    from(i in query, where: field(i, ^versioning_key) <= ^through)
  end

  defimpl Projectionist.Reader do
    def read(%Reader.SQL{repo: repo} = config, read) do
      config
      |> Reader.SQL.build_query(read)
      |> repo.all()
    end

    def stream(%Reader.SQL{repo: repo, max_rows: rows} = config, read, callback) do
      opts =
        if rows do
          [max_rows: rows]
        else
          []
        end

      stream =
        config
        |> Reader.SQL.build_query(read)
        |> repo.stream(opts)

      repo.transaction(fn ->
        callback.(stream)
      end)
    end
  end
end
