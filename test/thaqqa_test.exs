defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest Svg
  doctest SVG.Point
  doctest SVG.Path

  test "creates a new point" do
    testobj =
      Thaqqa.Regex_Khhyl.tokenize("(?<name>S(init,t0-d0,a0,t0))")
      |> Thaqqa.Regex_Khhyl.normalize()

    assert testobj == "m -10.0,-10.0 l 30.0,30.0 v -50.0 l 80.0,230.0 z"
  end
end
