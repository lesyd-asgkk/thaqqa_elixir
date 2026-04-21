defmodule Thaqqa.FontRegistryPrefab.ParserTable.Query do
  alias Thaqqa.FontRegistryPrefab.ParserTable, as: ParserTable
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  def get_parser!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_parser(prefab, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_parser(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case ParserTable.get_parser_table(prefab) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
