defmodule Thaqqa.ConstTable do
  defstruct const_tables: %{}

  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.ConstTable.Complement, as: Complement
  alias Thaqqa.ConstTable.Query, as: Query
  alias Thaqqa.ConstTable.Op, as: Op
  alias Thaqqa.ConstTable.IO, as: IO
  alias Thaqqa.Column, as: Column

  def new(), do: %__MODULE__{const_tables: %{}}
  def new(const_tables), do: %__MODULE__{const_tables: const_tables}

  defp update_const_tables(%__MODULE__{} = self, ct),
    do: %__MODULE__{self | const_tables: ct}

  def init_const_table(%__MODULE__{} = self, %DataTable{name: name} = table),
    do: update_const_tables(self, Map.put(self.const_tables, name, table))

  # Get/Query系。
  def get_const_table(%__MODULE__{} = self, name), do: Query.get_const_table(self, name)

  def get_const_table_or_error(%__MODULE__{} = self, name),
    do: Query.get_const_table_or_error(self, name)

  def get_const_table_list(%__MODULE__{} = self), do: Query.get_const_table_list(self)

  def get_static_const_table_list(%__MODULE__{} = self),
    do: Query.get_static_const_table_list(self)

  def get_global_const_table_list(%__MODULE__{} = self),
    do: Query.get_global_const_table_list(self)

  def get_local_const_table_list(%__MODULE__{} = self),
    do: Query.get_local_const_table_list(self)

  def const_table_exists?(self, table_name), do: Query.const_table_exists?(self, table_name)

  def static_const_table_exists?(self, table_name),
    do: Query.static_const_table_exists?(self, table_name)

  def local_const_table_exists?(self, table_name),
    do: Query.local_const_table_exists?(self, table_name)

  def global_const_table_exists?(self, table_name),
    do: Query.global_const_table_exists?(self, table_name)

  def get_single_data_or_nil(%__MODULE__{} = self, tablename),
    do: Query.get_single_data_or_nil(self, tablename)

  def get_single_data(%__MODULE__{} = self, tablename),
    do: Query.get_single_data(self, tablename)

  def get_single_data_value_or_nil(%__MODULE__{} = self, tablename, column),
    do: Query.get_single_data_value_or_nil(self, tablename, column)

  def get_single_data_value(%__MODULE__{} = self, tablename, column),
    do: Query.get_single_data_value(self, tablename, column)

  def get_column_list(%__MODULE__{} = self, name), do: Query.get_column_list(self, name)

  def get_column(%__MODULE__{} = self, table_name, column_name),
    do: Query.get_column(self, table_name, column_name)

  # CRUD系

  def add_const_table_if_enable(%__MODULE__{} = self, %DataTable{} = table),
    do: Op.add_const_table_if_enable(self, table)

  def add_const_table(%__MODULE__{} = self, %DataTable{} = table),
    do: Op.add_const_table(self, table)

  def edit_const_table_if_enable(%__MODULE__{} = self, name, %DataTable{} = table),
    do: Op.edit_const_table_if_enable(self, name, table)

  def edit_const_table(%__MODULE__{} = self, name, %DataTable{} = table),
    do: Op.edit_const_table(self, name, table)

  def delete_const_table_if_enable(%__MODULE__{} = self, name),
    do: Op.delete_const_table_if_enable(self, name)

  def delete_const_table(%__MODULE__{} = self, name),
    do: Op.delete_const_table(self, name)

  def add_column_if_enable(%__MODULE__{} = self, name, %Column{} = column),
    do: Op.add_column_if_enable(self, name, column)

  def add_column(%__MODULE__{} = self, name, %Column{} = column),
    do: Op.add_column(self, name, column)

  def edit_column_if_enable(%__MODULE__{} = self, name, %Column{} = column),
    do: Op.edit_column_if_enable(self, name, column)

  def edit_column(%__MODULE__{} = self, name, %Column{} = column),
    do: Op.edit_column(self, name, column)

  def delete_column_if_enable(%__MODULE__{} = self, name, column_name),
    do: Op.delete_column_if_enable(self, name, column_name)

  def delete_column(%__MODULE__{} = self, name, column_name),
    do: Op.delete_column(self, name, column_name)

  # complement系

  def import_as_const(%__MODULE__{} = self, constdata) when is_map(constdata),
    do: IO.import_as_const(self, constdata)

  def complement(%__MODULE__{} = self, bundles) when is_map(bundles),
    do: Complement.complement(self, bundles)

  def complement_bundle(%__MODULE__{} = self, %Bundle{} = bundle),
    do: Complement.complement_bundle(self, bundle)

  # def new_from_request(json) when is_map(json), do: IO.new_from_request(json)
end
