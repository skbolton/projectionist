defmodule Projectionist.StoreTest do
  use ExUnit.Case, async: true
  alias Projectionist.Reader
  alias Projectionist.Store
  alias Projectionist.TodoProjection
  alias Projectionist.Window

  describe "get/2" do
    setup do
      snap_reader = Reader.Testing.new()
      source_reader = Reader.Testing.new()

      {:ok, snap_reader: snap_reader, source_reader: source_reader}
    end

    test "no window specified - defaults to Window.Single", %{source_reader: source_reader} do
      opts = [name: __MODULE__, projection: TodoProjection, source: source_reader, snapshot: nil]
      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.stub(source_reader, [%{complete: false}, %{complete: true}])

      assert {:ok, %TodoProjection{}} = Store.get(__MODULE__, "id")
      assert {:ok, %TodoProjection{}} = Store.get(__MODULE__, "id", window: Window.single())
    end

    # NOTE: Basic Store/Window interaction - more thorough tests in Window.ManualTest
    test "custom trigger window can be specified", %{source_reader: source_reader} do
      opts = [name: __MODULE__, projection: TodoProjection, source: source_reader, snapshot: nil]
      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.stub(source_reader, [%{complete: false}, %{complete: true}])

      trigger_window =
        Window.trigger(nil, fn todo, projection, state ->
          # emit every value for testing sake
          {:emit, todo, projection, state}
        end)

      assert {:ok, [_window1, _window2, _window3]} =
               Store.get(__MODULE__, "id", window: trigger_window)
    end

    test "snapshots are configured but one is not available", %{
      snap_reader: snap_reader,
      source_reader: source_reader
    } do
      opts = [
        name: __MODULE__,
        projection: TodoProjection,
        source: source_reader,
        snapshot: snap_reader
      ]

      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.return(snap_reader, [])
      Reader.Testing.return(source_reader, [%{complete: false}, %{complete: false}])

      assert {:ok, %{incomplete: 2}} = Store.get(__MODULE__, "id")
    end

    test "snapshots are configured and available", %{
      snap_reader: snap_reader,
      source_reader: source_reader
    } do
      opts = [
        name: __MODULE__,
        projection: TodoProjection,
        source: source_reader,
        snapshot: snap_reader
      ]

      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.return(snap_reader, %{data: %TodoProjection{completed: 10, incomplete: 0}})
      # send through 3 more
      Reader.Testing.return(source_reader, [%{complete: false}, %{complete: false}])

      Reader.Testing.on_read(snap_reader, fn %Reader.Read{position: position} ->
        assert position == :LAST
      end)

      assert {:ok, %{completed: 10, incomplete: 2}} = Store.get(__MODULE__, "id")
    end

    test "snapshots are configured and available with until key", %{
      snap_reader: snap_reader,
      source_reader: source_reader
    } do
      until_version = 3

      opts = [
        name: __MODULE__,
        projection: TodoProjection,
        source: source_reader,
        snapshot: snap_reader
      ]

      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.return(snap_reader, %{data: %TodoProjection{completed: 3, incomplete: 0}})
      Reader.Testing.return(source_reader, [%{complete: false}, %{complete: false}])

      Reader.Testing.on_read(snap_reader, fn %Reader.Read{position: position} ->
        assert position == {:before, until_version}
      end)

      assert {:ok, %{completed: 3, incomplete: 2}} =
               Store.get(__MODULE__, "id", until: until_version)
    end

    test "no snapshots configured", %{source_reader: source_reader} do
      opts = [name: __MODULE__, projection: TodoProjection, source: source_reader, snapshot: nil]
      {:ok, _pid} = Store.start_link(opts)

      Reader.Testing.return(source_reader, [%{complete: false}, %{complete: true}])

      assert {:ok, %{completed: 1, incomplete: 1}} = Store.get(__MODULE__, "id")
    end
  end
end
