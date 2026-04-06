# Prefabに処理を加えるモジュール

defmodule Thaqqa.PrefabOp do
  alias Thaqqa.PrefabComplement, as: PrefabComplement

  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error
  defstruct fonts: %{}, static_tables: %{}

  defp update_static_tables(%Prefab{} = self, st, st_name),
    do: %Prefab{self | static_tables: st} |> complement_by_static_table(st_name)

  def update_fonts(%Prefab{} = self, f), do: %Prefab{self | fonts: f}

  def overwrite_font(%Prefab{} = self, name, %Thaqqa.Font{} = font) do
    if Prefab.get_font(self, name) != nil,
      do: update_fonts(self, Map.put(self.fonts, name, font)),
      else: self
  end

  def init_font(%Prefab{} = self, %Thaqqa.Font{name: name} = font) do
    update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)
  end

  def add_font_if_enable(%Prefab{} = self, %Thaqqa.Font{} = font) do
    case add_font(self, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_font(%Prefab{} = self, %Thaqqa.Font{name: name} = font) do
    if Prefab.get_font(self, name) != nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      else: Error.nominal_conflict_font(name, :add)
  end

  def delete_font_if_enable(%Prefab{} = self, name) do
    case delete_font(self, name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_font(%Prefab{} = self, name) do
    case Map.get(self.fonts, name) do
      nil -> Error.font_not_found(name)
      _ -> update_fonts(self, Map.delete(self.fonts, name))
    end
  end

  def edit_font_if_enable(%Prefab{} = self, name, %Thaqqa.Font{} = font) do
    case edit_font(self, name, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_font(%Prefab{} = self, name, %Thaqqa.Font{} = font) do
    if Prefab.get_font(self, name) != nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      else: Error.font_not_found(name)
  end

  ## static_table類

  ## 以降、static_table系統の本体

  def init_static_table(%Prefab{} = self, %DataTable{name: name} = table),
    do: update_static_tables(self, Map.put(Prefab.get_static_table_list(self), name, table), name)

  def add_static_table_if_enable(%Prefab{} = self, %DataTable{} = table) do
    case add_static_table(self, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def add_static_table(%Prefab{} = self, %DataTable{name: name} = table) do
    if Prefab.get_static_table(self, name) == nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      Error.nominal_conflict_datatable(name, :add)
    end
  end

  def edit_static_table_if_enable(%Prefab{} = self, name, %DataTable{} = table) do
    case edit_static_table(self, name, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def edit_static_table(%Prefab{} = self, name, %DataTable{} = table) do
    if Prefab.get_static_table(self, name) != nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      Error.table_not_found(name)
    end
  end

  def delete_static_table_if_enable(%Prefab{} = self, name) do
    case delete_static_table(self, name) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def delete_static_table(%Prefab{} = self, name) do
    case Map.get(self.static_tables, name) do
      nil -> Error.table_not_found(name)
      _ -> {:ok, update_static_tables(self, Map.delete(self.static_tables, name), name)}
    end
  end

  ## table類 (直接弄れない設定)

  def add_column_if_enable(%Prefab{} = self, name, %Column{} = column) do
    case add_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_column(%Prefab{} = self, name, %Column{} = column) do
    case Prefab.get_static_table(self, name) do
      nil ->
        Error.table_not_found(name)

      %DataTable{name: name} = datatable ->
        dt = DataTable.add_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def edit_column_if_enable(%Prefab{} = self, name, %Column{} = column) do
    case edit_column(self, name, column) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_column(%Prefab{} = self, name, %Column{} = column) do
    case Prefab.get_static_table(self, name) do
      nil ->
        Error.table_not_found(name, :edit)

      %DataTable{name: name} = datatable ->
        dt = DataTable.edit_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def delete_column_if_enable(%Prefab{} = self, name, column_name) do
    case delete_column(self, name, column_name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_column(%Prefab{} = self, name, column_name) do
    case Prefab.get_static_table(self, name) do
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
        %Prefab{} = self,
        %DataTable{name: table_name} = datatable,
        column_name
      ),
      do: PrefabComplement.complement_table_by_column(self, datatable, column_name)

  def complement_table(%Prefab{} = self, font_name, table_name),
    do: PrefabComplement.complement_table(self, font_name, table_name)

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Prefab{} = self, font_name),
    do: PrefabComplement.complement_font(self, font_name)

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%Prefab{} = self, table_name),
    do: PrefabComplement.complement_by_static_table(self, table_name)

  def set_precompile_as_root(%Prefab{} = self),
    do: PrefabCompiler.set_precompile_as_root(self)

  def set_precompile_as_root_by_table(%Prefab{} = self, tablename),
    do: PrefabCompiler.set_precompile_as_root_by_table(self, tablename)

  def set_precompile_as_root_by_data(%Prefab{} = self, tablename, %Data{} = data),
    do: PrefabCompiler.set_precompile_as_root_by_data(self, data)

  def set_precompile_as_font(%Prefab{} = self, fontname),
    do: PrefabCompiler.set_precompile_as_font(self, fontname)

  def set_precompile_as_font_by_table(%Prefab{} = self, fontname, tablename),
    do: PrefabCompiler.set_precompile_as_font_by_table(self, fontname, tablename)

  def set_precompile_as_font_by_data(%Prefab{} = self, fontname, tablename, %Data{} = data),
    do: PrefabCompiler.set_precompile_as_font_by_data(self, fontname, tablename, data)

  def sort_as_static(%Prefab{} = self, tablename) do
    case Prefab.get_static_table(self, tablename) do
      nil -> self
      table -> edit_static_table_if_enable(self, tablename, DataTable.sort(table))
    end
  end

  def sort_as_font_table(%Prefab{} = self, fontname, tablename) do
    case Prefab.get_table(self, fontname, tablename) do
      nil ->
        self

      table ->
        font = Prefab.get_font(self, fontname)
        Font.edit_table(font, tablename, DataTable.sort(table))
        edit_font_if_enable(self, tablename, font)
    end
  end
end
