defmodule Projectionist.Window do
  alias __MODULE__.Manual

  @spec trigger(Manual.window_state(), Manual.trigger_callback()) :: Manual.t()
  @doc """
  Create a Trigger window with `trigger_callback`
  """
  def trigger(window_state, trigger_callback) do
    %__MODULE__.Manual{state: window_state, trigger: trigger_callback}
  end

  @doc """
  Create a Single Window
  """
  def single(), do: %__MODULE__.Single{}

  @doc """
  Produce window data using `window` over `stream` and `projector`.
  """
  def materialize(window, stream, projector, init_projection) do
    __MODULE__.Windower.materialize(window, stream, projector, init_projection)
  end

  defprotocol Windower do
    @moduledoc """
    Protocol for running projection over a stream and collecting results into
    windows.
    """
    @spec materialize(t(), Enumerable.t(), module(), Projectionist.projection()) :: any()
    def materialize(window, stream, projection, initial_state)
  end
end
