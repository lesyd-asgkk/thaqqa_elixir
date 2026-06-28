defmodule Thaqqa.Bundle.GposTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.GposTable, as: GposTable
  use Thaqqa.DataTable.Const

  def add_gpos!(%Bundle{} = prefab, fontname, value_map) do
    case add_gpos(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_gpos(%Bundle{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Bundle.get_font_or_error(prefab, fontname),
         {:ok, %Bundle{} = new_prefab} <-
           Bundle.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, GposTable.sort_gpos(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_gpos!(%Bundle{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_gpos(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_gpos(%Bundle{} = prefab, fontname, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         {:ok, %Font{} = font} <- Bundle.get_font_or_error(prefab, fontname) do
      Bundle.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table))
    else
      {:error, _} = err -> err
    end
  end

  def edit_gpos!(%Bundle{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_gpos(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_gpos(%Bundle{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- GposTable.get_gpos_table(prefab, fontname),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Font{} = font} <- Bundle.get_font_or_error(prefab, fontname),
         {:ok, %Bundle{} = new_prefab} <-
           Bundle.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, GposTable.sort_gpos(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end
end
