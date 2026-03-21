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

    # 0.1秒ほど
    {:ok, string} =
      Thaqqa.Render.convert_into_khhyl_letter(
        prefab,
        "highirith,\n  kako karutaraa qahhowe uzhute kaghangetlaa. \n ittlutu kadha, eqhoghi reewe qarhilas.",
        "Default",
        "khehyelu",
        "horizontal"
      )

    # 0.1秒ほど
    {:ok, list} = Thaqqa.Render.split_by_syllable(prefab, string)
    IO.inspect(string)
    IO.inspect(list)
    # タイムラグなし
    pd =
      Thaqqa.Render.build_path_data(prefab, list, "Default", "horizontal", 16)

    # 0.1秒ほど。
    # {:ok, list} =
    Thaqqa.Render.alignment_path_data_as_horizontal(prefab, pd, %{font: "Default", wrap: false})

    #  |> length()

    # list
    # |> Enum.map(fn %{y: y} -> y end)
    |> IO.inspect()

    # この辺の変換は誤差
    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)

    # Thaqqa.Regex_Khhyl.tokenize("S(mid,,a0,)")
    # |> Thaqqa.Regex_Khhyl.normalize!()
    # |> Thaqqa.Regex_Khhyl.translate!(prefab)
    # |> IO.inspect()
  end
end
