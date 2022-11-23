defmodule Projectionist.Window.SingleTest do
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

  test "collects entire stream into a single window value", %{source_reader: source_reader} do
    Reader.Testing.return(source_reader, [%{complete: false}, %{complete: false}])

    assert {:ok, %TodoProjection{}} = Store.get(__MODULE__, "id", window: Window.single())
  end
end
