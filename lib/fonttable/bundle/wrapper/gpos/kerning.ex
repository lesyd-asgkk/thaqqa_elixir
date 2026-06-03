defmodule Thaqqa.Bundle.GposTable.Kerning do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.GposTable, as: GposTable
  use Thaqqa.DataTable.Const

  def gpos!(%Bundle{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] do
    case gpos(prefab, fontname, string, writing_direction, gpos_type) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def gpos(%Bundle{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list do
    GposTable.get_gpos(prefab, fontname, fn %Data{} = data ->
      Data.get_value(data, @writing_direction) in [writing_direction, @universal_language] and
        Data.get_value(data, @gpos_type) == gpos_type
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, gpos_data_list} ->
        {:ok,
         Enum.reduce(gpos_data_list, %{x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0}, fn gpos_data, acc ->
           reg = Data.get_value(gpos_data, @precompile)
           x0 = Data.get_value(gpos_data, "OffsetX0")
           x1 = Data.get_value(gpos_data, "OffsetX1")
           y0 = Data.get_value(gpos_data, "OffsetY0")
           y1 = Data.get_value(gpos_data, "OffsetY1")

           if Regex.match?(reg, string),
             do: %{x0: acc.x0 + x0, y0: acc.y0 + y0, x1: acc.x1 + x1, y1: acc.y1 + y1},
             else: acc
         end)}
    end
  end
end
