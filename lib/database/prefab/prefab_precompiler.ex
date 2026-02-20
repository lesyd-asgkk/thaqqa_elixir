defmodule Thaqqa.PrefabCompiler do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error

  defp reduce_while_ok(enum, acc, fun) do
    Enum.reduce_while(enum, acc, fn item, acc ->
      case fun.(item, acc) do
        {:error, _} = err -> {:halt, err}
        {:ok, value} -> {:cont, value}
      end
    end)
  end

  def set_precompile_as_root(%Prefab{} = self) do
    reduce_while_ok(Prefab.get_static_table_list(self), self, fn {tablename, _}, acc ->
      set_precompile_as_root_by_table(acc, tablename)
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      otherwize -> {:ok, otherwize}
    end
  end

  def set_precompile_as_root_by_table(%Prefab{} = self, tablename) do
    case Prefab.get_static_table(self, tablename) do
      nil ->
        Error.table_not_found(tablename)

      table ->
        reduce_while_ok(table.data_list, self, fn data, acc ->
          set_precompile_internal(acc, Prefab.get_static_table(acc, tablename), data)
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          otherwize -> {:ok, otherwize |> Prefab.sort_as_static(tablename)}
        end
    end
  end

  def set_precompile_as_root_by_data(%Prefab{} = self, tablename, %Data{} = data) do
    case Prefab.get_static_table(self, tablename) do
      nil -> Error.table_not_found(tablename)
      table -> set_precompile_internal(self, nil, table, data)
    end
  end

  def set_precompile_as_font(%Prefab{} = self, fontname) do
    case Prefab.get_font(self, fontname) do
      nil ->
        Error.font_not_found(fontname)

      font ->
        reduce_while_ok(font.table_list, self, fn %DataTable{name: tablename}, acc ->
          set_precompile_as_font_by_table(acc, fontname, tablename)
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          otherwize -> {:ok, otherwize}
        end
    end
  end

  def set_precompile_as_font_by_table(%Prefab{} = self, fontname, tablename) do
    with %Font{} = font <- Prefab.get_font(self, fontname) || Error.font_not_found(fontname),
         %DataTable{} = table <-
           Prefab.get_table(self, fontname, tablename) || Error.table_not_found(tablename) do
      reduce_while_ok(table.data_list, self, fn data, acc ->
        set_precompile_internal(
          acc,
          Prefab.get_font(acc, fontname),
          Prefab.get_table(acc, fontname, tablename),
          data
        )
      end)
      |> case do
        {:error, msg} -> {:error, msg}
        otherwize -> {:ok, otherwize |> Prefab.sort_as_font_table(font, tablename)}
      end
    else
      {:error, _} = err -> err
    end
  end

  def set_precompile_as_font_by_data(%Prefab{} = self, fontname, tablename, %Data{} = data) do
    case {Prefab.get_font(self, fontname), Prefab.get_table(self, fontname, tablename)} do
      {nil, _} -> Error.font_not_found(fontname)
      {_, nil} -> Error.table_not_found(tablename, fontname)
      {font, table} -> set_precompile_internal(self, font, table, data)
    end
  end

  # 加工ロジックについて
  # テーブル側に変換規則を定義させる項目を作る
  # 現状はregex_0,path_0,noneの3通り
  # noneは素通り、regex,pathの場合はnameやの項目を変換する
  # 変換に失敗した場合は返ってきたerrorをそのまま返す
  # internalじゃない方でerrorの処理をする

  defp set_precompile_internal(%Prefab{} = self, %DataTable{} = table, %Data{} = data),
    do: set_precompile_internal(self, nil, table, data)

  defp set_precompile_internal(
         %Prefab{} = self,
         nil,
         %DataTable{name: tablename} = table,
         %Data{} = data
       ) do
    # ここに加工ロジックを追加
    alter_data = Data.set_precompile(data, table)

    case alter_data do
      {:error, msg} ->
        {:error, msg}

      {:ok, %Data{value_list: v} = alter_data_} ->
        if data == alter_data_ do
          {:ok, self}
        else
          alter_table = DataTable.edit_data!(table, data, v)

          {:ok, Prefab.edit_static_table_if_enable(self, tablename, alter_table)}
        end
    end
  end

  defp set_precompile_internal(
         %Prefab{} = self,
         %Font{name: fontname} = font,
         %DataTable{name: tablename} = table,
         %Data{} = data
       ) do
    # ここに加工ロジックを追加

    alter_data = Data.set_precompile(data, table)

    case alter_data do
      {:error, msg} ->
        {:error, msg}

      {:ok, %Data{value_list: v} = alter_data_} ->
        if alter_data_ == data do
          {:ok, self}
        else
          alter_table = DataTable.edit_data!(table, data, v)
          alter_font = Font.edit_table(font, tablename, alter_table)
          {:ok, Prefab.edit_font_if_enable(self, fontname, alter_font)}
        end
    end
  end
end
