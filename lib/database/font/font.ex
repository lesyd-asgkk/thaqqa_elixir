defmodule Thaqqa.Font do
  # fontの関数について、結果としてtableの名前が変更される/追加される/削除されるものは
  # 直接APIを提供しないようにし、FontRegistryで編集するように変更する
  # font内tableの整合性機能をつける？（root.jsonで定義されていないtableは削除したり、定義されたtableが存在しなかったら自動で追加する、読み込み時にcolumnのエラーをチェックする）
  # それかいっそ「font= "Fontname"」のようなcolumnを必須にしてしまうか。

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegisteryPrefab, as: FontRegisteryPrefab
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Regex_Khhyl.Error, as: Error
  defstruct [:filename, :name, table_list: []]

  def new(filename, name, t), do: %__MODULE__{table_list: t, name: name, filename: filename}

  def get_table_all(%__MODULE__{table_list: tables}), do: tables

  def get_table(%__MODULE__{table_list: tables}, table_name) do
    Enum.find(tables, fn table -> table.name == table_name end)
  end

  def add_table!(%__MODULE__{} = font, %DataTable{} = table) do
    add_table(font, table)
  end

  def add_table(
        %__MODULE__{table_list: tables, name: fontname} = font,
        %DataTable{name: name} = table
      ) do
    table = %DataTable{table | parent: fontname}
    %{font | table_list: tables ++ [table]}
  end

  def delete_table!(%__MODULE__{} = font, %DataTable{} = table, table_name) do
    add_table(font, table)
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
