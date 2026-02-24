defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    # 0.1秒ほど
    Thaqqa.FontIO.import_as_root()

    # 0.4秒ほど　regex,pathの処理数が馬鹿多いので
    Thaqqa.FontIO.import_as_font("default")

    {:ok, prefab} = Thaqqa.FontRegistry.create_prefab()

    p = prefab |> Thaqqa.ParserManager.parse!("suzusha koratl", "khehyelu")

    p =
      prefab
      |> Thaqqa.GsubManager.gsub!(p, "vertical")

    prefab
    |> Thaqqa.UniqueGposManager.gpos("Default", "S(mid,t0,e0,t0)", "vertical", "internal")
    |> IO.inspect()

    # この辺の変換は誤差

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
