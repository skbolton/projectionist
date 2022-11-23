defmodule Projectionist.Window.ManualTest do
  use ExUnit.Case, async: true
  alias Projectionist.Reader
  alias Projectionist.Store
  alias Projectionist.TodoProjection
  alias Projectionist.Window

  setup do
    source_reader = Reader.Testing.new()
    opts = [name: __MODULE__, projection: TodoProjection, source: source_reader, snapshot: nil]

    _pid = start_supervised!({Store, opts})

    {:ok, source_reader: source_reader}
  end

  describe "emitting window values" do
    test "final projection is always emitted in window", %{source_reader: source_reader} do
      # window that never emits
      window =
        Window.trigger(nil, fn _todo, projection, _window_state ->
          {:cont, projection}
        end)

      Reader.Testing.return(source_reader, [%{complete: false}, %{complete: false}])

      {:ok, [%TodoProjection{completed: 0, incomplete: 2}]} = Store.get(__MODULE__, "id", window: window)
    end

    test "can emit values without changing projection", %{source_reader: source_reader} do
      # Create a window that only emits the first value in the stream
      has_emitted = false

      window =
        Window.trigger(has_emitted, fn todo, projection, has_emitted ->
          if has_emitted do
            {:cont, projection}
          else
            has_emitted = true
            {:emit, todo, has_emitted}
          end
        end)

      first_todo = %{complete: false}
      second_todo = %{complete: true}

      Reader.Testing.return(source_reader, [first_todo, second_todo])

      expected_emitted_value = first_todo
      expected_projection = %TodoProjection{completed: 1, incomplete: 1}

      assert {:ok, [^expected_emitted_value, ^expected_projection]} = Store.get(__MODULE__, "id", window: window)
    end

    test "projection can be changed when emitting a window value", %{source_reader: source_reader} do
      # Create window that emits when incomplete todo is encountered
      # and resets the projection every time that happens

      window =
        Window.trigger(nil, fn todo, projection, window_state ->
          if todo.complete do
            {:cont, projection}
          else
            {:ok, reset_projection} = TodoProjection.init()
            {:emit, todo, reset_projection, window_state}
          end
        end)

      Reader.Testing.return(source_reader, [%{complete: true}, %{complete: true}, %{complete: false}])

      assert {:ok, [%{complete: false}, %TodoProjection{completed: 0, incomplete: 1}]} =
               Store.get(__MODULE__, "id", window: window)
    end
  end
end
