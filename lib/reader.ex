defprotocol Projectionist.Reader do
  @moduledoc """
  Protocol for reading snapshot and data source streams.

  Readers are used by the `Projectionist.Store` to retreive both snapshots and to
  query data sources for data to run projections over. Anything wishing to supply
  snapshots and/or data sources should implement this protocol.

  ## Available Readers

    * `Projectionist.Reader.SQL`
  """

  @doc """
  Read from `reader` the params list in `read` returning a list of values.
  """
  @spec read(t(), Projectionist.Reader.Read.t()) :: [term()]
  def read(reader, read)

  @doc """
  Return a stream of values from `reader` for `read` params
  """
  @spec stream(t(), Projectionist.Reader.Read.t(), fun()) :: {:ok, any()}
  def stream(reader, read, callback)
end
