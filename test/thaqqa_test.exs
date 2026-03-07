defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    # 0.1秒ほど
    Thaqqa.FontIO.import_as_root()

    # 0.5秒ほど　何かしらで結構ラグっているが割と早い部類
    # (complement、regex/path処理で相応に時間がかかるので当然ではある)

    Thaqqa.FontIO.import_as_font("default")

    {:ok, prefab} = Thaqqa.FontRegistry.create_prefab()

    # prefab |> Thaqqa.PrefabCompiler.set_precompile_as_font("Default")
    # p = prefab |> Thaqqa.ParserManager.parse!("suzusha koratl", "khehyelu")

    {:ok, string} =
      Thaqqa.Render.convert_into_khhyl_letter(
        prefab,
        "suzusha koratl",
        "Default",
        "khehyelu",
        "vertical"
      )

    string |> IO.inspect()
    {:ok, list} = Thaqqa.Render.split_by_syllable(prefab, string)
    # list |> IO.inspect()

    Thaqqa.Render.build_path_data(prefab, list, "Default", "vertical")
    # |> IO.inspect()

    # この辺の変換は誤差

    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)
  end
end
