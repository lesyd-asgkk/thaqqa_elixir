defmodule Thaqqa.ConstTable.Query do
  alias Thaqqa.ConstTable, as: ConstTable
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Data, as: Data

  def get_const_table_or_error(%ConstTable{} = self, name) do
    case get_const_table(self, name) do
      nil -> Error.table_not_found(name)
      table -> {:ok, table}
    end
  end

  def get_const_table(%ConstTable{} = self, name), do: Map.get(get_const_table_list(self), name)

  def get_const_table_list(%ConstTable{} = self), do: self.const_tables

  def get_static_const_table_list(%ConstTable{} = self),
    do: get_const_table_list(self) |> Enum.filter(fn {_, val} -> val.static end)

  def get_global_const_table_list(%ConstTable{} = self),
    do: get_const_table_list(self) |> Enum.filter(fn {_, val} -> val.global end)

  def get_local_const_table_list(%ConstTable{} = self),
    do: get_const_table_list(self) |> Enum.filter(fn {_, val} -> !val.global end)

  def const_table_exists?(self, table_name),
    do:
      get_const_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def static_const_table_exists?(self, table_name),
    do:
      get_static_const_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def local_const_table_exists?(self, table_name),
    do:
      get_local_const_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def global_const_table_exists?(self, table_name),
    do:
      get_global_const_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  # single_data系統。

  def get_single_data_or_nil(%ConstTable{} = self, tablename) do
    case get_const_table(self, tablename) do
      nil -> nil
      table -> table.data_list |> Enum.at(0)
    end
  end

  def get_single_data(%ConstTable{} = self, tablename) do
    case get_const_table(self, tablename) do
      nil -> Error.table_not_found(tablename)
      table -> {:ok, table.data_list |> Enum.at(0)}
    end
  end

  def get_single_data_value_or_nil(%ConstTable{} = self, tablename, column) do
    case get_single_data_or_nil(self, tablename) do
      nil -> nil
      data -> Data.get_value(data, column)
    end
  end

  def get_single_data_value(%ConstTable{} = self, tablename, column) do
    case get_single_data(self, tablename) do
      {:error, _} = err -> err
      {:ok, data} -> Data.get_value_or_error(data, column)
    end
  end

  def get_column_list(%ConstTable{} = self, name) do
    case get_const_table(self, name) do
      nil -> nil
      datatable -> datatable.column_list
    end
  end

  def get_column(%ConstTable{} = self, table_name, column_name) do
    case get_const_table(self, table_name) do
      nil -> nil
      datatable -> datatable.column_list |> Enum.find(&(&1.name == column_name))
    end
  end
end
