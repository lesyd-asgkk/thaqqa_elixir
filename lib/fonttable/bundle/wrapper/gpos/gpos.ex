defmodule Thaqqa.Bundle.GposTable do
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.GposTable.Op, as: Op
  alias Thaqqa.Bundle.GposTable.Query, as: Query
  alias Thaqqa.Bundle.GposTable.Kerning, as: Kerning
  use Thaqqa.DataTable.Const

  def get_gpos_table!(%Bundle{} = prefab, fontname) do
    case get_gpos_table(prefab, fontname) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_gpos_table(%Bundle{} = prefab, fontname),
    do: Bundle.get_table_or_error(prefab, fontname, @gpos)

  def get_gpos!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_gpos!(prefab, fontname, filter_fun)

  def get_gpos(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_gpos(prefab, fontname, filter_fun)

  def add_gpos!(%Bundle{} = prefab, fontname, value_map),
    do: Op.add_gpos!(prefab, fontname, value_map)

  def add_gpos(%Bundle{} = prefab, fontname, value_map),
    do: Op.add_gpos(prefab, fontname, value_map)

  def delete_gpos!(%Bundle{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_gpos!(prefab, fontname, data)

  def delete_gpos(%Bundle{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_gpos(prefab, fontname, data)

  def edit_gpos!(%Bundle{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_gpos!(prefab, fontname, value_map, data)

  def edit_gpos(%Bundle{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_gpos(prefab, fontname, value_map, data)

  def gpos!(%Bundle{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal],
      do: Kerning.gpos!(prefab, fontname, string, writing_direction, gpos_type)

  # todo with文-化
  def gpos(%Bundle{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list,
      do: Kerning.gpos(prefab, fontname, string, writing_direction, gpos_type)

  def complement(%Bundle{} = prefab, fontname),
    do: Bundle.complement_table(prefab, fontname, @gpos)

  def sort_gpos(%Bundle{} = prefab, fontname),
    do: Bundle.sort_as_font_table_if_enable(prefab, fontname, @gpos)
end
