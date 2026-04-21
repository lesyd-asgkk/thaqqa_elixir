defmodule Thaqqa.FontRegistryPrefab.GposTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.GposTable, as: GposTable
  use Thaqqa.DataTable.Const

  def add_gpos!(%Prefab{} = prefab, fontname, value_map) do
    case add_gpos(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_gpos(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, GposTable.sort_gpos(new_prefab, fontname)}
    else
      nil -> Error.font_not_found(fontname)
      {:error, _} = err -> err
    end
  end

  def delete_gpos!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_gpos(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_gpos(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname) do
      Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table))
    else
      {:error, _} = err -> err
    end
  end

  def edit_gpos!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_gpos(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_gpos(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, GposTable.sort_gpos(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end
end
