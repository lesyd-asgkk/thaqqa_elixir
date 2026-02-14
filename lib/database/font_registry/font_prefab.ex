defmodule Thaqqa.FontRegisteryPrefab do
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  defstruct fonts: %{}, static_tables: %{}

  def new(fonts, static_tables), do: %__MODULE__{fonts: fonts, static_tables: static_tables}

  defp update_static_tables(%__MODULE__{} = self, st, st_name),
    do: %__MODULE__{self | static_tables: st} |> complement_by_static_table(st_name)

  defp update_fonts(%__MODULE__{} = self, f), do: %__MODULE__{self | fonts: f}

  def init_font(%__MODULE__{} = self, %Thaqqa.Font{name: name} = font) do
    update_fonts(self, Map.put(self, name, font)) |> complement_font(name)
  end

  # こちらは既に存在する場合は反映しない
  # 「一応」エラーを返すverも作っとく。
  # エラー：重なりがあります　的な
  def add_font!(%__MODULE__{} = self, %Thaqqa.Font{} = font) do
    case add_font(self, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def add_font(%__MODULE__{} = self, %Thaqqa.Font{name: name} = font) do
    if get_font(self, name) != nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      # 仮のエラー表示
      else: {:error, "font_conflict"}
  end

  def delete_font!(%__MODULE__{} = self, name) do
    case delete_font(self, name) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def delete_font(%__MODULE__{} = self, name) do
    case Map.get(self.fonts, name) do
      nil -> {:error, "font_not_found"}
      _ -> update_fonts(self, Map.delete(self.fonts, name))
    end
  end

  def get_font(%__MODULE__{} = self, name), do: Map.get(self.fonts, name)
  def get_font_list(%__MODULE__{} = self), do: self.fonts

  def edit_font!(%__MODULE__{} = self, name, %Thaqqa.Font{} = font) do
    case edit_font(self, name, font) do
      {:error, _} -> self
      {:ok, value} -> value
    end
  end

  def edit_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font) do
    if get_font(self, name) != nil,
      do: {:ok, update_fonts(self, Map.put(self.fonts, name, font)) |> complement_font(name)},
      # 仮のエラー表示
      else: {:error, "font_not_found"}
  end

  # overwrite_fontは内部にしか使わないのでエラー処理はない
  defp overwrite_font(%__MODULE__{} = self, name, %Thaqqa.Font{} = font) do
    if get_font(self, name) != nil,
      do: update_fonts(self, Map.put(self.fonts, name, font)),
      else: self
  end

  ## static_table類

  ## static_tableの設定に合わせてfontの仕様を同期させる
  defp complement_table_by_column(
         %__MODULE__{} = self,
         %Thaqqa.DataTable{name: table_name} = datatable,
         column_name
       ) do
    cond do
      get_column(self, table_name, column_name) == [] ->
        DataTable.delete_column(datatable, column_name)

      get_column(self, table_name, column_name) != [] and
          DataTable.get_column(datatable, fn %Column{name: name} -> name == column_name end) == [] ->
        DataTable.add_column!(datatable, column_name)

      true ->
        datatable
    end
  end

  defp complement_table(%__MODULE__{} = self, font_name, table_name) do
    font = get_font(self, font_name)

    if is_nil(font) ||
         get_static_table_list(self) |> Enum.find(fn {k, _} -> k == table_name end) == [] do
      # 更新なし
      self
    else
      # もしlocal_tableが削除された（＝見つからなかった）場合、fontのtableの方も削除する
      if get_static_table_list_local(self)
         |> Enum.find(fn {k, _} -> k == table_name end) == [] do
        overwrite_font(self, font_name, Font.delete_table(font, table_name))
        # 削除処理。
      else
        table = get_table(self, font_name, table_name)

        if is_nil(table) do
          # テーブル自体を補完
          altered_font = Font.add_table(font, get_static_table(self, table_name))
          overwrite_font(self, font_name, altered_font)
        else
          # column毎の補完・削除処理。
          # complement_table_base_on_columnに分離するか。
          altered_font =
            Enum.reduce(get_column_list(self, table_name), font, fn column, font_alt ->
              altered_table = complement_table_by_column(self, table, column.name)
              Font.edit_table(font_alt, table_name, altered_table)
            end)

          overwrite_font(self, font_name, altered_font)
        end

        # 補完処理。
      end
    end
  end

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  defp complement_font(%__MODULE__{} = self, font_name) do
    Enum.reduce(get_static_table_list_local(self), self, fn {table_name, _}, acc ->
      complement_table(self, font_name, table_name)
    end)
  end

  # static_tableの変更に伴ってfontテーブル側を変更する
  defp complement_by_static_table(%__MODULE__{} = self, table_name) do
    Enum.reduce(get_font_list(self), self, fn {font_name, _}, acc ->
      complement_table(self, font_name, table_name)
    end)
  end

  def get_static_table(%__MODULE__{} = self, name), do: Map.get(get_static_table_list(self), name)

  def get_static_table_list(%__MODULE__{} = self), do: self.static_tables

  def get_static_table_list_global(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> val.global end)

  def get_static_table_list_local(%__MODULE__{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> !val.global end)

  def init_static_table(%__MODULE__{} = self, %Thaqqa.DataTable{name: name} = table),
    do: update_static_tables(self, Map.put(get_static_table_list(self), name, table), name)

  def add_static_table!(%__MODULE__{} = self, %Thaqqa.DataTable{} = table) do
    case add_static_table(self, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def add_static_table(%__MODULE__{} = self, %Thaqqa.DataTable{name: name} = table) do
    if get_static_table(self, name) == nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      # 仮エラー
      {:error, "table_conflict"}
    end
  end

  def edit_static_table!(%__MODULE__{} = self, name, %Thaqqa.DataTable{} = table) do
    case edit_static_table(self, name, table) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def edit_static_table(%__MODULE__{} = self, name, %Thaqqa.DataTable{} = table) do
    if get_static_table(self, name) != nil do
      {:ok, update_static_tables(self, Map.put(self.static_tables, name, table), name)}
    else
      # 仮エラー
      {:error, "table_not_found"}
    end
  end

  def delete_static_table!(%__MODULE__{} = self, name) do
    case delete_static_table(self, name) do
      {:error, _} -> self.static_tables
      {:ok, value} -> value
    end
  end

  def delete_static_table(%__MODULE__{} = self, name) do
    case Map.get(self.static_tables, name) do
      nil -> {:error, "table_not_found"}
      _ -> {:ok, update_static_tables(self, Map.delete(self.static_tables, name), name)}
    end
  end

  ## table類 (直接弄れない設定)

  def get_table(%__MODULE__{} = self, fontname, tablename) do
    case get_font(self, fontname) do
      nil -> nil
      font -> Font.get_table(font, tablename)
    end
  end

  # column
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

  def add_column!(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case add_column(self, name, column) do
      {:error, msg} -> self
      {:ok, value} -> value
    end
  end

  def add_column(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case get_static_table(self, name) do
      nil ->
        {:error, "static_table_not_found"}

      %Thaqqa.DataTable{name: name} = datatable ->
        dt = Thaqqa.DataTable.add_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def edit_column!(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case edit_column(self, name, column) do
      {:error, msg} -> self
      {:ok, value} -> value
    end
  end

  def edit_column(%__MODULE__{} = self, name, %Thaqqa.Column{} = column) do
    case get_static_table(self, name) do
      nil ->
        {:error, "static_table_not_found"}

      %Thaqqa.DataTable{name: name} = datatable ->
        dt = Thaqqa.DataTable.edit_column(datatable, column)
        edit_static_table(self, name, dt)
    end
  end

  def delete_column!(%__MODULE__{} = self, name, column_name) do
    case delete_column(self, name, column_name) do
      {:error, msg} -> self
      {:ok, value} -> value
    end
  end

  def delete_column(%__MODULE__{} = self, name, column_name) do
    case get_static_table(self, name) do
      nil ->
        {:error, "static_table_not_found"}

      %Thaqqa.DataTable{name: name} = datatable ->
        Thaqqa.DataTable.delete_column(datatable, column_name)
        |> then(&edit_static_table(self, name, &1))
    end
  end

  #
  def import_as_root(%__MODULE__{} = self, rootdata) when is_map(rootdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
    Enum.reduce_while(rootdata, self, fn {k, v}, acc ->
      import_table(k, v)
      |> case do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, value} -> {:cont, init_static_table(self, value)}
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      value -> {:ok, value}
    end
  end

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "data", "0", "Fontname"])

  def import_as_font(%__MODULE__{} = self, fontdata, filename) when is_map(fontdata) do
    Enum.reduce_while(fontdata, [], fn {k, v}, acc ->
      import_table(k, v)
      |> case do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, value} -> {:cont, acc ++ [value]}
      end
    end)
    |> case do
      {:error, msg} ->
        {:error, msg}

      value ->
        case extract_datatable_name(fontdata) do
          nil -> {:error, "Cannot load font: Fontname is not found"}
          name -> {:ok, init_font(self, Font.new(filename, name, value))}
        end
    end
  end

  def set_precompile_as_root(%__MODULE__{} = self, tablename) do
    # set_precompile_as_root/3をdatatable毎に回す
    self
  end

  def set_precompile_as_root(%__MODULE__{} = self, tablename, data) do
    self
  end

  defp import_table(name, struct) do
    table = DataTable.new(name, Map.get(struct, "global"), nil)

    Enum.reduce_while(struct, table, fn {k, v}, ans ->
      if k == "columnList" do
        column =
          Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
            new_column =
              Column.new(
                Map.get(v_, "name"),
                Map.get(v_, "type") |> String.to_atom(),
                Map.get(v_, "desc", ""),
                Map.get(v_, "order", 0),
                Map.get(v_, "subtype", "none") |> String.to_atom(),
                Map.get(v_, "dev", false)
              )

            if Map.get(v_, "name") == nil or Map.get(v_, "type") == nil,
              do: {:halt, {:error, "name or type is undefined"}},
              else: {:cont, DataTable.add_column!(ans_, new_column)}
          end)

        case column do
          {:error, _msg} -> {:halt, column}
          _ -> {:cont, column}
        end
      else
        if is_map(v) do
          # volatilityとなっている値は追加しません　→ subtypeから考えます
          column_volatility =
            DataTable.get_column(ans, fn %Column{type: type} -> type == :volatility end)
            |> Enum.map(fn %Column{name: name} -> name end)

          data =
            Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
              v_ = Enum.reduce(column_volatility, v_, fn k, ans__ -> Map.put(ans__, k, nil) end)
              data_ = ans_ |> DataTable.init_data(v_)

              case data_ do
                {:error, _msg} -> {:halt, data_}
                {:ok, value} -> {:cont, value}
                _ -> {:cont, data_}
              end
            end)

          case data do
            {:error, _msg} -> {:halt, data}
            _ -> {:cont, data}
          end
        else
          {:cont, ans}
        end
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      value -> {:ok, value}
    end
  end
end
