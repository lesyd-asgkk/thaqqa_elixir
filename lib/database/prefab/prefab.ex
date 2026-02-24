defmodule Thaqqa.FontRegistryPrefab do
  alias Thaqqa.PrefabComplement, as: PrefabComplement
  alias Thaqqa.PrefabCompiler, as: PrefabCompiler
  alias Thaqqa.PrefabIO, as: PrefabIO
  alias Thaqqa.PrefabOp, as: PrefabOp
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error
  defstruct fonts: %{}, static_tables: %{}

  def new(fonts, static_tables), do: %__MODULE__{fonts: fonts, static_tables: static_tables}
  # update,overwrite,init系統は要置き場所検討
  def update_fonts(%__MODULE__{} = self, f), do: PrefabOp.update_fonts(self, f)

  defp update_static_tables(%__MODULE__{} = self, st, st_name),
    do: %__MODULE__{self | static_tables: st} |> complement_by_static_table(st_name)

  def overwrite_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: PrefabOp.overwrite_font(self, name, font)

  def init_font(%__MODULE__{} = self, %Thaqqa.Font{} = font), do: PrefabOp.init_font(self, font)

  def init_static_table(%__MODULE__{} = self, %DataTable{name: name} = table),
    do: update_static_tables(self, Map.put(get_static_table_list(self), name, table), name)

  # get系統は何かしらを操作するわけではないのでここで処理。
  def get_font(%__MODULE__{} = self, name), do: Map.get(self.fonts, name)
  def get_font_list(%__MODULE__{} = self), do: self.fonts

  def get_static_table(%__MODULE__{} = self, name), do: Map.get(get_static_table_list(self), name)

  def get_static_table_list(%__MODULE__{} = self), do: self.static_tables

  def get_global_static_table_list(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> val.global end)

  def get_local_static_table_list(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> !val.global end)

  def static_table_exists?(self, table_name),
    do:
      get_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def local_static_table_exists?(self, table_name),
    do:
      get_local_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def global_static_table_exists?(self, table_name),
    do:
      get_global_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def get_table(%__MODULE__{} = self, fontname, tablename) do
    case get_font(self, fontname) do
      nil -> nil
      font -> Font.get_table(font, tablename)
    end
  end

  def get_column_list(%__MODULE__{} = self, name) do
    case get_static_table(self, name) do
      nil -> nil
      datatable -> datatable.column_list
    end
  end

  def get_column(%__MODULE__{} = self, table_name, column_name) do
    case get_static_table(self, table_name) do
      nil -> nil
      datatable -> datatable.column_list |> Enum.find(&(&1.name == column_name))
    end
  end

  # add,delete,edit系統
  def add_font_if_enable(%__MODULE__{} = self, %Thaqqa.Font{} = font),
    do: PrefabOp.add_font_if_enable(self, font)

  def add_font(%__MODULE__{} = self, %Thaqqa.Font{} = font), do: PrefabOp.add_font(self, font)

  def delete_font_if_enable(%__MODULE__{} = self, name),
    do: PrefabOp.delete_font_if_enable(self, name)

  def delete_font(%__MODULE__{} = self, name), do: PrefabOp.delete_font(self, name)

  def edit_font_if_enable(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: PrefabOp.edit_font_if_enable(self, name, font)

  def edit_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: PrefabOp.edit_font(self, name, font)

  def add_static_table_if_enable(%__MODULE__{} = self, %DataTable{} = table),
    do: PrefabOp.add_static_table_if_enable(self, table)

  def add_static_table(%__MODULE__{} = self, %DataTable{} = table),
    do: PrefabOp.add_static_table(self, table)

  def edit_static_table_if_enable(%__MODULE__{} = self, name, %DataTable{} = table),
    do: PrefabOp.edit_static_table_if_enable(self, name, table)

  def edit_static_table(%__MODULE__{} = self, name, %DataTable{} = table),
    do: PrefabOp.edit_static_table(self, name, table)

  def delete_static_table_if_enable(%__MODULE__{} = self, name),
    do: PrefabOp.delete_static_table_if_enable(self, name)

  def delete_static_table(%__MODULE__{} = self, name),
    do: PrefabOp.delete_static_table(self, name)

  def add_column_if_enable(%__MODULE__{} = self, name, %Column{} = column),
    do: PrefabOp.add_column_if_enable(self, name, column)

  def add_column(%__MODULE__{} = self, name, %Column{} = column),
    do: PrefabOp.add_column(self, name, column)

  def edit_column_if_enable(%__MODULE__{} = self, name, %Column{} = column),
    do: PrefabOp.edit_column_if_enable(self, name, column)

  def edit_column(%__MODULE__{} = self, name, %Column{} = column),
    do: PrefabOp.edit_column(self, name, column)

  def delete_column_if_enable(%__MODULE__{} = self, name, column_name),
    do: PrefabOp.delete_column_if_enable(self, name, column_name)

  def delete_column(%__MODULE__{} = self, name, column_name),
    do: PrefabOp.delete_column(self, name, column_name)

  #

  ## static_tableの設定に合わせてfontの仕様を同期させる
  ## 本体は別モジュールで行っている

  def complement_table_by_column(
        %__MODULE__{} = self,
        %DataTable{name: table_name} = datatable,
        column_name
      ),
      do: PrefabComplement.complement_table_by_column(self, datatable, column_name)

  def complement_table(%__MODULE__{} = self, font_name, table_name),
    do: PrefabComplement.complement_table(self, font_name, table_name)

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%__MODULE__{} = self, font_name),
    do: PrefabComplement.complement_font(self, font_name)

  # 読み込み系
  def import_as_root(%__MODULE__{} = self, rootdata) when is_map(rootdata),
    do: PrefabIO.import_as_root(self, rootdata)

  def import_as_font(%__MODULE__{} = self, fontdata, filename) when is_map(fontdata),
    do: PrefabIO.import_as_font(self, fontdata, filename)

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%__MODULE__{} = self, table_name),
    do: PrefabComplement.complement_by_static_table(self, table_name)

  def set_precompile_as_root(%__MODULE__{} = self),
    do: PrefabCompiler.set_precompile_as_root(self)

  def set_precompile_as_root_by_table(%__MODULE__{} = self, tablename),
    do: PrefabCompiler.set_precompile_as_root_by_table(self, tablename)

  def set_precompile_as_root_by_data(%__MODULE__{} = self, tablename, %Data{} = data),
    do: PrefabCompiler.set_precompile_as_root_by_data(self, data)

  def set_precompile_as_font(%__MODULE__{} = self, fontname),
    do: PrefabCompiler.set_precompile_as_font(self, fontname)

  def set_precompile_as_font_by_table(%__MODULE__{} = self, fontname, tablename),
    do: PrefabCompiler.set_precompile_as_font_by_table(self, fontname, tablename)

  def set_precompile_as_font_by_data(%__MODULE__{} = self, fontname, tablename, %Data{} = data),
    do: PrefabCompiler.set_precompile_as_font_by_data(self, fontname, tablename, data)

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

  # 読み込み系
  def import_as_root(%__MODULE__{} = self, rootdata) when is_map(rootdata),
    do: PrefabIO.import_as_root(self, rootdata)

  def import_as_font(%__MODULE__{} = self, fontdata, filename) when is_map(fontdata),
    do: PrefabIO.import_as_font(self, fontdata, filename)
end
