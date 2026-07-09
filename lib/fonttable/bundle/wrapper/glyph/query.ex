defmodule Thaqqa.Bundle.GlyphTable.Query do
  alias Thaqqa.DataTable, as: DataTable

  alias Thaqqa.Bundle.GlyphTable, as: GlyphTable
  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  def get_glyph!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_glyph(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_glyph(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case GlyphTable.get_glyph_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end
end
