defmodule Projectionist.TodoProjection do
  @behaviour Projectionist.Projection
  @moduledoc """
  A projection for testing purposes

  Derives the count of complete vs incomplete todos
  """

  @enforce_keys [:completed, :incomplete]
  defstruct [:completed, :incomplete]

  @impl Projectionist.Projection
  def init() do
    state = %__MODULE__{completed: 0, incomplete: 0}

    {:ok, state}
  end

  @impl Projectionist.Projection
  def project(%{complete: false}, projection),
    do: %__MODULE__{projection | incomplete: projection.incomplete + 1}

  @impl Projectionist.Projection
  def project(%{complete: true}, projection),
    do: %__MODULE__{projection | completed: projection.completed + 1}
end
