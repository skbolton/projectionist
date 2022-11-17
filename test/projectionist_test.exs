defmodule ProjectionistTest do
  use ExUnit.Case
  doctest Projectionist

  test "greets the world" do
    assert Projectionist.hello() == :world
  end
end
