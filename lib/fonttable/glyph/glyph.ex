defmodule Thaqqa.FontRegistryPrefab.GlyphTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.FontRegistryPrefab.GlyphTable.Query, as: Query
  alias Thaqqa.FontRegistryPrefab.GlyphTable.Op, as: Op
  use Thaqqa.DataTable.Const

  def get_glyph_table!(%Prefab{} = prefab, fontname),
    do: Prefab.get_table(prefab, fontname, @glyph)

  def get_glyph_table(%Prefab{} = prefab, fontname) do
    case Prefab.get_table(prefab, fontname, @glyph) do
      nil -> Error.table_not_found(@glyph, fontname)
      table -> {:ok, table}
    end
  end

  def get_glyph!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_glyph!(prefab, fontname, filter_fun)

  def get_glyph(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_glyph(prefab, fontname, filter_fun)

  def add_glyph!(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_glyph!(prefab, fontname, value_map)

  def add_glyph(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_glyph(prefab, fontname, value_map)

  def delete_glyph!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_glyph!(prefab, fontname, data)

  def delete_glyph(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_glyph(prefab, fontname, data)

  def edit_glyph!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_glyph!(prefab, fontname, value_map, data)

  def edit_glyph(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_glyph(prefab, fontname, value_map, data)

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @glyph)

  def sort_glyph(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @glyph)
end
