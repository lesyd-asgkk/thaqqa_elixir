defmodule Thaqqa.Bundle do
  alias Thaqqa.Bundle.Query, as: Query
  alias Thaqqa.Bundle.Complement, as: Complement
  alias Thaqqa.Bundle.Compiler, as: Compiler
  alias Thaqqa.Bundle.IO, as: IO
  alias Thaqqa.Bundle.Op, as: Op
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error
  defstruct fonts: %{}, static_tables: %{}, uuid: nil, owner: "", co_owner: ""

  def new(), do: new(%{}, %{}, nil, "", "")

  def new(fonts, static_tables), do: new(fonts, static_tables, nil, "", "")

  def new(fonts, static_tables, uuid, owner, co_owner),
    do: %__MODULE__{
      fonts: fonts,
      static_tables: static_tables,
      uuid: uuid,
      owner: owner,
      co_owner: co_owner
    }

  def new_from_request(json) when is_map(json), do: IO.new_from_request(json)

  # update,overwrite,init系統は要置き場所検討
  def update_fonts(%__MODULE__{} = self, f), do: Op.update_fonts(self, f)

  # ※complementは一旦要らない
  defp update_static_tables(%__MODULE__{} = self, st, st_name),
    do: %__MODULE__{self | static_tables: st} |> complement_by_static_table(st_name)

  def overwrite_font(%__MODULE__{} = self, name, %Font{} = font),
    do: Op.overwrite_font(self, name, font)

  def init_font(%__MODULE__{} = self, %Font{} = font), do: Op.init_font(self, font)

  def init_static_table(%__MODULE__{} = self, %DataTable{name: name} = table),
    do: update_static_tables(self, Map.put(get_static_table_list(self), name, table), name)

  # get系統
  def get_font(%__MODULE__{} = self, name), do: Query.get_font(self, name)

  def get_font_or_error(%__MODULE__{} = self, name), do: Query.get_font_or_error(self, name)

  def get_font_from_filename(%__MODULE__{} = self, filename),
    do: Query.get_font_from_filename(self, filename)

  def get_font_list(%__MODULE__{} = self), do: Query.get_font_list(self)

  def get_static_table(%__MODULE__{} = self, name), do: Query.get_static_table(self, name)

  def get_static_table_or_error(%__MODULE__{} = self, name),
    do: Query.get_static_table_or_error(self, name)

  def get_static_table_list(%__MODULE__{} = self), do: Query.get_static_table_list(self)

  def get_global_static_table_list(%__MODULE__{} = self),
    do: Query.get_global_static_table_list(self)

  def get_local_static_table_list(%__MODULE__{} = self),
    do: Query.get_local_static_table_list(self)

  def static_table_exists?(self, table_name), do: Query.static_table_exists?(self, table_name)

  def local_static_table_exists?(self, table_name),
    do: Query.local_static_table_exists?(self, table_name)

  def global_static_table_exists?(self, table_name),
    do: Query.global_static_table_exists?(self, table_name)

  def get_table(%__MODULE__{} = self, fontname, tablename),
    do: Query.get_table(self, fontname, tablename)

  def get_table_or_error(%__MODULE__{} = self, fontname, tablename),
    do: Query.get_table_or_error(self, fontname, tablename)

  def get_single_data_or_nil(%__MODULE__{} = self, fontname, tablename),
    do: Query.get_single_data_or_nil(self, fontname, tablename)

  def get_single_data(%__MODULE__{} = self, fontname, tablename),
    do: Query.get_single_data(self, fontname, tablename)

  def get_single_data_value_or_nil(%__MODULE__{} = self, fontname, tablename, column),
    do: Query.get_single_data_value_or_nil(self, fontname, tablename, column)

  def get_single_data_value(%__MODULE__{} = self, fontname, tablename, column),
    do: Query.get_single_data_value(self, fontname, tablename, column)

  def get_fontdata(%__MODULE__{} = self, fontname, list),
    do: Query.get_fontdata(self, fontname, list)

  def get_column_list(%__MODULE__{} = self, name), do: Query.get_column_list(self, name)

  def get_column(%__MODULE__{} = self, table_name, column_name),
    do: Query.get_column(self, table_name, column_name)

  # add,delete,edit系統
  def add_font_if_enable(%__MODULE__{} = self, %Thaqqa.Font{} = font),
    do: Op.add_font_if_enable(self, font)

  def add_font(%__MODULE__{} = self, %Thaqqa.Font{} = font), do: Op.add_font(self, font)

  def duplicate_font(%__MODULE__{} = self, fontname, fontname_duplication, filename),
    do: Op.duplicate_font(self, fontname, fontname_duplication, filename)

  def delete_font_if_enable(%__MODULE__{} = self, name),
    do: Op.delete_font_if_enable(self, name)

  def delete_font(%__MODULE__{} = self, name), do: Op.delete_font(self, name)

  def edit_font_if_enable(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: Op.edit_font_if_enable(self, name, font)

  def edit_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: Op.edit_font(self, name, font)

  def add_static_table_if_enable(%__MODULE__{} = self, %DataTable{} = table),
    do: Op.add_static_table_if_enable(self, table)

  def add_static_table(%__MODULE__{} = self, %DataTable{} = table),
    do: Op.add_static_table(self, table)

  def edit_static_table_if_enable(%__MODULE__{} = self, name, %DataTable{} = table),
    do: Op.edit_static_table_if_enable(self, name, table)

  def edit_static_table(%__MODULE__{} = self, name, %DataTable{} = table),
    do: Op.edit_static_table(self, name, table)

  def delete_static_table_if_enable(%__MODULE__{} = self, name),
    do: Op.delete_static_table_if_enable(self, name)

  def delete_static_table(%__MODULE__{} = self, name),
    do: Op.delete_static_table(self, name)

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

  #

  ## static_tableの設定に合わせてfontの仕様を同期させる
  ## 本体は別モジュールで行っている
  ## ※ファイルシステムの改定に基づき、一番作り直すべき場所

  def complement_table_by_column(%__MODULE__{} = self, %DataTable{} = datatable, column_name),
    do: Complement.complement_table_by_column(self, datatable, column_name)

  def complement_table(%__MODULE__{} = self, font_name, table_name),
    do: Complement.complement_table(self, font_name, table_name)

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%__MODULE__{} = self, font_name),
    do: Complement.complement_font(self, font_name)

  # 読み込み系
  def import_as_root(%__MODULE__{} = self, rootdata) when is_map(rootdata),
    do: IO.import_as_root(self, rootdata)

  def import_as_font(%__MODULE__{} = self, fontdata, filename) when is_map(fontdata),
    do: IO.import_as_font(self, fontdata, filename)

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%__MODULE__{} = self, table_name),
    # Complement.complement_by_static_table(self, table_name)
    do: self

  def set_precompile_on_root(%__MODULE__{} = self),
    do: Compiler.set_precompile_on_root(self)

  def set_precompile_on_font(%__MODULE__{} = self, fontname),
    do: Compiler.set_precompile_on_font(self, fontname)

  # {:ok/:error}バージョンも作る（要はnil対応）
  def sort_as_static_if_enable(%__MODULE__{} = self, tablename) do
    case sort_as_static(self, tablename) do
      {:ok, prefab} -> prefab
      {:error, _} -> self
    end
  end

  def sort_as_font_table_if_enable(%__MODULE__{} = self, fontname, tablename) do
    case sort_as_font_table(self, fontname, tablename) do
      {:ok, prefab} -> prefab
      {:error, _} -> self
    end
  end

  def sort_as_static(%__MODULE__{} = self, tablename) do
    case get_static_table(self, tablename) do
      nil -> Error.table_not_found(tablename)
      table -> edit_static_table(self, tablename, DataTable.sort(table))
    end
  end

  def sort_as_font_table(%__MODULE__{} = self, fontname, tablename) do
    case get_table(self, fontname, tablename) do
      nil ->
        Error.table_not_found(tablename)

      table ->
        font = get_font(self, fontname)
        Font.edit_table(font, tablename, DataTable.sort(table))
        edit_font(self, tablename, font)
    end
  end
end
