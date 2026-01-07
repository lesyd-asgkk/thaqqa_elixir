defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    Thaqqa.FontIO.import()
    Thaqqa.FontIO.import("default")

    {:ok, table} = Thaqqa.FontRegistry.get_font("Default")

    IO.inspect(table |> Thaqqa.Font.get_table("UniqueGSUB"))

    Thaqqa.ParserRegister.parse!("suzusha koratl", "khehyelu")
    |> Thaqqa.GsubRegister.gsub!("vertical")
    |> Thaqqa.UniqueGsubRegister.unique_gsub("Default", "vertical")
    |> IO.inspect()

    Thaqqa.ParserRegister.parse!("naylath kaatak", "khehyelu")
    |> Thaqqa.GsubRegister.gsub!("horizontal")
    |> IO.inspect()

    Thaqqa.ParserRegister.parse!("rlryo'i knngwahye", "samlhta")
    |> Thaqqa.GsubRegister.gsub!("vertical")
    |> IO.inspect()

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
