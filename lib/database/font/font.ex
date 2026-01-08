defmodule Thaqqa.Font do
  # fontの関数について、結果として名前が変更される/追加される/削除されるものは
  # こちらから編集できないようにし、FontRegistryで編集するように変更する
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  defstruct [:filename, :name, table_list: []]

  def new(filename, name, t), do: %__MODULE__{table_list: t, name: name, filename: filename}

  def get_table(%__MODULE__{table_list: tables}, table_name) do
    Enum.find(tables, fn table -> table.name == table_name end)
  end

  def add_table!(%__MODULE__{} = font, %DataTable{} = table) do
    case add_table(font, table) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_table(
        %__MODULE__{table_list: tables, name: fontname} = font,
        %DataTable{name: name} = table
      ) do
    case FontRegistry.get_static_table(name) do
      {:error, reason} ->
        Error.genserver_error(reason)

      {:ok, nil} ->
        if get_table(font, name) != nil do
          Error.nominal_conflict_datatable(name, :add)
        else
          table = %DataTable{table | parent: fontname}
          {:ok, %{font | table_list: tables ++ [table]}}
        end

      {:ok, _} ->
        Error.nominal_conflict_datatable(name, :add)
    end
  end

  def delete_table(%__MODULE__{table_list: tables} = font, table_name) do
    new_tables = Enum.filter(tables, fn table -> table.name != table_name end)
    %{font | table_list: new_tables}
  end

  def edit_table(
        %__MODULE__{table_list: tables} = font,
        table_name,
        %DataTable{name: new_name} = new_table
      ) do
    new_tables =
      Enum.map(tables, fn
        table when table.name == table_name -> new_table
        table -> table
      end)

    %{font | table_list: new_tables}
  end

  def update_fontregistry(%__MODULE__{name: name} = font) do
    FontRegistry.edit_font(name, font)
    font
  end
end
