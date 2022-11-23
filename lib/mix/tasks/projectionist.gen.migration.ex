defmodule Mix.Tasks.Projectionist.Gen.Migration do
  @moduledoc """
  Generates a migration for a new snapshot table.

  This module creates a migration and injects the needed fields to work with
  `Projectionist.Snapshot.Schema`s for storing snapshots in SQL. This task
  wraps `ecto.gen.migration ...` by adding the necessary changes into
  a migration.

  ## Examples

    $ mix projectionist.gen.migration add_available_balance_v1 --table available_balance_v1 --entity-id-type binary_id --version-type utc_datetime
    $ mix projectionist.gen.migration add_available_balance_v1 --table available_balance_v1 entity-id-type binary_id --version-type string

  This task can be ran exactly like `mix ecto.gen.migration` but you must include
  the `--table`, `--entity-id-type`, and `--version-type` flags in order to
  configure the migration.

  ## Command Line Options

    * `--table` - the name of the table (should match what is given to Projectionist.Snapshot.Schema)
    * `--version-type` - type of the field being used for versions of snapshots
    * `--entity-id-type` - type of the field being used to separate entities

  All other options are passed through to `mix ecto.gen.migration`
  """
  alias Mix.Tasks.Ecto.Gen

  # switches to send to ecto migration
  # there are more but we can add them as we need
  @ecto_switches [
    migrations_path: :string
  ]

  # Switches for snapshot migration
  @switches [
    table: :string,
    entity_id_type: :string,
    version_type: :string
  ]

  @doc """
  Wraps `ecto.gen.migration` task and injects a migration for a snapshot table.
  """
  def run(args) do
    # parse both our flags and ecto flags
    {all_opts, [table_name], []} = OptionParser.parse(args, strict: @switches ++ @ecto_switches)

    # build up an argv of ecto args
    ecto_flags =
      all_opts
      |> Enum.filter(fn {key, _value} -> Keyword.has_key?(@ecto_switches, key) end)
      |> OptionParser.to_argv()

    # run migration
    [migration_file] = Gen.Migration.run([table_name | ecto_flags])

    # read the file and inject migration needed for snapshot
    contents = File.read!(migration_file)
    with_injected_change = String.replace(contents, ~r/.*def change.*do\n\n\s+end\n/, migration_template(all_opts))
    File.write!(migration_file, with_injected_change)

    # keep the same return as `mix ecto.gen.migration`
    [migration_file]
  end

  defp migration_template(opts) do
    table = opts[:table]
    version_type = opts[:version_type]
    entity_id_type = opts[:entity_id_type]

    ~s"""
      def change() do
        create table(:#{table}) do
          add :entity_id, :#{entity_id_type}, null: false
          add :data, :map, null: false
          add :version, :#{version_type}, null: false
          timestamps()
        end

        create unique_index(:#{table}, [:entity_id, :version])
      end
    """
  end
end
