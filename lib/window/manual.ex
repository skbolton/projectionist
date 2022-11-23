defmodule Projectionist.Window.Manual do
  @moduledoc """
  A Window that takes in a trigger callback to decide when to emit values.

    trigger = Projectionist.Window.trigger(initial_window_state, trigger_callback)

  ## Triggering windows

  The `trigger_callback` specifies whether a window value should be emitted and
  it takes the following args.

    1. The current item in the source data stream
    2. The projection **up to but not including** the current item
    3. Window state accumulator

  The return of this function controls whether a value is emitted as a window
  value.

  Emit value as a window value

    `{:emit, window_value, new_window_state}`

  Adjust the projection before processing current item

    `{:emit, window_value, new_projection, new_window_state}`

  Continue processing without emitting a window value

    `{:cont, projection}`

  ## Window return

  This window will always return a list of values. That list being all the emitted window
  values and ending with the final projection value.
  """

  @typedoc """
  An accumulator passed to `t:trigger_callback()` that caller can use to decide
  whether or not a window value should be emitted.
  """
  @type window_state :: term()

  @type window_value :: term()

  @type emit_return ::
          {:emit, window_value(), window_state()}
          | {:emit, window_value(), Projectionist.projection(), window_state()}
          | {:cont, Projectionist.projection()}

  @typedoc """
  Callback that receives the current item of stream, current projection before
  stream item was processed and the `t:window_state()`.

  Return value of callback specifies whether a window value should be emitted or
  not.
  """
  @type trigger_callback :: (term(), Projectionist.projection(), window_state() -> emit_return())

  @type t :: %__MODULE__{
          state: window_state(),
          trigger: trigger_callback()
        }

  defstruct [:state, :trigger]

  defimpl Projectionist.Window.Windower do
    def materialize(
          %Projectionist.Window.Manual{trigger: trigger, state: window_state},
          stream,
          projector,
          projection_baseline
        ) do
      emitted_window_values = []
      initial_state = {window_state, emitted_window_values, projection_baseline}

      {_window_state, windows, final_projection} =
        stream
        |> Enum.reduce(initial_state, fn item, {window_state, window_values, projection} ->
          case trigger.(item, projection, window_state) do
            {:emit, window_value, window_state} ->
              projection = projector.project(item, projection)
              {window_state, [window_value | window_values], projection}

            {:emit, window_value, projection, window_state} ->
              projection = projector.project(item, projection)
              {window_state, [window_value | window_values], projection}

            {:cont, projection} ->
              projection = projector.project(item, projection)
              {window_state, window_values, projection}
          end
        end)

      Enum.reverse([final_projection | windows])
    end
  end
end
