defmodule Thaqqa.FontRegisteryPrefab do
  defstruct fonts: %{}, static_tables: %{}

  def new(fonts, static_tables), do: %__MODULE__{fonts: fonts, static_tables: static_tables}

  defp update_static_tables(%__MODULE__{} = self, st), do: %__MODULE__{self | static_tables: st}
  defp update_fonts(%__MODULE__{} = self, f), do: %__MODULE__{self | fonts: f}

  def init_font(%__MODULE__{} = self, %Thaqqa.Font{name: name} = font) do
    update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)
  end

  # こちらは既に存在する場合は反映しない
  def add_font(%__MODULE__{} = self, %Thaqqa.Font{name: name} = font) do
    if get_font(self, name) != nil do
      update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)
    else
      self
    end
  end

  def delete_font(%__MODULE__{} = self, name) do
    update_fonts(self, Map.delete(self.fonts, name)) |> complement_font(name)
  end

  def get_font(%__MODULE__{} = self, name), do: Map.get(self.fonts, name)

  def edit_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font) do
    if get_font(self, name) != nil do
      update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)
    else
      self
    end
  end

  ## static_table類

  ## static_tableの設定に合わせて全fontの仕様を同期させる
  defp complement_table(%__MODULE__{} = self, font_name, table_name) do
    self
  end

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  defp complement_font(%__MODULE__{} = self, font_name) do
    self
  end

  # static_tableの変更に伴ってfontテーブル側を変更する
  defp complement_by_static_table(%__MODULE__{} = self, table_name) do
    self.static_tables
  end

  def get_static_table(%__MODULE__{} = self, name), do: Map.get(self.static_tables, name)

  def get_static_table_list(%__MODULE__{} = self), do: self.static_tables

  def get_static_table_list_global(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> val.global end)

  def get_static_table_list_local(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> !val.global end)

  def init_static_table(%__MODULE__{} = self, %Thaqqa.DataTable{name: name} = table) do
    update_static_tables(self, Map.put(self.static_tables, name, table))
    |> complement_font(name)
  end

  def add_static_table(%__MODULE__{} = self, %Thaqqa.DataTable{name: name} = table) do
    if get_static_table(self, name) != nil do
      update_static_tables(self, Map.put(self.static_tables, name, table))
      |> complement_font(name)
    else
      self.static_tables
    end
  end

  def edit_static_table(%__MODULE__{} = self, name, %Thaqqa.DataTable{} = table) do
    if get_static_table(self, name) != nil do
      update_static_tables(self, Map.put(self.static_tables, name, table))
      |> complement_font(name)
    else
      self.static_tables
    end
  end

  def delete_static_table(%__MODULE__{} = self, name) do
    update_static_tables(self, Map.delete(self.static_tables, name))
    |> complement_font(name)
  end

  ## table類 (直接弄れない設定)
  def import_table(%__MODULE__{} = self, name, json) do
  end

  def get_table(%__MODULE__{} = self, fontname, tablename),
    do: get_in(self.fonts, [fontname, tablename])

  # column
  def get_column_list(%__MODULE__{} = self, name) do
    case get_static_table(self, name) do
      nil -> nil
      datatable -> datatable.column_list
    end
  end

  def add_column(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case get_static_table(self, name) do
      nil ->
        # 将来的にはエラー落ち。
        self

      %Thaqqa.DataTable{name: name} = datatable ->
        # DatTableのadd_columnを後々書き直す(column直代入でおｋなように)
        dt = Thaqqa.DataTable.add_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def edit_column(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case get_static_table(self, name) do
      nil ->
        # 将来的にはエラー落ち。
        self

      %Thaqqa.DataTable{name: name} = datatable ->
        # DatTableのedit_columnを後々書き直す。
        dt = Thaqqa.DataTable.edit_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def delete_column(%__MODULE__{} = self, name, column_name) do
    case get_static_table(self, name) do
      nil ->
        # 将来的にはエラー落ち。
        self

      %Thaqqa.DataTable{name: name} = datatable ->
        dt = Thaqqa.DataTable.delete_column(datatable, column_name)
        edit_static_table(self, name, dt)
    end
  end
end
