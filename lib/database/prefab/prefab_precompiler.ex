# 全設定は使用頻度が想像以上に高くなりそうな上、いくらなんでも現時点で0.5秒近く掛かってるのは結構まずい。
# まずgposなりgsubなりを追加した場合は必ず「set_precompile_as_root_by_data」を使う。
# 単に(ただletter情報を変えたetcでは)リアルタイム反映をせず、
# テスト動作、保存時にprecompilerを呼び出す仕様とするか？
# それかいっそ並列対応して時短するか。時間としては相応に軽くなるはず。
# 追伸：並列対応した所何故か時間が伸びた。

defmodule Thaqqa.PrefabCompiler do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistry.Error, as: Error

  defp reduce_while_ok(enum, acc, fun) when is_function(fun) do
    Enum.reduce_while(enum, {:ok, acc}, fn item, {:ok, acc} ->
      case fun.(item, acc) do
        {:error, _} = err -> {:halt, err}
        {:ok, value} -> {:cont, {:ok, value}}
      end
    end)
  end

  def set_precompile_as_root(%Prefab{} = self) do
    reduce_while_ok(Prefab.get_static_table_list(self), self, fn {tablename, _}, acc ->
      set_precompile_as_root_by_table(acc, tablename)
    end)
  end

  def set_precompile_as_root_by_table(%Prefab{} = self, tablename) do
    case Prefab.get_static_table(self, tablename) do
      nil ->
        Error.table_not_found(tablename)

      table ->
        reduce_while_ok(table.data_list, self, fn data, acc ->
          set_precompile_internal(acc, Prefab.get_static_table(acc, tablename), data)
        end)
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
        {:error, _} = err -> err
        {:ok, prefab} -> {:ok, prefab |> Prefab.sort_as_font_table_if_enable(font, tablename)}
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
    case Data.set_precompile(data, table, self) do
      {:error, _} = err ->
        err

      {:ok, %Data{} = alter_data} ->
        if data == alter_data do
          {:ok, self}
        else
          alter_table = DataTable.edit_data!(table, data, alter_data)

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
    case Data.set_precompile(data, table, self) do
      {:error, _} = err ->
        err

      {:ok, %Data{} = alter_data} ->
        if alter_data == data do
          {:ok, self}
        else
          alter_table = DataTable.edit_data!(table, data, alter_data)
          alter_font = Font.edit_table(font, tablename, alter_table)
          {:ok, Prefab.edit_font_if_enable(self, fontname, alter_font)}
        end
    end
  end

  ### 以降は一斉変換用に拵えたコード
  # 単純にTask.asyncでは重たくなるので(※600件程度)
  # 次はprocessとして書き換えてみる

  def set_precompile_stream(%Prefab{static_tables: static_tables, fonts: fonts} = self) do
    with {:ok, static_tables_alt} <-
           Enum.reduce_while(static_tables, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
             case set_precompile_internal_stream_as_datatable(self, value) do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
             end
           end),
         {:ok, fonts_alt} <-
           Enum.reduce_while(fonts, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
             case set_precompile_internal_stream_as_font(self, value) do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
             end
           end) do
      {:ok, %Prefab{self | static_tables: static_tables_alt, fonts: fonts_alt}}
    else
      {:error, _} = err -> err
    end
  end

  defp set_precompile_internal_stream_as_font(
         %Prefab{} = self,
         %Font{table_list: table_list} = font
       ) do
    Task.async_stream(
      table_list,
      fn table ->
        set_precompile_internal_stream_as_datatable(self, table)
      end
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, table}}, {:ok, acc} -> {:cont, {:ok, [table | acc]}}
      {:ok, {:error, _} = err}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, table_list} -> {:ok, %Font{font | table_list: table_list}}
      {:error, _} = err -> err
    end
  end

  defp set_precompile_internal_stream_as_datatable(
         %Prefab{} = self,
         %DataTable{data_list: data_list} = table
       ) do
    Task.async_stream(data_list, fn data -> Data.set_precompile(data, table, self) end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, data}}, {:ok, acc} -> {:cont, {:ok, [data | acc]}}
      {:ok, {:error, _} = err}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, data_list} -> {:ok, %DataTable{table | data_list: data_list}}
      {:error, _} = err -> err
    end
  end
end
