defmodule Thaqqa.Bundle.GsubTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.GsubTable, as: GsubTable
  use Thaqqa.DataTable.Const

  def add_gsub!(%Bundle{} = prefab, value_map) do
    case add_gsub(prefab, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_gsub(%Bundle{} = prefab, value_map) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Bundle{} = new_prefab} <- Bundle.edit_static_table(prefab, @gsub, table) do
      {:ok, GsubTable.sort_gsub(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_gsub!(%Bundle{} = prefab, %Data{} = data) do
    case delete_gsub(prefab, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_gsub(%Bundle{} = prefab, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Bundle.edit_static_table(prefab, @gsub, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_gsub!(%Bundle{} = prefab, value_map, %Data{} = data) do
    case edit_gsub(prefab, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_gsub(%Bundle{} = prefab, value_map, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Bundle{} = new_prefab} <- Bundle.edit_static_table(prefab, @gsub, table) do
      {:ok, GsubTable.sort_gsub(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end
end
