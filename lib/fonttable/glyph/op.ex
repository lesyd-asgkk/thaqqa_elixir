defmodule Thaqqa.FontRegistryPrefab.GlyphTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.GlyphTable, as: GlyphTable
  use Thaqqa.DataTable.Const

  def add_glyph!(%Prefab{} = prefab, fontname, value_map) do
    case add_glyph(%Prefab{} = prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_glyph(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- GlyphTable.get_glyph_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, GlyphTable.sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_glyph!(%Prefab{} = prefab, fontname, %Data{} = data) do
    case delete_glyph(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_glyph(%Prefab{} = prefab, fontname, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GlyphTable.get_glyph_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, GlyphTable.sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def edit_glyph!(%Prefab{} = prefab, fontname, value_map, %Data{} = data) do
    case edit_glyph(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_glyph(%Prefab{} = prefab, fontname, value_map, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GlyphTable.get_glyph_table(prefab, fontname),
         {:ok, %Data{} = _new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, value_map),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, GlyphTable.sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end
end
