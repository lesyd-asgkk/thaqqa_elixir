defmodule Thaqqa.Bundle.GposTable.Query do
  alias Thaqqa.DataTable, as: DataTable

  alias Thaqqa.Bundle.GposTable, as: GposTable
  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  def get_gpos!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_gpos(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_gpos(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case GposTable.get_gpos_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
