defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa

  test "creates a new point" do
    testobj =
      Thaqqa.Regex_Khhyl.tokenize("(^|P(*))S(null,,(+),)($|P(*))")
      |> Thaqqa.Regex_Khhyl.normalize()
      |> Thaqqa.Regex_Khhyl.translate()
      |> Regex.compile!()

    IO.inspect(testobj, label: "testobj")
    IO.inspect(Regex.match?(testobj, "S(null,,a0,)"), label: "testobj")

    {:ok, _pid} = Thaqqa.FontManager.start_link([])

    Thaqqa.FontIO.import(true)
    IO.inspect(Thaqqa.FontManager.get_static_table_all(), label: "font")

    # Supervisor.start_link(Thaqqa.FontManager, strategy: :one_for_one)
  end
end
