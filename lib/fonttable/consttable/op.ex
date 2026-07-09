defmodule Thaqqa.ConstTable.Op do
  alias Thaqqa.ConstTable, as: ConstTable
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error

  defp update_const_tables(%ConstTable{} = self, st),
    do: %ConstTable{self | const_tables: st}

  def init_const_table(%ConstTable{} = self, %DataTable{name: name} = table),
    do:
      update_const_tables(
        self,
        Map.put(ConstTable.get_const_table_list(self), name, table)
      )

  def add_const_table_if_enable(%ConstTable{} = self, %DataTable{} = table) do
    case add_const_table(self, table) do
      {:error, _} -> self.const_tables
      {:ok, value} -> value
    end
  end

  def add_const_table(%ConstTable{} = self, %DataTable{name: name} = table) do
    if ConstTable.get_const_table(self, name) == nil do
      {:ok, update_const_tables(self, Map.put(self.const_tables, name, table))}
    else
      Error.nominal_conflict_datatable(name, :add)
    end
  end

  def edit_const_table_if_enable(%ConstTable{} = self, name_alt, %DataTable{} = table) do
    case edit_const_table(self, name_alt, table) do
      {:error, _} -> self.const_tables
      {:ok, value} -> value
    end
  end

  def edit_const_table(%ConstTable{} = self, name_alt, %DataTable{name: name} = table) do
    if ConstTable.get_const_table(self, name_alt) != nil do
      {:ok,
       update_const_tables(self, Map.delete(self.const_tables, name_alt) |> Map.put(name, table))}
    else
      Error.table_not_found(name)
    end
  end

  def delete_const_table_if_enable(%ConstTable{} = self, name) do
    case delete_const_table(self, name) do
      {:error, _} -> self.const_tables
      {:ok, value} -> value
    end
  end

  def delete_const_table(%ConstTable{} = self, name) do
    case Map.get(self.const_tables, name) do
      nil -> Error.table_not_found(name)
      _ -> {:ok, update_const_tables(self, Map.delete(self.const_tables, name))}
    end
  end

  ## table類 (直接弄れない設定)

  def add_column_if_enable(%ConstTable{} = self, name, %Column{} = column) do
    case add_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_column(%ConstTable{} = self, name, %Column{} = column) do
    case ConstTable.get_const_table(self, name) do
      nil ->
        Error.table_not_found(name)

      %DataTable{name: name} = datatable ->
        case DataTable.add_column(datatable, column) do
          {:ok, dt} -> edit_const_table(self, name, dt)
          {:error, _} = err -> err
        end
    end
  end

  def edit_column_if_enable(%ConstTable{} = self, name, %Column{} = column) do
    case edit_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_column(%ConstTable{} = self, name, %Column{name: name} = column) do
    case ConstTable.get_const_table(self, name) do
      nil ->
        Error.table_not_found(name, :edit)

      %DataTable{name: name} = datatable ->
        case DataTable.edit_column(datatable, name, column) do
          {:ok, dt} -> edit_const_table(self, name, dt)
          {:error, _} = err -> err
        end
    end
  end

  def delete_column_if_enable(%ConstTable{} = self, name, column_name) do
    case delete_column(self, name, column_name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_column(%ConstTable{} = self, name, column_name) do
    case ConstTable.get_const_table(self, name) do
      nil ->
        Error.table_not_found(name)

      %DataTable{name: name} = datatable ->
        DataTable.delete_column(datatable, column_name)
        |> then(&edit_const_table(self, name, &1))
    end
  end
end
