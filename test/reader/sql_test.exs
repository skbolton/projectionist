defmodule Projectionist.Reader.SQLTest do
  use ExUnit.Case, async: true
  import Ecto.Query
  alias Ecto.Adapters.SQL
  alias Projectionist.Reader

  setup tags do
    :ok = SQL.Sandbox.checkout(Projectionist.Repo)

    unless tags[:async] do
      SQL.Sandbox.mode(Projectionist.Repo, {:shared, self()})
    end

    :ok
  end

  # Create a test db and data to work with
  setup do
    SQL.query(
      Projectionist.Repo,
      ~s"""
      CREATE TABLE projections_testing (
        amount float,
        bank_account_id integer,
        version integer
      )
      """
    )

    Projectionist.Repo.insert_all(
      "projections_testing",
      [
        # bank account 1
        %{amount: 10.0, bank_account_id: 1, version: 1},
        %{amount: 5.0, bank_account_id: 1, version: 2},
        %{amount: 2.0, bank_account_id: 1, version: 3},
        # bank account 2
        %{amount: 20.0, bank_account_id: 2, version: 1},
        %{amount: 7.0, bank_account_id: 2, version: 2},
        %{amount: 4.0, bank_account_id: 2, version: 3}
      ]
    )

    # create a reader for testing
    reader =
      Reader.SQL.new(
        repo: Projectionist.Repo,
        queryable:
          from(item in "projections_testing",
            select: %{
              version: item.version,
              amount: item.amount,
              bank_account_id: item.bank_account_id
            }
          ),
        id: :bank_account_id,
        versioning_key: :version
      )

    {:ok, reader: reader}
  end

  describe "read/2" do
    test "reading from the :FIRST position", %{reader: reader} do
      # bank account 1
      read = Reader.Read.new(id: 1, position: :FIRST, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # bank account 2
      read = Reader.Read.new(id: 2, position: :FIRST, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2},
               %{amount: 4.0, bank_account_id: 2, version: 3}
             ] = results
    end

    test "reading from the :LAST position", %{reader: reader} do
      # bank account 1
      read = Reader.Read.new(id: 1, position: :LAST, count: 1)
      results = Reader.read(reader, read)

      assert [%{amount: 2.0, bank_account_id: 1, version: 3}] = results

      # bank account 2
      read = Reader.Read.new(id: 2, position: :LAST, count: 1)
      results = Reader.read(reader, read)

      assert [%{amount: 4.0, bank_account_id: 2, version: 3}] = results
    end

    test "reading from after position", %{reader: reader} do
      # read from 0 - same as :FIRST in this case
      read = Reader.Read.new(id: 1, position: {:after, 0}, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # read from 1
      read = Reader.Read.new(id: 1, position: {:after, 1}, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # read from 2
      read = Reader.Read.new(id: 1, position: {:after, 2}, count: :infinity)
      results = Reader.read(reader, read)

      assert [%{amount: 2.0, bank_account_id: 1, version: 3}] = results

      # read from 3
      read = Reader.Read.new(id: 1, position: {:after, 3}, count: :infinity)
      assert [] = Reader.read(reader, read)
    end

    test "reading from before position", %{reader: reader} do
      # read before 1 - should be empty as nothing before position one
      read = Reader.Read.new(id: 1, position: {:before, 0}, count: :infinity)
      results = Reader.read(reader, read)

      assert [] = results

      # read before 2
      read = Reader.Read.new(id: 1, position: {:before, 2}, count: :infinity)
      results = Reader.read(reader, read)

      assert [%{amount: 10.0, bank_account_id: 1, version: 1}] = results

      # read before 3
      read = Reader.Read.new(id: 1, position: {:before, 3}, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2}
             ] = results

      # read before version that does not exist yet
      read = Reader.Read.new(id: 1, position: {:before, 40}, count: :infinity)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = Reader.read(reader, read)
    end

    test "reading with until key", %{reader: reader} do
      # returns all results prior to the until position
      read = Reader.Read.new(id: 2, position: :FIRST, until: 3, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2}
             ] = results

      # until is first available
      read = Reader.Read.new(id: 2, position: :FIRST, until: 1, count: :infinity)
      results = Reader.read(reader, read)

      assert [] = results

      # until is beyond available versions returns all
      read = Reader.Read.new(id: 2, position: :FIRST, until: 10, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2},
               %{amount: 4.0, bank_account_id: 2, version: 3}
             ] = results
    end

    test "reading with through key", %{reader: reader} do
      # returns all results including the through position
      read = Reader.Read.new(id: 2, position: :FIRST, through: 2, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2}
             ] = results

      # through is beyond available versions returns all
      read = Reader.Read.new(id: 2, position: :FIRST, through: 10, count: :infinity)
      results = Reader.read(reader, read)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2},
               %{amount: 4.0, bank_account_id: 2, version: 3}
             ] = results
    end
  end

  describe "stream/3" do
    test "streaming from :FIRST position", %{reader: reader} do
      # bank account 1
      read = Reader.Read.new(id: 1, position: :FIRST, count: :infinity)

      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # bank account 2
      read = Reader.Read.new(id: 2, position: :FIRST, count: :infinity)

      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [
               %{amount: 20.0, bank_account_id: 2, version: 1},
               %{amount: 7.0, bank_account_id: 2, version: 2},
               %{amount: 4.0, bank_account_id: 2, version: 3}
             ] = results
    end

    test "streaming from :LAST position", %{reader: reader} do
      # bank account 1
      read = Reader.Read.new(id: 1, position: :LAST, count: 1)

      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [%{amount: 2.0, bank_account_id: 1, version: 3}] = results

      # bank account 2
      read = Reader.Read.new(id: 2, position: :LAST, count: 1)

      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [%{amount: 4.0, bank_account_id: 2, version: 3}] = results
    end

    test "streaming from specific position", %{reader: reader} do
      # read from 0 - same as :FIRST in this case
      read = Reader.Read.new(id: 1, position: {:after, 0}, count: :infinity)
      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [
               %{amount: 10.0, bank_account_id: 1, version: 1},
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # read from 1
      read = Reader.Read.new(id: 1, position: {:after, 1}, count: :infinity)
      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [
               %{amount: 5.0, bank_account_id: 1, version: 2},
               %{amount: 2.0, bank_account_id: 1, version: 3}
             ] = results

      # read from 2
      read = Reader.Read.new(id: 1, position: {:after, 2}, count: :infinity)
      {:ok, results} = Reader.stream(reader, read, &verify_stream/1)

      assert [%{amount: 2.0, bank_account_id: 1, version: 3}] = results

      # read from 3
      read = Reader.Read.new(id: 1, position: {:after, 3}, count: :infinity)
      assert {:ok, []} = Reader.stream(reader, read, &verify_stream/1)
    end
  end

  # verify that we are given a stream and convert it to a list to assert against
  defp verify_stream(%Stream{} = stream) do
    Enum.to_list(stream)
  end

  defp verify_stream(_non_stream) do
    flunk("Stream was not passed in stream/3")
  end
end
