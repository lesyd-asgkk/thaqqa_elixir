defmodule Thaqqa.FontRegistryPrefab.ParserTable.Op do
  alias Thaqqa.FontRegistryPrefab.ParserTable, as: ParserTable
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def add_parser!(%Prefab{} = prefab, value_map) do
    case add_parser(prefab, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_parser(%Prefab{} = prefab, value_map) do
    with {:ok, %DataTable{} = table} <- ParserTable.get_parser_table(prefab),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @parser, table) do
      {:ok, ParserTable.sort_parser(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_parser!(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    case delete_parser(prefab, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_parser(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- ParserTable.get_parser_table(prefab),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Prefab.edit_static_table(prefab, @parser, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_parser!(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    case edit_parser(prefab, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_parser(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- ParserTable.get_parser_table(prefab),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @parser, table) do
      {:ok, ParserTable.sort_parser(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end
end
