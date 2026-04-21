defmodule Thaqqa.FontRegistryPrefab.GsubTable.Query do
  alias Thaqqa.DataTable, as: DataTable

  alias Thaqqa.FontRegistryPrefab.GsubTable, as: GsubTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  def get_gsub!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_gsub(prefab, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_gsub(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case GsubTable.get_gsub_table(prefab) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
