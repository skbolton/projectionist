defmodule Projectionist.Snapshot.SchemaTest do
  use ExUnit.Case, async: true

  use Projectionist.Snapshot.Schema,
    table: "projectionist_snapshot_testing",
    projection: Projectionist.TodoProjection,
    version_type: :integer,
    entity_id_type: :integer

  test "table name for schema is set correctly" do
    assert __MODULE__.__schema__(:source) == "projectionist_snapshot_testing"
  end

  test "embedded projection for schema is set correctly" do
    assert {
             :parameterized,
             Ecto.Embedded,
             %Ecto.Embedded{
               related: Projectionist.TodoProjection
             }
           } = __MODULE__.__schema__(:type, :data)
  end

  test "versioning_key for schema is set correctly" do
    # based on `use Projectionist.Snapshot.Schema` in this test
    assert :integer = __MODULE__.__schema__(:type, :version)
  end
end
