# Bundleに処理を加えるモジュール

defmodule Thaqqa.Bundle.Op do
  alias Thaqqa.Bundle.Complement, as: Complement
  alias Thaqqa.Bundle.Compiler, as: Compiler

  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.IO, as: IO
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error
  defstruct fonts: %{}, static_tables: %{}

  defp update_static_tables(%Bundle{} = self, st, st_name),
    do: %Bundle{self | static_tables: st} |> complement_by_static_table(st_name)

  def update_fonts(%Bundle{} = self, f), do: %Bundle{self | fonts: f}

  def overwrite_font(%Bundle{} = self, name, %Thaqqa.Font{} = font) do
    if Bundle.get_font(self, name) != nil,
      do: update_fonts(self, Map.put(self.fonts, name, font)),
      else: self
  end

  def init_font(%Bundle{} = self, %Thaqqa.Font{name: name} = font) do
    update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)
  end

  def add_font_if_enable(%Bundle{} = self, %Thaqqa.Font{} = font) do
    case add_font(self, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_font(%Bundle{} = self, %Thaqqa.Font{name: name} = font) do
    if Bundle.get_font(self, name) == nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      else: Error.nominal_conflict_font(name, :add)
  end

  def duplicate_font(%Bundle{} = self, name, fontname_duplication, filename) do
    # TODO filename側の重複の方を確認する（むしろこっちのが大事）
    case Bundle.get_font(self, name) do
      nil ->
        Error.font_not_found(name)

      font ->
        cond do
          Bundle.get_font(self, fontname_duplication) != nil ->
            Error.nominal_conflict_font(name, :duplicate)

          Bundle.get_font_from_filename(self, filename) != nil ->
            Error.filename_conflict_font(name, :duplicate)

          true ->
            font_alt = %Thaqqa.Font{font | filename: filename}
            {:ok, update_fonts(self, Map.put(self.fonts, fontname_duplication, font_alt))}
        end
    end
  end

  def delete_font_if_enable(%Bundle{} = self, name) do
    case delete_font(self, name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_font(%Bundle{} = self, name) do
    case Map.get(self.fonts, name) do
      nil -> Error.font_not_found(name)
      _ -> {:ok, update_fonts(self, Map.delete(self.fonts, name))}
    end
  end

  def edit_font_if_enable(%Bundle{} = self, name, %Thaqqa.Font{} = font) do
    case edit_font(self, name, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_font(%Bundle{} = self, name, %Thaqqa.Font{} = font) do
    if Bundle.get_font(self, name) != nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      else: Error.font_not_found(name)
  end

  ## static_table類

  ## 以降、static_table系統の本体

  def init_static_table(%Bundle{} = self, %DataTable{name: name} = table),
    do: update_static_tables(self, Map.put(Bundle.get_static_table_list(self), name, table), name)

  def add_static_table_if_enable(%Bundle{} = self, %DataTable{} = table) do
    case add_static_table(self, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def add_static_table(%Bundle{} = self, %DataTable{name: name} = table) do
    if Bundle.get_static_table(self, name) == nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      Error.nominal_conflict_datatable(name, :add)
    end
  end

  def edit_static_table_if_enable(%Bundle{} = self, name, %DataTable{} = table) do
    case edit_static_table(self, name, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def edit_static_table(%Bundle{} = self, name, %DataTable{} = table) do
    if Bundle.get_static_table(self, name) != nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      Error.table_not_found(name)
    end
  end

  def delete_static_table_if_enable(%Bundle{} = self, name) do
    case delete_static_table(self, name) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def delete_static_table(%Bundle{} = self, name) do
    case Map.get(self.static_tables, name) do
      nil -> Error.table_not_found(name)
      _ -> {:ok, update_static_tables(self, Map.delete(self.static_tables, name), name)}
    end
  end

  ## table類 (直接弄れない設定)

  def add_column_if_enable(%Bundle{} = self, name, %Column{} = column) do
    case add_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_column(%Bundle{} = self, name, %Column{} = column) do
    case Bundle.get_static_table(self, name) do
      nil ->
        Error.table_not_found(name)

      %DataTable{name: name} = datatable ->
        case DataTable.add_column(datatable, column) do
          {:ok, dt} -> edit_static_table(self, name, dt)
          {:error, _} = err -> err
        end
    end
  end

  def edit_column_if_enable(%Bundle{} = self, name, %Column{} = column) do
    case edit_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_column(%Bundle{} = self, name, %Column{name: name} = column) do
    case Bundle.get_static_table(self, name) do
      nil ->
        Error.table_not_found(name, :edit)

      %DataTable{name: name} = datatable ->
        case DataTable.edit_column(datatable, name, column) do
          {:ok, dt} -> edit_static_table(self, name, dt)
          {:error, _} = err -> err
        end
    end
  end

  def delete_column_if_enable(%Bundle{} = self, name, column_name) do
    case delete_column(self, name, column_name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_column(%Bundle{} = self, name, column_name) do
    case Bundle.get_static_table(self, name) do
      nil ->
        Error.table_not_found(name)

      %DataTable{name: name} = datatable ->
        DataTable.delete_column(datatable, column_name)
        |> then(&edit_static_table(self, name, &1))
    end
  end

  #

  ## static_tableの設定に合わせてfontの仕様を同期させる
  ## 本体は別モジュールで行っている

  def complement_table_by_column(
        %Bundle{} = self,
        %DataTable{} = datatable,
        column_name
      ),
      # Complement.complement_table_by_column(self, datatable, column_name)
      do: self

  def complement_table(%Bundle{} = self, font_name, table_name),
    # Complement.complement_table(self, font_name, table_name)
    do: self

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Bundle{} = self, font_name),
    # Complement.complement_font(self, font_name)
    do: self

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%Bundle{} = self, table_name),
    # Complement.complement_by_static_table(self, table_name)
    do: self

  def set_precompile_as_root(%Bundle{} = self),
    do: Compiler.set_precompile_as_root(self)

  def set_precompile_as_root_by_table(%Bundle{} = self, tablename),
    do: Compiler.set_precompile_as_root_by_table(self, tablename)

  def set_precompile_as_root_by_data(%Bundle{} = self, tablename, %Data{} = data),
    do: Compiler.set_precompile_as_root_by_data(self, tablename, data)

  def set_precompile_as_font(%Bundle{} = self, fontname),
    do: Compiler.set_precompile_as_font(self, fontname)

  def set_precompile_as_font_by_table(%Bundle{} = self, fontname, tablename),
    do: Compiler.set_precompile_as_font_by_table(self, fontname, tablename)

  def set_precompile_as_font_by_data(%Bundle{} = self, fontname, tablename, %Data{} = data),
    do: Compiler.set_precompile_as_font_by_data(self, fontname, tablename, data)

  def sort_as_static(%Bundle{} = self, tablename) do
    case Bundle.get_static_table(self, tablename) do
      nil -> self
      table -> edit_static_table_if_enable(self, tablename, DataTable.sort(table))
    end
  end

  def sort_as_font_table(%Bundle{} = self, fontname, tablename) do
    case Bundle.get_table(self, fontname, tablename) do
      nil ->
        self

      table ->
        font = Bundle.get_font(self, fontname)
        Font.edit_table(font, tablename, DataTable.sort(table))
        edit_font_if_enable(self, tablename, font)
    end
  end
end
