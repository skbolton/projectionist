defmodule Projectionist.Snapshot.MigrationTest do
  use Genesis.VanillaCase, async: true
  alias Mix.Tasks.Projectionist.Gen.Migration

  # create a tmp directory for putting test migrations
  @moduletag :tmp_dir

  test "values are correctly injected into the migration", %{tmp_dir: dir} do
    [migration_file] =
      Migration.run([
        "add_snapshot_migration_test",
        "--table",
        "some_table",
        "--version-type",
        "utc_datetime",
        "--entity-id-type",
        "binary_id",
        # dump migration file to temp dir
        "--migrations-path",
        dir
      ])

    migration = File.read!(migration_file)

    # table name is put in place
    assert migration =~ "create table(:some_table) do"
    # entity id is put in place
    assert migration =~ "add :entity_id, :binary_id, null: false"
    # projection slot is put in place
    assert migration =~ "add :data, :map, null: false"
    # version type is put into place
    assert migration =~ "add :version, :utc_datetime, null: false"
    # unique index is set
    assert migration =~ "create unique_index(:some_table, [:entity_id, :version])"
  end
end
