defmodule Thaqqa.Glyph.GlyphBuilder do
  import SVG.Path
  alias Thaqqa.Glyph, as: Glyph

  # Sの場合の設定
  def set_path(
        %Glyph{name: %{type: "S"}, children_glyph_list: children, path: path, scale: scale} = self
      ) do
    %{top: tv, bottom: bv} = Enum.at(children, 1).path |> SVG.Path.get_border()

    [onset_glyph, vowel_glyph, coda_glyph] =
      Enum.map(children, fn k -> set_path(k) end)

    [off_onset, off_coda] = calc_offset(onset_glyph, vowel_glyph, coda_glyph)

    path_new =
      SVG.Path.merge_path_3(
        vowel_glyph.path,
        onset_glyph.path,
        coda_glyph.path,
        0,
        off_onset.y,
        0,
        off_coda.y
      )

    %{top: t, bottom: b} = SVG.Path.get_border(path_new)
    height = %{y0: t, y1: tv, y2: bv, y3: b}
    %Glyph{self | height: height, path: path_new}
  end

  # S以外の時の設定(再帰処理)
  def set_path(
        %Glyph{name: %{type: type}, children_glyph_list: [], path: path, scale: scale} = self
      )
      when type != "S" do
    %{left: _, top: t, right: _, bottom: b} = SVG.Path.get_border(path)
    %Glyph{self | height: %{y0: t, y1: t, y2: b, y3: b}}
  end

  def set_path(
        %Glyph{
          name: %{type: type, form: form},
          children_glyph_list: children,
          path: top_path,
          scale: scale
        } = self
      ) do
    top_glyph = %Glyph{self | children_glyph_list: []} |> set_path()
    child = Enum.at(children, 0)
    sub_glyph = child |> set_path()

    dir = if type in ["C", "Cd"] and form == "coda", do: -1, else: 1
    off = calc_offset(top_glyph, sub_glyph)
    child_path = child.path
    %{left: l, top: t, right: r, bottom: b} = SVG.Path.get_border(child_path)

    off_child_x = dir * (r + l) / 2
    off_child_y = -(t + b) / 2

    path_new =
      merge_path_2(
        top_path,
        child_path,
        off_child_x + off.x,
        off_child_y + off.y
      )
      |> to_relative()

    %{left: _, top: t, right: _, bottom: b} = SVG.Path.get_border(path_new)
    %Glyph{self | height: %{y0: t, y1: t, y2: b, y3: b}, path: path_new}
  end

  # 無の場合。そのまま初期値のm0,0が帰ります
  def set_path(%Glyph{name: %{glyph: "", variant: "", type: "", form: ""}} = self), do: self

  #

  defp calc_offset(
         %Glyph{name: %{type: type, form: form}, path: top_path, scale: _top_scale} = top_glyph,
         %Glyph{offset: sub_offset, aligment: sub_aligment, scale: sub_scale} = sub_glyph
       ) do
    %{left: l, top: t, right: r, bottom: b} = SVG.Path.get_border(top_path)
    sub_offset = %{x: sub_offset.x * sub_scale, y: sub_offset.y * sub_scale}

    if type in ["C", "Cd"] do
      dir = if form == "coda", do: -1, else: 1

      # C,Cdの場合のx値補正（0:「グリフの」中央、1:グリフの外側、-1:グリフの内側(母音側) ）
      %{
        x:
          l * (1 - sub_aligment.x * dir) / 2 + r * (1 + sub_aligment.x * dir) / 2 +
            sub_offset.x * dir,
        y: t * (1 - sub_aligment.y) / 2 + b * (1 + sub_aligment.y) / 2 + sub_offset.y
      }
    else
      # V,Vd,P,Pdの場合のx値補正（0:中央、1:母音の左側、-1:母音の右側　
      # これについては不適切な演算式の可能性がある。検証した上で値を変えて全て上へと変えることも検討。
      # （Vd,Pdは使用頻度が少ないので早急に対処する必要性はない）
      %{
        x: l * sub_aligment.x / 2 + r * -sub_aligment.x / 2 + sub_offset.x,
        y: t * (1 - sub_aligment.y) / 2 + b * (1 + sub_aligment.y) / 2 + sub_offset.y
      }
    end
  end

  defp calc_offset(
         %Glyph{offset: onset_offset, path: onset_path, scale: onset_scale},
         %Glyph{internal_attribution: %{is_null: true}, path: vowel_path},
         %Glyph{offset: coda_offset, path: coda_path, scale: coda_scale}
       ) do
    %{top: t_onset, bottom: b_onset} = SVG.Path.get_border(onset_path)
    %{top: t_coda, bottom: b_coda} = SVG.Path.get_border(coda_path)
    %{bottom: b_vowel} = SVG.Path.get_border(vowel_path)

    onset_offset = %{x: onset_offset.x * onset_scale, y: onset_offset.y * onset_scale}
    coda_offset = %{x: coda_offset.x * coda_scale, y: coda_offset.y * coda_scale}

    topgap = min(t_onset, t_coda)
    bottomgap = max(b_onset, b_coda)

    [
      %{x: onset_offset.x, y: b_vowel + topgap - bottomgap + onset_offset.y},
      %{x: coda_offset.x, y: b_vowel + topgap - bottomgap + coda_offset.y}
    ]
  end

  defp calc_offset(
         %Glyph{offset: onset_offset, path: onset_path, scale: onset_scale},
         %Glyph{internal_attribution: %{is_null: false}, name: %{form: form}, path: vowel_path},
         %Glyph{offset: coda_offset, path: coda_path, scale: coda_scale}
       ) do
    %{top: t_onset, bottom: b_onset} = SVG.Path.get_border(onset_path)
    %{top: t_coda, bottom: b_coda} = SVG.Path.get_border(coda_path)
    %{top: t_vowel, bottom: b_vowel} = SVG.Path.get_border(vowel_path)

    topgap = min(t_onset, t_coda)
    bottomgap = max(b_onset, b_coda)

    onset_offset = %{x: onset_offset.x * onset_scale, y: onset_offset.y * onset_scale}
    coda_offset = %{x: coda_offset.x * coda_scale, y: coda_offset.y * coda_scale}

    case form do
      "init" ->
        [
          %{x: onset_offset.x, y: b_vowel + topgap + onset_offset.y},
          %{x: coda_offset.x, y: b_vowel + topgap + coda_offset.y}
        ]

      _mid when _mid in ["sol", "mid"] ->
        [
          %{x: onset_offset.x, y: t_vowel - b_onset + onset_offset.y},
          %{x: coda_offset.x, y: b_vowel + t_coda + coda_offset.y}
        ]

      "fin" ->
        [
          %{x: onset_offset.x, y: t_vowel - bottomgap + onset_offset.y},
          %{x: coda_offset.x, y: t_vowel - bottomgap + coda_offset.y}
        ]
    end
  end
end
