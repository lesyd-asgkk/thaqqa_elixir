defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    Thaqqa.FontIO.import_as_root()
    Thaqqa.FontIO.import_as_font("default")

    {:ok, data} = Thaqqa.FontRegistry.create_prefab()

    data
    |> Thaqqa.FontRegistryPrefab.get_static_table("PARSER")
    |> IO.inspect()

    # 上記の前処理で2.3秒
    {:ok, table} = Thaqqa.FontRegistry.get_font("Default")

    Thaqqa.ParserRegister.parse!("suzusha koratl", "khehyelu")
    |> Thaqqa.GsubRegister.gsub!("vertical")
    |> Thaqqa.UniqueGsubRegister.unique_gsub!("Default", "vertical")
    |> IO.inspect()

    Thaqqa.ParserRegister.parse!("aterui", "khehyelu")
    |> Thaqqa.GsubRegister.gsub!("horizontal")
    |> Thaqqa.UniqueGsubRegister.unique_gsub!("Default", "horizontal")
    |> IO.inspect()

    Thaqqa.ParserRegister.parse!("rlryo'i adzara", "samlhta")
    |> Thaqqa.GsubRegister.gsub!("vertical")
    |> Thaqqa.UniqueGsubRegister.unique_gsub!("Default", "vertical")
    |> IO.inspect()

    t =
      Thaqqa.ParserRegister.parse!("tegh", "khehyelu")
      |> Thaqqa.GsubRegister.gsub!("vertical")
      |> Thaqqa.UniqueGsubRegister.unique_gsub!("Default", "vertical")

    t |> IO.inspect()

    t
    |> Thaqqa.GposRegister.gpos("Default", "vertical", "internal")
    |> IO.inspect()

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
