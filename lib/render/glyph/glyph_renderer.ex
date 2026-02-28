defmodule Thaqqa.GlyphRenderer do
  import SVG.Path
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Glyph, as: Glyph

  # rectangleを描画する用（汎用関数でもないのでpath本体には追記しなかった）

  defp draw_rectangle(x0, y0, x1, y1) do
    if y0 >= y1 || x0 >= x1 do
      %SVG.Path{}
    else
      %SVG.Path{
        commands: [
          SVG.Command.new_m_absolute(x0, y0),
          SVG.Command.new_l_absolute(x0, y1),
          SVG.Command.new_l_absolute(x1, y1),
          SVG.Command.new_l_absolute(x1, y0),
          SVG.Command.new_z_absolute()
        ]
      }
    end
  end

  def render_with_relative_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          height: %{y0: y0, y1: y1, y2: y2, y3: y3},
          font: font,
          internal_attribution: %{is_null: false},
          path: path
        } = self,
        top_gap,
        bottom_gap
      ) do
    thickness_raw = Prefab.get_single_data_value(prefab, font, "FONTDATA", "Thickness")

    # 将来用。1のところに倍率指定を置く
    thickness = thickness_raw * 1
    th_half = thickness / 2

    case form do
      "sol" ->
        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.toRelativeAll()

        %Glyph{self | path: path}

      "init" ->
        skewer = draw_rectangle(-th_half, top_gap + y2, th_half, bottom_gap + y3)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.to_relative()
          |> concat_path(skewer)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      "mid" ->
        skewer_top = draw_rectangle(-th_half, y0, th_half, y1)
        skewer_bottom = draw_rectangle(-th_half, y2, th_half, bottom_gap + y3)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.to_relative()
          |> concat_path(skewer_top)
          |> concat_path(skewer_bottom)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      "fin" ->
        skewer = draw_rectangle(-th_half, y0, th_half, y1)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.to_relative()
          |> concat_path(skewer)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      _ ->
        raise "fatal: invalid form found at render_with_absolute_height/4"
    end
  end

  def render_with_relative_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          height: %{y0: y0, y3: y3},
          font: font,
          internal_attribution: %{is_null: true},
          path: path
        } = self,
        top_gap,
        bottom_gap
      ) do
    # 下からどれだけ、という値なのを、上からどれだけ、に換算する。

    thickness_raw = Prefab.get_single_data_value(prefab, font, "FONTDATA", "Thickness")

    # 将来用。1のところに倍率指定を置く
    thickness = thickness_raw * 1
    th_half = thickness / 2

    case form do
      "sol" ->
        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      _ ->
        skewer = draw_rectangle(-th_half, y0, th_half, y3 + bottom_gap)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, 0)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.concat_path(skewer)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}
    end
  end

  # そんなことはない場合
  def render_with_relative_height(
        %Prefab{} = _prefab,
        %Glyph{name: %{type: type}, height: %{y0: y0, y3: y3}, font: font, path: path} = self,
        top_gap,
        bottom_gap
      ) do
    path =
      SVG.Path.to_relative(path)
      |> SVG.Path.set_end_position(0, bottom_gap + y3)
      |> SVG.Path.set_start_position(0, top_gap)
      |> SVG.Path.to_relative()

    %Glyph{self | path: path}
  end

  # absoluteな高さにしたい場合の処理。
  # まずは音節の場合から
  def render_with_absolute_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          font: font,
          height: %{y0: y0, y1: y1, y2: y2, y3: y3},
          path: path
        } = self,
        height,
        vowel_height
      ) do
    thickness_raw = Prefab.get_single_data_value(prefab, font, "FONTDATA", "Thickness")

    # 将来用。1のところに倍率指定を置く
    thickness = thickness_raw * 1
    th_half = thickness / 2

    vowel_height_half = (y2 - y1) / 2
    glyph_height_half = (-y3 - y0) / 2

    case form do
      "sol" ->
        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, vowel_height - vowel_height_half)
          |> SVG.Path.toRelativeAll()

        %Glyph{self | path: path}

      "init" ->
        skewer = draw_rectangle(-th_half, y2, th_half, height)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, 0)
          |> SVG.Path.to_relative()
          |> concat_path(skewer)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      "mid" ->
        glyph_gap = vowel_height + glyph_height_half - vowel_height_half

        skewer_top = draw_rectangle(-th_half, 0, th_half, glyph_gap)
        skewer_bottom = draw_rectangle(-th_half, y2 + glyph_gap, th_half, height)

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, glyph_gap)
          |> SVG.Path.to_relative()
          |> concat_path(skewer_top)
          |> concat_path(skewer_bottom)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      "fin" ->
        skewer = draw_rectangle(-th_half, 0, th_half, height - (y3 - y1))

        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, height - (y3 - y1))
          |> SVG.Path.to_relative()
          |> concat_path(skewer)
          |> SVG.Path.to_relative()

        %Glyph{self | path: path}

      _ ->
        raise "fatal: invalid form found at render_with_absolute_height/4"
    end
  end

  # その他の場合。
  def render_with_absolute_height(
        %Prefab{} = prefab,
        %Glyph{font: font, height: %{y1: y1, y2: y2}, path: path} = self,
        height,
        vowel_height
      ) do
    thickness_raw = Prefab.get_single_data_value(prefab, font, "FONTDATA", "Thickness")
    glyph_height_half = (y2 - y1) / 2
    # 将来用。1のところに倍率指定を置く
    thickness = thickness_raw * 1
    th_half = thickness / 2

    path =
      SVG.Path.to_relative(path)
      |> SVG.Path.set_start_position(0, vowel_height - glyph_height_half)
      |> SVG.Path.to_relative()

    %Glyph{self | path: path}
  end
end
