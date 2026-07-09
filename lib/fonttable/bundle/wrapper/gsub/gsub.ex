defmodule Thaqqa.Bundle.GsubTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle.GsubTable.Op, as: Op
  alias Thaqqa.Bundle.GsubTable.Converter, as: Converter
  alias Thaqqa.Bundle.GsubTable.Query, as: Query

  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  def get_gsub_table!(%Bundle{} = prefab) do
    case get_gsub_table(prefab) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_gsub_table(%Bundle{} = prefab), do: Bundle.get_static_table_or_error(prefab, @gsub)

  def get_gsub!(%Bundle{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_gsub!(prefab, filter_fun)

  def get_gsub(%Bundle{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_gsub(prefab, filter_fun)

  def add_gsub!(%Bundle{} = prefab, value_map), do: Op.add_gsub!(prefab, value_map)

  def add_gsub(%Bundle{} = prefab, value_map), do: Op.add_gsub(prefab, value_map)

  def delete_gsub!(%Bundle{} = prefab, %Data{} = data), do: Op.delete_gsub!(prefab, data)

  def delete_gsub(%Bundle{} = prefab, %Data{} = data), do: Op.delete_gsub(prefab, data)

  def edit_gsub!(%Bundle{} = prefab, value_map, %Data{} = data),
    do: Op.edit_gsub!(prefab, value_map, data)

  def edit_gsub(%Bundle{} = prefab, value_map, %Data{} = data),
    do: Op.edit_gsub(prefab, value_map, data)

  def gsub!(%Bundle{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.gsub!(prefab, string, writing_direction)

  def gsub(%Bundle{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.gsub(prefab, string, writing_direction)

  def complement(%Bundle{} = prefab), do: Bundle.complement_by_static_table(prefab, @gsub)
  def sort_gsub(%Bundle{} = prefab), do: Bundle.sort_as_static_if_enable(prefab, @gsub)
end
