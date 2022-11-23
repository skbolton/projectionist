defmodule Projectionist.Projection do
  @moduledoc """
  Projection behaviours are modules that reduce a data source into a model.

  `Projectionist.Store` uses configured data sources and possible snapshots to
  feed data into a `Projectionist.Projection`.
  """
  @doc """
  The `c:init/0` callback is called to create the zero state of a projection.
  This will be used when there is not a snapshot that the projection can
  be hydrated from, or on brand new projections.
  """
  @callback init() :: {:ok, Projectionist.projection()}

  @doc """
  Callback that is called on each iteration of events to produce new projection
  """
  @callback project(any(), Projectionist.projection()) :: Projectionist.projection()
end
