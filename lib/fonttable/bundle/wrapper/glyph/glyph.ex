defmodule Thaqqa.Bundle.GlyphTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.GlyphTable.Query, as: Query
  alias Thaqqa.Bundle.GlyphTable.Op, as: Op
  use Thaqqa.DataTable.Const

  def get_glyph_table!(%Bundle{} = prefab, fontname) do
    case get_glyph_table(prefab, fontname) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_glyph_table(%Bundle{} = prefab, fontname),
    do: Bundle.get_table_or_error(prefab, fontname, @glyph)

  def get_glyph!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end)
      when is_binary(fontname) and is_function(filter_fun),
      do: Query.get_glyph!(prefab, fontname, filter_fun)

  def get_glyph(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end)
      when is_binary(fontname) and is_function(filter_fun),
      do: Query.get_glyph(prefab, fontname, filter_fun)

  def add_glyph!(%Bundle{} = prefab, fontname, value_map)
      when is_binary(fontname) and is_map(value_map),
      do: Op.add_glyph!(prefab, fontname, value_map)

  def add_glyph(%Bundle{} = prefab, fontname, value_map)
      when is_binary(fontname) and is_map(value_map),
      do: Op.add_glyph(prefab, fontname, value_map)

  def delete_glyph!(%Bundle{} = prefab, fontname, %Data{} = data) when is_binary(fontname),
    do: Op.delete_glyph!(prefab, fontname, data)

  def delete_glyph(%Bundle{} = prefab, fontname, %Data{} = data) when is_binary(fontname),
    do: Op.delete_glyph(prefab, fontname, data)

  def edit_glyph!(%Bundle{} = prefab, fontname, value_map, %Data{} = data)
      when is_binary(fontname) and is_map(value_map),
      do: Op.edit_glyph!(prefab, fontname, value_map, data)

  def edit_glyph(%Bundle{} = prefab, fontname, value_map, %Data{} = data)
      when is_binary(fontname) and is_map(value_map),
      do: Op.edit_glyph(prefab, fontname, value_map, data)

  def complement(%Bundle{} = prefab, fontname) when is_binary(fontname),
    do: Bundle.complement_table(prefab, fontname, @glyph)

  def sort_glyph(%Bundle{} = prefab, fontname) when is_binary(fontname),
    do: Bundle.sort_as_font_table_if_enable(prefab, fontname, @glyph)
end
