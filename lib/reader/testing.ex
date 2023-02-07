defmodule Projectionist.Reader.Testing do
  @moduledoc """
  A Projectionist.Reader implementation for testing purposes.

  When testing projections it can be useful to control what values are passed to
  them without having to talk to external dependencies.

  ## Usage

  Create a testing reader and configure a `Projectionist.Store` to use it as the
  data source supplier. Any calls to get a data stream will run through the
  testing reader.

  ```elixir
  testing_reader = Projectionist.Reader.Testing.new()
  {:ok, store} = MyApp.Store.start_link(source: testing_reader)
  ```

  Now the testing reader can be used to control what values are returned and
  used to run projection over, allowing more focused tests of a projection and
  how it handles data.

  ```elixir
  # on next read from reader return no results (zero state of projection)
  Testing.return(reader, [])
  {:ok, projection} = Projectionist.Store.get(store, entity_id)

  # on next read return a few records
  Testing.return(reader, [%{completed: true}, %{completed: false}])
  {:ok, projection} = Projectionist.Store.get(store, entity_id)
  ```

  It might also be desirable to set a fallback stubbed return for a reader. The
  stub will always be returned if no other return is given to the store

  ```elixir
  # default to returning an empty list
  Testing.stub(reader, []) 
  {:ok, projection} = Projectionist.Store.get(store, entity_id)
  ```
  """
  defstruct [:pid]

  @doc """
  Creates a new Reader used for testing.

  Passing a value will configure the stubbed return for the reader.

  ```elixir
  Projectionist.Reader.Testing.new([%{state: :failed}, %{state: :successful}])
  ```

  Same as

  ```elixir
  Projectionist.Reader.Testing.new()
  |> Projectionist.Reader.Testing.stub([%{state: :failed}, %{state: :successful}])
  ```
  """
  def new() do
    {:ok, pid} = Agent.start_link(fn -> {_stubs = nil, _expectations = [], _callbacks = []} end)
    %__MODULE__{pid: pid}
  end

  def new(stub_data) do
    {:ok, pid} =
      Agent.start_link(fn ->
        {_stubs = List.wrap(stub_data), _expectations = [], _callbacks = []}
      end)

    %__MODULE__{pid: pid}
  end

  @doc """
  Set, or update, the wanted stub value for `reader`
  """
  def stub(%__MODULE__{pid: pid}, value) do
    Agent.update(pid, fn {_old_stub, expectations, callbacks} ->
      {List.wrap(value), expectations, callbacks}
    end)
  end

  @doc """
  Add `value` to list wanted return values from `reader`
  """
  def return(%__MODULE__{pid: pid}, value) do
    Agent.update(pid, fn {stub, expectations, callbacks} ->
      # expectations is a list of lists
      # wrap passed value in a list to ensure that it always a list
      new_expectations = expectations ++ [List.wrap(value)]

      {stub, new_expectations, callbacks}
    end)
  end

  @doc """
  Takes in the reader and exposes the arguments read was called with
   through the callback.
  """
  def on_read(%__MODULE__{pid: pid}, callback) do
    Agent.update(pid, fn {stub, expectations, callbacks} ->
      {stub, expectations, [callback | callbacks]}
    end)
  end

  defimpl Projectionist.Reader do
    alias Projectionist.Reader.Read
    alias Projectionist.Reader.Testing

    def read(%Testing{pid: pid}, %Read{position: position} = read) do
      # create the read stream
      stream =
        case Agent.get(pid, & &1) do
          # no stub or expectation defined
          {nil, [], _callbacks} ->
            raise ArgumentError,
              message:
                "Projectionist.Reader.Testing called without any remaining return or stub values"

          {stub, [first_return | rest], callbacks} ->
            Enum.each(callbacks, fn callback -> callback.(read) end)
            # update state by dropping first return
            Agent.update(pid, fn _state -> {stub, rest, []} end)
            List.wrap(first_return)

          {stub, [], callbacks} ->
            Enum.each(callbacks, fn callback -> callback.(read) end)
            Agent.update(pid, fn _state -> {stub, [], []} end)
            List.wrap(stub)
        end

      case position do
        :LAST ->
          stream
          |> List.last()
          |> List.wrap()

        # for now don't offer a filter of the stub/expecation by version
        # callers should pass perfect lists that they assume every event will be seen
        # this makes :FIRST and version lookup the same
        _first_or_position ->
          stream
      end
    end

    def stream(%Testing{} = testing_reader, read_params, callback) do
      result =
        testing_reader
        |> read(read_params)
        |> callback.()

      {:ok, result}
    end
  end
end
