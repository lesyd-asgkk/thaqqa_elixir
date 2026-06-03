defmodule Thaqqa.Bundle.UniqueGsubTable.Query do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.UniqueGsubTable, as: UniqueGsubTable
  use Thaqqa.DataTable.Const

  def get_unique_gsub!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_unique_gsub(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_unique_gsub(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case UniqueGsubTable.get_unique_gsub_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
