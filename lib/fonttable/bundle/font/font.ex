defmodule Thaqqa.Font do
  alias Thaqqa.DataTable, as: DataTable

  defstruct [:name, table_list: %{}]

  def new(name, t), do: %__MODULE__{table_list: t, name: name}

  def get_table_list(%__MODULE__{table_list: tables}), do: tables

  def get_table(%__MODULE__{table_list: tables}, table_name), do: Map.get(tables, table_name)

  def add_table!(%__MODULE__{} = font, %DataTable{} = table) do
    add_table(font, table)
  end

  def add_table(
        %__MODULE__{table_list: tables} = font,
        %DataTable{name: table_name} = table
      ),
      do: %{font | table_list: Map.put(tables, table, table_name)}

  def delete_table(%__MODULE__{table_list: tables} = font, table_name),
    do: %{font | table_list: Map.delete(tables, table_name)}

  def edit_table(%__MODULE__{table_list: tables} = font, table_name, %DataTable{} = new_table),
    do: %{font | table_list: Map.put(tables, new_table, table_name)}
end
