# font設定etcは必要ないと判断。

defmodule Thaqqa.Glyph do
  alias SVG.Path, as: Path
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  defstruct offset: %{x: 0, y: 0},
            height: %{y0: 0, y1: 0, y2: 0, y3: 0},
            glyph_height: 0,
            aligment: %{x: 0, y: 0},
            children_glyph_list: [],
            name: %{glyph: "", variant: "", type: "", form: ""},
            font: "",
            path: Path.parse_string!("m0,0") |> Path.new(),
            scale: nil,
            attribution: %{},
            internal_attribution: %{
              is_null: false,
              gap_top: 0,
              gap_center: 0,
              is_space: false,
              is_newline: true
            }

  # attributionは今後の拡張機能を想定して設けた。
  # height: %{y0:頭,y1:母音の頭,y2:母音の尾,y3:尾}
  # ただしそのglyphの構成として母音が存在しない場合、y1:=y0,y2:=y3
  # internal_attributionは内部処理で保持しておくと楽な値の一覧。

  def new(%Prefab{} = prefab, font, glyphname, writing_direction, default_size),
    do: Thaqqa.Glyph.GlyphSpawner.new(prefab, font, glyphname, writing_direction, default_size)

  def set_path(%__MODULE__{} = self), do: Thaqqa.Glyph.GlyphBuilder.set_path(self)

  def render_by_relative_height(%Prefab{} = prefab, %__MODULE__{} = self, top_gap, bottom_gap),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_relative_height(prefab, self, top_gap, bottom_gap)

  def render_by_absolute_height(%Prefab{} = prefab, %__MODULE__{} = self, height, vowel_height),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_absolute_height(prefab, self, height, vowel_height)
end
