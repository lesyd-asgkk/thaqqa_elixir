defmodule Thaqqa.FontRegistryPrefab.GlyphTable.Query do
  alias Thaqqa.DataTable, as: DataTable

  alias Thaqqa.FontRegistryPrefab.GlyphTable, as: GlyphTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  def get_glyph!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_glyph(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_glyph(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case GlyphTable.get_glyph_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
