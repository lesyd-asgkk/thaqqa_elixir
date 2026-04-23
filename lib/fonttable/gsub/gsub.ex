defmodule Thaqqa.FontRegistryPrefab.GsubTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistryPrefab.GsubTable.Op, as: Op
  alias Thaqqa.FontRegistryPrefab.GsubTable.Converter, as: Converter
  alias Thaqqa.FontRegistryPrefab.GsubTable.Query, as: Query

  alias Thaqqa.FontRegistryPrefab, as: Prefab
  use Thaqqa.DataTable.Const

  def get_gsub_table!(%Prefab{} = prefab) do
    case get_gsub_table(prefab) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_gsub_table(%Prefab{} = prefab), do: Prefab.get_static_table_or_error(prefab, @gsub)

  def get_gsub!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_gsub!(prefab, filter_fun)

  def get_gsub(%Prefab{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_gsub(prefab, filter_fun)

  def add_gsub!(%Prefab{} = prefab, value_map), do: Op.add_gsub!(prefab, value_map)

  def add_gsub(%Prefab{} = prefab, value_map), do: Op.add_gsub(prefab, value_map)

  def delete_gsub!(%Prefab{} = prefab, %Data{} = data), do: Op.delete_gsub!(prefab, data)

  def delete_gsub(%Prefab{} = prefab, %Data{} = data), do: Op.delete_gsub(prefab, data)

  def edit_gsub!(%Prefab{} = prefab, value_map, %Data{} = data),
    do: Op.edit_gsub!(prefab, value_map, data)

  def edit_gsub(%Prefab{} = prefab, value_map, %Data{} = data),
    do: Op.edit_gsub(prefab, value_map, data)

  def gsub!(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.gsub!(prefab, string, writing_direction)

  def gsub(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.gsub(prefab, string, writing_direction)

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @gsub)
  def sort_gsub(%Prefab{} = prefab), do: Prefab.sort_as_static_if_enable(prefab, @gsub)
end
