defmodule Thaqqa.FontRegistryPrefab do
  alias Thaqqa.FontRegistryPrefab.Complement, as: Complement
  alias Thaqqa.FontRegistryPrefab.Compiler, as: Compiler
  alias Thaqqa.FontRegistryPrefab.IO, as: IO
  alias Thaqqa.FontRegistryPrefab.Op, as: Op
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error
  defstruct fonts: %{}, static_tables: %{}

  # ※ぶっちゃけここはfonts,static_tablesを適時抜き出すだけでおｋ。
  # static_tablesもリストとする（将来的に複数使用する可能性があるので）
  def new(fonts, static_tables), do: %__MODULE__{fonts: fonts, static_tables: static_tables}

  def new_from_request(json) when is_map(json), do: IO.new_from_request(json)

  # update,overwrite,init系統は要置き場所検討
  def update_fonts(%__MODULE__{} = self, f), do: Op.update_fonts(self, f)

  def overwrite_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font),
    do: Op.overwrite_font(self, name, font)

  def init_font(%__MODULE__{} = self, %Thaqqa.Font{} = font), do: Op.init_font(self, font)

  def init_static_table_list(%__MODULE__{} = self, %Thaqqa.StaticTableList{} = static_table_list),
    do: Op.init_static_table_list(self, static_table_list)

  # get系統は何かしらを操作するわけではないのでここで処理。
  def get_font(%__MODULE__{} = self, name), do: Map.get(self.fonts, name)

  def get_font_or_error(%__MODULE__{} = self, name) do
    case get_font(self, name) do
      nil -> {:error, Error.font_not_found(name)}
      otherwise -> {:ok, otherwise}
    end
  end

  def get_font_from_filename(%__MODULE__{} = self, filename),
    do:
      get_font_list(self)
      |> Enum.filter(fn {_, val} -> val.filename == filename end)
      |> Enum.at(0)

  def get_font_list(%__MODULE__{} = self), do: self.fonts

  def get_static_table(%__MODULE__{} = self, name), do: Map.get(get_static_table_list(self), name)

  def get_static_table_or_error(%__MODULE__{} = self, name) do
    case get_static_table(self, name) do
      nil -> Error.table_not_found(name)
      table -> {:ok, table}
    end
  end

  #
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

  def get_table_or_error(%__MODULE__{} = self, fontname, tablename) do
    case get_font_or_error(self, fontname) do
      {:error, _} = err ->
        err

      {:ok, font} ->
        case Font.get_table(font, tablename) do
          nil -> Error.table_not_found(tablename, fontname)
          datatable -> {:ok, datatable}
        end
    end
  end

  def get_single_data_or_nil(%__MODULE__{} = self, fontname, tablename) do
    case get_table(self, fontname, tablename) do
      nil -> nil
      table -> table.data_list |> Enum.at(0)
    end
  end

  # nil ->
  def get_single_data(%__MODULE__{} = self, fontname, tablename) do
    case get_table(self, fontname, tablename) do
      nil -> Error.table_not_found(tablename, fontname)
      table -> {:ok, table.data_list |> Enum.at(0)}
    end
  end

  def get_single_data_value_or_nil(%__MODULE__{} = self, fontname, tablename, column) do
    case get_single_data_or_nil(self, fontname, tablename) do
      nil -> nil
      data -> Data.get_value(data, column)
    end
  end

  def get_single_data_value(%__MODULE__{} = self, fontname, tablename, column) do
    case get_single_data(self, fontname, tablename) do
      {:error, _} = err -> err
      {:ok, data} -> Data.get_value_or_error(data, column)
    end
  end

  def get_fontdata(%__MODULE__{} = prefab, fontname, list) when is_list(list) do
    case get_single_data(prefab, fontname, "FONTDATA") do
      {:ok, %Thaqqa.Data{} = data} ->
        {value_map, err_list} =
          Enum.reduce(list, {%{}, []}, fn arg, {acc, acc_err} ->
            case Thaqqa.Data.get_value(data, arg) do
              nil -> {acc, [arg | acc_err]}
              otherwise -> {Map.put(acc, String.to_atom(arg), otherwise), acc_err}
            end
          end)

        if length(err_list) == 0,
          do: {:ok, value_map},
          else: Error.data_not_found(nil, err_list, "FONTDATA", fontname)

      {:error, _} = err ->
        err
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
  # これらの実装のため、FontRegistry本体による可能なUUIDの取得関数が必須。
  def add_font_if_enable(%__MODULE__{} = self, %Thaqqa.Font{} = font),
    do: Op.add_font_if_enable(self, font)

  def add_font(%__MODULE__{} = self, %Thaqqa.Font{} = font), do: Op.add_font(self, font)

  def duplicate_font(%__MODULE__{} = self, fontname, fontname_duplication),
    do: Op.duplicate_font(self, fontname, fontname_duplication)

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

  def complement_table_by_column(%__MODULE__{} = self, %DataTable{} = datatable, column_name),
    do: Complement.complement_table_by_column(self, datatable, column_name)

  def complement_table(%__MODULE__{} = self, font_name, table_name),
    do: Complement.complement_table(self, font_name, table_name)

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%__MODULE__{} = self, font_name),
    do: Complement.complement_font(self, font_name)

  # 読み込み系
  def import_from_internal_folder(%__MODULE__{} = self, uuid),
    do: IO.import_from_internal_folder(self, uuid)

  # static_tableの変更に伴ってfontテーブル側を変更する
  # complement系統は直接static_tableやfontを参照する仕様＋平行化を執り行う。
  def complement_by_static_table(%__MODULE__{} = self, table_name),
    do: Complement.complement_by_static_table(self, table_name)

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
