defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    Thaqqa.FontIO.import()
    Thaqqa.FontIO.import("default")

    Thaqqa.FontRegistry.get_font("Default")

    Thaqqa.ParserRegister.parse("suzusha koratl", "khehyelu")
    |> IO.inspect()

    # |> Thaqqa.DataTable.update_fontregistry()

    # |> Thaqqa.DataTable.get_column()

    # |> Enum.at(0)
    # IO.inspect(Thaqqa.FontRegistry.get_static_table_all())
    # IO.inspect(Thaqqa.FontRegistry.get_static_table("PARSER"))
    # IO.inspect(Thaqqa.FontRegistry.get_static_table("VOWEL"))

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
