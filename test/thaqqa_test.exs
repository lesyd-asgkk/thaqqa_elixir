defmodule ThaqqaTest do
  use ExUnit.Case
  doctest Thaqqa
  doctest SVG

  test "creates a new point" do
    {:ok, _pid} = Thaqqa.FontRegistry.start_link([])

    # 0.1秒ほど
    Thaqqa.FontRegistry.import_const()

    # 0.5秒ほど　何かしらで結構ラグっているが割と早い部類
    # (complement、regex/path処理で相応に時間がかかるので当然ではある)

    Thaqqa.FontRegistry.import_bundle(0)

    {:ok, prefab} = Thaqqa.FontRegistry.create_prefab()

    # 0.1秒ほど
    # kako karutaraa qahhowe uzhute kaghangetlaa. ittlutu kadha, eqhoghi reewe qarhilas.
    {:ok, string} =
      Thaqqa.Render.convert_into_khhyl_letter(
        prefab,
        "highirith, kako karutaraa qahhowi uzhute kaghangetlaa. \nittlutu kadha, eqhoghi reewe qarhilas. 1234",
        "Default",
        "khehyelu",
        "vertical"
      )

    # 0.1秒ほど
    {:ok, list} = Thaqqa.Render.split_by_syllable(prefab, string)
    IO.inspect(string)
    IO.inspect(list)
    # タイムラグなし
    pd =
      Thaqqa.Render.build_path_data(prefab, list, "Default", "vertical", 8)

    # 0.1秒ほど。
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

    # この辺の変換は誤差
    # Supervisor.start_link(Thaqqa.FontRegistry, strategy: :one_for_one)

    # Thaqqa.Regex_Khhyl.tokenize("S(mid,,a0,)")
    # |> Thaqqa.Regex_Khhyl.normalize!()
    # |> Thaqqa.Regex_Khhyl.translate!(prefab)
    # |> IO.inspect()

    {:ok, glyph} = Thaqqa.Glyph.new(prefab, "Default", "S(init,r0,a0,th0)", "vertical", 16)

    glyph = Thaqqa.Glyph.set_path(glyph)

    {:ok, glyph} = Thaqqa.Glyph.render_by_relative_height(prefab, glyph, 10, 20)

    glyph.path
    |> SVG.Path.export_as_string_mass!()

    Thaqqa.FontIO.export_as_font("Default", pretty: true)
    |> IO.inspect()

    # def set_path(%__MODULE__{} = self), do: Thaqqa.Glyph.GlyphBuilder.set_path(self)

    # def render_by_relative_height(%Prefab{} = prefab, %__MODULE__{} = self, top_gap, bottom_gap),
    #  do: Thaqqa.Glyph.GlyphRenderer.render_by_relative_height(prefab, self, top_gap, bottom_gap)
  end
end
