defmodule Thaqqa.Glyph.GlyphRenderer do
  import SVG.Path
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.Render.Error, as: Error

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

  def render_by_relative_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          height: %{y0: y0, y1: y1, y2: y2, y3: y3},
          font: fontname,
          internal_attribution: %{is_null: false},
          path: path,
          scale: scale
        } = self,
        top_gap,
        bottom_gap
      ) do
    case Prefab.get_fontdata(prefab, fontname, ["Thickness"]) do
      {:ok, %{Thickness: thickness_raw}} ->
        # 将来用。1のところに倍率指定を置く
        thickness = thickness_raw * scale
        th_half = thickness / 2

        case form do
          k when k in ["sol", ""] ->
            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: top_gap + bottom_gap + y3}}

          "init" ->
            skewer = draw_rectangle(-th_half, top_gap + y2, th_half, top_gap + bottom_gap + y3)

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.to_relative()
              |> concat_path(skewer)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: top_gap + bottom_gap + y3}}

          "mid" ->
            skewer_top = draw_rectangle(-th_half, y0, th_half, y1 + top_gap)

            skewer_bottom =
              draw_rectangle(-th_half, top_gap + y2, th_half, top_gap + bottom_gap + y3)

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.to_relative()
              |> concat_path(skewer_top)
              |> concat_path(skewer_bottom)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: top_gap + bottom_gap + y3}}

          "fin" ->
            skewer = draw_rectangle(-th_half, y0, th_half, top_gap + y1)

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.to_relative()
              |> concat_path(skewer)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: top_gap + bottom_gap + y3}}

          _ ->
            Error.invalid_form(form)
        end

      {:error, _} = err ->
        err
    end
  end

  def render_by_relative_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          height: %{y0: y0, y3: y3},
          font: fontname,
          internal_attribution: %{is_null: true},
          path: path,
          scale: scale
        } = self,
        top_gap,
        bottom_gap
      ) do
    # 下からどれだけ、という値なのを、上からどれだけ、に換算する。

    case Prefab.get_fontdata(prefab, fontname, ["Thickness"]) do
      {:ok, %{Thickness: thickness_raw}} ->
        # 将来用。1のところに倍率指定を置く
        thickness = thickness_raw * scale
        th_half = thickness / 2

        case form do
          k when k in ["sol", ""] ->
            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path}}

          k when k in ["init", "mid", "fin"] ->
            skewer = draw_rectangle(-th_half, y0, th_half, top_gap + y3 + bottom_gap)

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, top_gap)
              |> SVG.Path.set_end_position(0, bottom_gap + y3)
              |> SVG.Path.concat_path(skewer)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: bottom_gap + y3}}

          _ ->
            Error.invalid_form(form)
        end

      {:error, _} = err ->
        err
    end
  end

  # そんなことはない場合
  def render_by_relative_height(
        %Prefab{} = _prefab,
        %Glyph{name: %{form: form}, height: %{y0: _y0, y3: y3}, path: path, scale: _scale} = self,
        top_gap,
        bottom_gap
      ) do
    case form do
      k when k in ["init", "mid", "fin", "onset", "coda", "sol", ""] ->
        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_end_position(0, bottom_gap + y3)
          |> SVG.Path.set_start_position(0, top_gap)
          |> SVG.Path.to_relative()

        {:ok, %Glyph{self | path: path, glyph_height: bottom_gap + y3}}

      _ ->
        Error.invalid_form(form)
    end
  end

  # absoluteな高さにしたい場合の処理。
  # まずは音節の場合から
  def render_by_absolute_height(
        %Prefab{} = prefab,
        %Glyph{
          name: %{type: "S", form: form},
          font: fontname,
          height: %{y0: y0, y1: y1, y2: y2, y3: y3},
          path: path,
          scale: scale
        } = self,
        height,
        vowel_height
      ) do
    case Prefab.get_fontdata(prefab, fontname, ["Thickness"]) do
      {:ok, %{Thickness: thickness_raw}} ->
        # 将来用。1のところに倍率指定を置く
        thickness = thickness_raw * scale
        th_half = thickness / 2

        vowel_height_half = (y2 - y1) / 2
        glyph_height_half = (-y3 - y0) / 2

        # TODO: 文字幅がheightを超えてしまった場合の処理を追加。
        case form do
          k when k in ["sol", ""] ->
            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, vowel_height - vowel_height_half)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: height}}

          "init" ->
            skewer = draw_rectangle(-th_half, y2, th_half, height)

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, 0)
              |> SVG.Path.to_relative()
              |> concat_path(skewer)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: height}}

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

            {:ok, %Glyph{self | path: path, glyph_height: height}}

          "fin" ->
            skewer = draw_rectangle(-th_half, 0, th_half, height - (y3 - y1))

            path =
              SVG.Path.to_relative(path)
              |> SVG.Path.set_start_position(0, height - (y3 - y1))
              |> SVG.Path.to_relative()
              |> concat_path(skewer)
              |> SVG.Path.to_relative()

            {:ok, %Glyph{self | path: path, glyph_height: height}}

          _ ->
            Error.invalid_form(form)
        end

      {:error, _} = err ->
        err
    end
  end

  # その他の場合。
  def render_by_absolute_height(
        %Prefab{} = prefab,
        %Glyph{
          font: fontname,
          name: %{form: form},
          height: %{y1: y1, y2: y2},
          path: path,
          scale: _scale
        } =
          self,
        height,
        vowel_height
      ) do
    case form do
      k when k in ["init", "mid", "fin", "onset", "coda", "sol", ""] ->
        glyph_height_half = (y2 - y1) / 2
        # 将来用。1のところに倍率指定を置く
        path =
          SVG.Path.to_relative(path)
          |> SVG.Path.set_start_position(0, vowel_height - glyph_height_half)
          |> SVG.Path.to_relative()

        {:ok, %Glyph{self | path: path, glyph_height: height}}

      _ ->
        Error.invalid_form(form)
    end
  end
end
