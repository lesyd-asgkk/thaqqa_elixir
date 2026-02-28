# font設定etcは必要ないと判断。

defmodule Thaqqa.Glyph do
  import SVG.Path
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.GlyphManager, as: GlyphManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.LetterManager, as: LetterManager
  use Thaqqa.DataTable.Const

  defstruct offset: %{x: 0, y: 0},
            height: %{y0: 0, y1: 0, y2: 0, y3: 0},
            glyph_height: 0,
            aligment: %{x: 0, y: 0},
            children_glyph_list: [],
            name: %{glyph: "", variant: "", type: "", form: ""},
            font: "",
            path: SVG.Path.parse_string!("m0,0"),
            attribution: %{},
            internal_attribution: %{is_null: false}

  # attributionは今後の拡張機能を想定して設けた。
  # height: %{y0:頭,y1:母音の頭,y2:母音の尾,y3:尾}
  # ただしそのglyphの構成として母音が存在しない場合、y1:=y0,y2:=y3
  # internal_attributionは内部処理で保持しておくと楽な値の一覧。

  def new(%Prefab{} = prefab, font, glyphname, writing_direction),
    do: Thaqqa.Glyph.GlyphSpawner.new(prefab, font, glyphname, writing_direction)

  def set_path(%__MODULE__{} = self), do: Thaqqa.Glyph.GlyphBuilder.set_path(self)

  def render_by_relative_height(%Prefab{} = prefab, %Glyph{} = self, top_gap, bottom_gap),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_relative_height(prefab, self, top_gap, bottom_gap)

  def render_by_absolute_height(%Prefab{} = prefab, %Glyph{} = self, height, vowel_height),
    do: Thaqqa.Glyph.GlyphRenderer.render_by_absolute_height(prefab, self, height, vowel_height)
end
