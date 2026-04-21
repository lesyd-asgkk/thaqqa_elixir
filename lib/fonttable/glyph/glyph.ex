defmodule Thaqqa.FontRegistryPrefab.GlyphTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_glyph_table!(%Prefab{} = prefab, fontname),
    do: Prefab.get_table(prefab, fontname, @glyph)

  def get_glyph_table(%Prefab{} = prefab, fontname) do
    case Prefab.get_table(prefab, fontname, @glyph) do
      nil -> Error.table_not_found(@glyph, fontname)
      table -> {:ok, table}
    end
  end

  def get_glyph!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_glyph(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_glyph(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_glyph_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_glyph!(%Prefab{} = prefab, fontname, value_map) do
    case add_glyph(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_glyph(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- get_glyph_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_glyph!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_glyph(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_glyph(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_glyph_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def edit_glyph!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_glyph(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_glyph(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_glyph_table(prefab, fontname),
         {:ok, %Data{} = _new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, value_map),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @glyph, table)) do
      {:ok, sort_glyph(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @glyph)

  def sort_glyph(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @glyph)
end
