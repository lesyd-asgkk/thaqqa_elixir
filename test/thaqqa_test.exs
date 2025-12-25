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

    Thaqqa.FontIO.import()
    Thaqqa.FontIO.import("default")

    # Thaqqa.FontManager.get_font("Default")
    table =
      Thaqqa.FontManager.get_static_table("VOWEL")
      # |> Thaqqa.Font.get_table("VOWEL")
      |> Thaqqa.DataTable.get_data(&(&1 |> Thaqqa.Data.get_val("Name") == "a"))

    IO.inspect(table, label: "font")

    # Supervisor.start_link(Thaqqa.FontManager, strategy: :one_for_one)
  end
end
