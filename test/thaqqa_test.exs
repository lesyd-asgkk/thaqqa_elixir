defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  def find_lists(data, path \\ []) do
    cond do
      is_list(data) ->
        IO.inspect(path, label: "LIST FOUND")

        Enum.each(data, fn v ->
          find_lists(v, path ++ ["[]"])
        end)

      is_map(data) ->
        Enum.each(data, fn {k, v} ->
          find_lists(v, path ++ [k])
        end)

      true ->
        :ok
    end
  end

  test "creates a new point" do
    # FontRegistryのGenServerプロセスを生成する。
    # プロセスの実行中はデータベースの原型として機能する。
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    # import_as_root()ではdata/main.jsonの読み取りを、
    # import_as_font(<フォルダ名>)ではdata/<フォルダ名>/main.jsonの読み取りを行う。
    Thaqqa.FontRegistry.import_as_root()
    Thaqqa.FontRegistry.import_as_font("default")

    # Thaqqa.FontRegistry.create_prefab()により、FontRegistryに保存されているデータベースのローカルでの操作・使用を可能とする。
    {:ok, prefab} = Thaqqa.FontRegistry.create_prefab()

    {:ok, glyph} = Thaqqa.Glyph.new(prefab, "Default", "C(onset,t0-d0-hd0)", "vertical", 16)

    glyph = Thaqqa.Glyph.set_path(glyph)

    {:ok, glyph} = Thaqqa.Glyph.render_by_relative_height(prefab, glyph, 10, 20)

    IO.puts(glyph.path |> SVG.Path.export_as_string_mass!())

    #

    j =
      Jason.encode!(%{prefab: prefab}, pretty: true)
      |> Jason.decode!()

    j["prefab"]
    |> Thaqqa.FontRegistryPrefab.new_from_request()

    # ※ 二重以上のダイアクリティカルマークにエラー。最初の一つしか反映されていない様子
    # ※ glyph系統の処理を見直すこととする
    # Thaqqa.FontRegistry.export_as_font("Default", pretty: true)
  end
end

'''

    # convert_into_khhyl_letter(prefab,文字列、フォント、言語、書字方向指定)により、
    # 指定した文字列が東果文字内部表現に変換される。
    {:ok, string} =
      Thaqqa.Render.convert_into_khhyl_letter(
        prefab,
        "highirith, kako karutaraa qahhowi uzhute kaghangetlaa. \nittlutu kadha, eqhoghi reewe qarhilas. 1234",
        "Default",
        "khehyelu",
        "vertical"
      )

    # 東果文字内部表現をプログラムが扱いやすいようグリフ単位で分割する。
    # 分割不能な文字を発見した場合はエラーとなる。
    {:ok, list} = Thaqqa.Render.split_by_syllable(prefab, string)

    # build_path_data(prefab、東果文字内部表現のlist、フォント、書字方向、(デフォルトの)文字サイズ)により
    # 本格的な組版処理の前準備を行う(GlyphのListを返す)

    pd = Thaqqa.Render.build_path_data(prefab, list, "Default", "vertical", 8)

    # alignment_path_data_as_vertical(prefab,上記のグリフ列、レンダー条件)により組版処理、
    # concat_path_data()によりsvgのpathデータ(d)へと変換する。

    # render条件については Thaqqa.Render.build_render(横幅, 縦幅, 改行処理, 改行時の追加幅,
    # 揃え方(:centerならば中央揃え、:justifyならば一行を埋める), 最終行の揃え方,
    # 単語同士の隙間の幅、文字同士の隙間の幅)のように指定。
    # うち横幅、縦幅は指定必須。他は任意。

    list =
      Thaqqa.Render.alignment_path_data_as_vertical(
        prefab,
        pd,
        Thaqqa.Render.build_render(200, 600, :normal, 0, :center, :center)
      )
      |> Thaqqa.Render.concat_path_data()

      #
      # |> length()
      |> IO.puts()

'''
