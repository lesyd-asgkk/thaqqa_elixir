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

    {:ok, value} = Thaqqa.FontRegistry.create_prefab()

    Thaqqa.LetterManager.get_table(value) |> IO.inspect()
    # この辺の変換は誤差

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
