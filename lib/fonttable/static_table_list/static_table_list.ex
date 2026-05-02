defmodule Thaqqa.StaticTableList do
  alias Thaqqa.DataTable, as: DataTable
  defstruct [:uuid, table_list: []]

  def new(uuid, t), do: %__MODULE__{table_list: t, uuid: uuid}

  def get_table_list(%__MODULE__{table_list: tables}), do: tables

  def get_table(%__MODULE__{table_list: tables}, table_name) do
    Enum.find(tables, fn table -> table.name == table_name end)
  end

  def add_table!(%__MODULE__{} = static_table, %DataTable{} = table) do
    add_table(static_table, table)
  end

  def add_table(
        %__MODULE__{table_list: tables} = static_table,
        %DataTable{} = table
      ) do
    %{static_table | table_list: [table | tables]}
  end

  def delete_table(%__MODULE__{table_list: tables} = static_table, table_name) do
    new_tables = Enum.filter(tables, fn table -> table.name != table_name end)
    %{static_table | table_list: new_tables}
  end

  def edit_table(
        %__MODULE__{table_list: tables} = static_table,
        table_name,
        %DataTable{} = new_table
      ) do
    new_tables =
      Enum.map(tables, fn
        table when table.name == table_name -> new_table
        table -> table
      end)

    %{static_table | table_list: new_tables}
  end
end
