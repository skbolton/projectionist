defmodule Projectionist.Window.Single do
  @moduledoc """
  The default window which collects all values and emits a window
  of a single value.
  """
  defstruct []

  defimpl Projectionist.Window.Windower do
    def materialize(_window, stream, projector, projection) do
      Enum.reduce(stream, projection, &projector.project/2)
    end
  end
end
