defmodule Thaqqa.FontRegistryPrefab.GposTable.Query do
  alias Thaqqa.DataTable, as: DataTable

  alias Thaqqa.FontRegistryPrefab.GposTable, as: GposTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  def get_gpos!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_gpos(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_gpos(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case GposTable.get_gpos_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
