# font設定etcは必要ないと判断。

defmodule Thaqqa.Glyph do
  alias SVG.Path, as: Path
  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  defstruct offset: %{x: 0, y: 0},
            height: %{y0: 0, y1: 0, y2: 0, y3: 0},
            glyph_height: 0,
            aligment: %{x: 0, y: 0},
            children_glyph_list: [],
            name: %{glyph: "", variant: "", type: "", form: ""},
            font: "",
            path: Path.parse_string!("m0,0") |> Path.new(),
            path_raw: Path.parse_string!("m0,0") |> Path.new(),
            scale: nil,
            attribution: %{
              line: %{
                fill: "#000000",
                stroke_width: 0,
                stroke: "#000000",
                dash: 0,
                stroke_dasharray: 1
              },
              layer: 0,
              transform: %{scale: 1, x: 0, y: 0, rotate: 0}
            },
            internal_attribution: %{
              is_null: false,
              gap_top: 0,
              gap_center: 0,
              is_wordbreaker: false,
              is_newline: false
            }

  # attributionは今後の拡張機能を想定して設けた。
  # height: %{y0:頭,y1:母音の頭,y2:母音の尾,y3:尾}
  # ただしそのglyphの構成として母音が存在しない場合、y1:=y0,y2:=y3
  # internal_attributionは内部処理で保持しておくと楽な値の一覧。
  # path_raw(下位グリフの構成要素を含まないpathデータ)も予約済
  # （色変化対応ver用）

  def new(%Bundle{} = prefab, font, glyphname, writing_direction, default_size),
    do: Thaqqa.Glyph.GlyphSpawner.new(prefab, font, glyphname, writing_direction, default_size)

  def set_path(%__MODULE__{} = self), do: Thaqqa.Glyph.GlyphBuilder.set_path(self)

  def render_by_relative_height(%Bundle{} = prefab, %__MODULE__{} = self, top_gap, bottom_gap),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_relative_height(prefab, self, top_gap, bottom_gap)

  def render_by_absolute_height(%Bundle{} = prefab, %__MODULE__{} = self, height, vowel_height),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_absolute_height(prefab, self, height, vowel_height)
end
