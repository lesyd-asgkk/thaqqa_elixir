defmodule Thaqqa.FontRegistryPrefab.GposTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.GposTable.Op, as: Op
  alias Thaqqa.FontRegistryPrefab.GposTable.Query, as: Query
  alias Thaqqa.FontRegistryPrefab.GposTable.Kerning, as: Kerning
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_gpos_table!(%Prefab{} = prefab, fontname),
    do: Prefab.get_table(prefab, fontname, @gpos)

  def get_gpos_table(%Prefab{} = prefab, fontname) do
    case Prefab.get_table(prefab, fontname, @gpos) do
      nil -> Error.table_not_found(@gpos, fontname)
      table -> {:ok, table}
    end
  end

  def get_gpos!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_gpos!(prefab, fontname, filter_fun)

  def get_gpos(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_gpos(prefab, fontname, filter_fun)

  def add_gpos!(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_gpos!(prefab, fontname, value_map)

  def add_gpos(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_gpos(prefab, fontname, value_map)

  def delete_gpos!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_gpos!(prefab, fontname, data)

  def delete_gpos(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data),
    do: Op.delete_gpos(prefab, fontname, data)

  def edit_gpos!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_gpos!(prefab, fontname, value_map, data)

  def edit_gpos(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data),
    do: Op.edit_gpos(prefab, fontname, value_map, data)

  def gpos!(%Prefab{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal],
      do: Kerning.gpos!(prefab, fontname, string, writing_direction, gpos_type)

  # todo with文-化
  def gpos(%Prefab{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list,
      do: Kerning.gpos(prefab, fontname, string, writing_direction, gpos_type)

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @gpos)

  def sort_gpos(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @gpos)
end
