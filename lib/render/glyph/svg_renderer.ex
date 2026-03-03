defmodule Thaqqa.GlyphList do
  defstruct position: %{x: 0, y: 0},
            aligment: %{x: 0, y: 0},
            glyph_list: [],
            name: %{glyph: "", variant: "", type: "", form: ""},
            font: "",
            path: SVG.Path.parse_string!("m0,0"),
            attribution: %{},
            internal_attribution: %{writing_direction: "horizontal_left"}
end

# 合成方針
# horizontal、veritcal共に「3文字づつkerning用の値の処理」
# ダミーデータとして「None()」に該当するGlyphを前後に挿入。
# glyphs = glyphs ++ [None()]
# glyphs = [ None() | glyphs]
# |> Stream.chunk_every(3, 1, :discard)
# |> Stream.map(&calc_kerning/1)
# のような形。

#
#
#
#
#

defmodule Thaqqa.SvgRenderer do
  import SVG.Path
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.GlyphList, as: GlyphList
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.GlyphManager, as: GlyphManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.LetterManager, as: LetterManager
  use Thaqqa.DataTable.Const

  # None()に該当するダミーデータ
  defp build_none(font) do
    %Glyph{
      offset: %{x: 0, y: 0},
      aligment: %{x: 0, y: 0},
      path: %SVG.Path{},
      children_glyph_list: [],
      font: font,
      name: %{glyph: "", variant: nil, type: "None", form: nil},
      # ↓ここでは設定しない
      height: %{y0: 0, y1: 0, y2: 0, y3: 0}
    }
  end
end
