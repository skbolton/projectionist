defmodule Projectionist do
  @moduledoc """
  A toolkit for creating projections.

  Projectionist is broken into the following modules:

    * `Projectionist.Projection` - behaviour invoked to reduce a data source
    * `Projectionist.Reader` - supplier of data used in projections
    * `Projectionist.Store` - runs a projection over data produced by reader
    * `Projectionist.Window` - provides intermediate projection values from a stream

  ## Projections

  A projection can be looked at like any other data model. The key difference is
  in how it is created and updated. Instead of mutating a record and storing the
  result, a projection is built by reducing a data source into a model. The
  produced model itself is immutable and changes can only occur by adding new
  items to the data source and re-applying the projection.

  Through this approach easier auditability and debugging are gained. It's much
  easier to see how a given state was reached since the records can be replayed
  to see how they interact with the projection. There can also be several
  projections built from the same data source answering different questions.

  As an example here is a projection that sums transactions into an available
  balance.

    def MyApp.AvailableBalanceProjection do
      use Projectionist.Projection
      alias MyApp.Transaction

      @impl Projectionist.Projection
      def init() do
        initial_state = %{available_balance: Decimal.new(0)}
        {:ok, initial_state}
      end

      @impl Projectionist.Projection
      def project(%Transaction{value: value}, projection) do
        Map.update!(projection, :available_balance, fn available_balance ->
          Decimal.add(available_balance, value)
        end)
      end
    end

  ## Readers

  Without data to project over a projection cannot go very far. Readers supply
  data that projections can reduce. They also are in charge of putting the data
  stream into a deterministic order, see `t:versioning_key/0`, and being able
  to query the stream for record from a singular entity. Readers are implemented
  as a protocol to support reading from any data source. The following will show
  a SQL reader which will be most common.

    sql_reader = Projectionist.Reader.SQL.new(
      repo: MyApp.Repo,
      queryable: MyApp.Transaction,
      id: :account_id,
      versioning_key: :transaction_datetime
    )

  ## Stores

  Stores join readers and projections and give the api to query and build a
  projection. Using the previous examples here is a store that could be used
  to query the available balance of an account. Add stores somewhere in the
  supervision tree.

    defmodule MyApp.AvailableBalanceStore do
      use Projectionist.Store
      alias MyApp.AvailableBalanceProjection

      def start_link(_opts) do
        sql_reader = Projectionist.Reader.SQL.new(
          repo: MyApp.Repo,
          queryable: MyApp.Transaction,
          id: :account_id,
          versioning_key: :transaction_datetime
        )

        Projectionist.Store.start_link(
          name: __MODULE__,
          projection: AvailableBalanceProjection,
          snapshot: nil,
          source: sql_reader
        )
      end
    end

  Now we could get the balance of account `123`.

    Projectionist.Store.get(MyApp.AvailableBalanceStore, "123")

  ## Windows

  Projections reduce a data stream into a singular value, but what if multiple
  values are needed? Take the example of getting the ending balance of an
  account over the last 12 months. This could be achieved by running 12
  different projections for each period. While this would work, it would be
  inefficient and slow. Instead windows can be used to peek in and get values
  out at intervals that can be specified.

  If a window is specified when calling into a store the return value will
  be a list of values that were emitted in the window. The last value in this
  list will always be the last value of the projection.

  ### Defining Windows

  Window triggers are callbacks that take the following arguments

    1. The current item in the source data stream
    2. The projection **up to but not including** the current item
    3. Window state accumulator

  The window state accumulator is any value that is needed to decide when to
  emit window values.

  ### Emitting Values

  The return value of the trigger callback determines whether a window value
  should be added or if the projection should continue on processing

  Emit a value in window
    
    {:emit, value_to_emit, new_window_state}

  It is also possible to adjust the projection to reset some values. Its important to note
  that the current item has not yet been processed so a new projection value will be passed
  to the current iteration.

    {:emit, value_to_emit, adjusted_projection, new_window_state}

  ### Example

  Using the previous example of getting an accounts balance at months ends here is a window
  definition and its usage.

    period_ends = [~N[2020-02-01 00:00:00], ~N[2020-03-01 00:00:00]]
    window = Projectionist.Window.trigger(period_ends, fn transaction, balance_projection, periods ->
      [current_period | next_periods] = periods

      if DateTime.compare(transaction.timestamp, current_period) == :gt do
        {:emit, balance_projection, next_periods}
      else
        {:cont, balance_projection}
    end)

    {:ok, windows} = Projectionist.Store.get(AvailableBalanceStore, "123", window: window)
  """

  @typedoc """
  Model that is built up from reducing a source stream of data.

  This is a user defined value that is being returned by modules implementing
  the `Projectionist.Projection` behaviour.
  """
  @type projection :: term()

  @typedoc """
  Value that puts a data source into a deterministic order.

  When querying snapshot or source stream data its important that the order is
  deterministic to always yield the same results. This user defined value helps
  achieve that based on data source being used in a projection.
  See `Projectionist.Snapshot.Schema` and `Projectionist.Reader.Read` for
  examples of its usage.
  """
  @type versioning_key :: term()

  @typedoc """
  A value representing a version of a record.

  In order to query a from a given point, or up until a given point a version
  can be passed. `versioning_key` puts a stream in order, `version` is a value
  of a `versioning_key` at a given point in the stream.

  For example a data source using a timestamp as a `versioning_key` would result
  in the following.

    versioning_key = :transaction_datetime
    version = ~N[2022-01-01 00:00:00]
  """
  @type version :: term()
end

