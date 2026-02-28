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

defmodule Thaqqa.SvgRenderer do
  import SVG.Path
  alias Thaqqa.GlyphList, as: GlyphList
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.GlyphManager, as: GlyphManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.LetterManager, as: LetterManager
  use Thaqqa.DataTable.Const
end
