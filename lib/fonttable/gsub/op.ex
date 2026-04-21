defmodule Thaqqa.FontRegistryPrefab.GsubTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.GsubTable, as: GsubTable
  use Thaqqa.DataTable.Const

  def add_gsub!(%Prefab{} = prefab, value_map) do
    case add_gsub(prefab, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_gsub(%Prefab{} = prefab, value_map) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @gsub, table) do
      {:ok, GsubTable.sort_gsub(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_gsub!(%Prefab{} = prefab, %Data{} = data) do
    case delete_gsub(prefab, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_gsub(%Prefab{} = prefab, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Prefab.edit_static_table(prefab, @gsub, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_gsub!(%Prefab{} = prefab, value_map, %Data{} = data) do
    case edit_gsub(prefab, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_gsub(%Prefab{} = prefab, value_map, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- GsubTable.get_gsub_table(prefab),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @gsub, table) do
      {:ok, GsubTable.sort_gsub(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end
end
