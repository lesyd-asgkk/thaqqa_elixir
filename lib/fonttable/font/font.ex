defmodule Thaqqa.Font do
  alias Thaqqa.DataTable, as: DataTable
  defstruct [:filename, :name, table_list: []]

  def new(filename, name, t), do: %__MODULE__{table_list: t, name: name, filename: filename}

  def get_table_list(%__MODULE__{table_list: tables}), do: tables

  def get_table(%__MODULE__{table_list: tables}, table_name) do
    Enum.find(tables, fn table -> table.name == table_name end)
  end

  def add_table!(%__MODULE__{} = font, %DataTable{} = table) do
    add_table(font, table)
  end

  def add_table(
        %__MODULE__{table_list: tables, name: fontname} = font,
        %DataTable{} = table
      ) do
    table = %DataTable{table | parent: fontname}
    %{font | table_list: tables ++ [table]}
  end

  def delete_table(%__MODULE__{table_list: tables} = font, table_name) do
    new_tables = Enum.filter(tables, fn table -> table.name != table_name end)
    %{font | table_list: new_tables}
  end

  def edit_table(%__MODULE__{table_list: tables} = font, table_name, %DataTable{} = new_table) do
    new_tables =
      Enum.map(tables, fn
        table when table.name == table_name -> new_table
        table -> table
      end)

    %{font | table_list: new_tables}
  end
end
