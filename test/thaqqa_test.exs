defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    # 0.3秒ほど
    Thaqqa.FontIO.import_as_root()

    # 2秒ほど　regex,pathの処理数が馬鹿多いので
    Thaqqa.FontIO.import_as_font("default")

    {:ok, table} = Thaqqa.FontRegistry.get_font("Default")

    # この辺の変換は誤差
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
