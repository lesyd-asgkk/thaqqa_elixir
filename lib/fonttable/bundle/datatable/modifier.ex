defmodule Thaqqa.DataTable.DataMapModifier do
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable
  use Thaqqa.DataTable.Const

  # IDをくっつけるサブルーチン。
  def attach_id(value_map, %DataTable{} = table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, DataTable.get_least_available_id(table))
  end

  # value_mapから足りていないColumnを補う関数。
  def modify_value_map(value_map, %DataTable{column_list: column_list})
      when is_map(value_map) do
    Enum.reduce(column_list, value_map, fn %Column{name: name} = column, acc ->
      if Map.has_key?(acc, name) do
        acc
      else
        val_init = Column.init_value(column, nil)
        Map.put(acc, name, val_init)
      end
    end)
  end
end
