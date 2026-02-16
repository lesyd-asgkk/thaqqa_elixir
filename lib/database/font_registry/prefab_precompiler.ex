defmodule Thaqqa.PrefabCompiler do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column

  def set_precompile_as_root(%Prefab{} = self) do
    Enum.reduce_while(Prefab.get_static_table_list(self), self, fn {tablename, _}, acc ->
      case set_precompile_as_root_by_table(acc, tablename) do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, value} -> {:cont, value}
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      otherwize -> {:ok, otherwize}
    end
  end

  def set_precompile_as_root_by_table(%Prefab{} = self, tablename) do
    case Prefab.get_static_table(self, tablename) do
      nil ->
        {:error, "table_not_found"}

      table ->
        Enum.reduce_while(table.data_list, self, fn data, acc ->
          {:ok, t} = set_precompile_internal(acc, table, data)

          # 　何故かここで機能していない

          case set_precompile_internal(acc, Prefab.get_static_table(acc, tablename), data) do
            {:error, msg} -> {:halt, {:error, msg}}
            {:ok, value} -> {:cont, value}
          end
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          otherwize -> {:ok, otherwize}
        end
    end
  end

  def set_precompile_as_root_by_data(%Prefab{} = self, tablename, %Data{} = data) do
    case Prefab.get_static_table(self, tablename) do
      nil -> {:error, "table_not_found"}
      table -> set_precompile_internal(self, nil, table, data)
    end
  end

  def set_precompile_as_font(%Prefab{} = self, fontname) do
    font = Prefab.get_font(self, fontname)

    if font == nil do
      {:error, "font_not_found"}
    else
      Enum.reduce_while(font.table_list, self, fn %DataTable{name: tablename}, acc ->
        case set_precompile_as_font_by_table(acc, fontname, tablename) do
          {:error, msg} -> {:halt, {:error, msg}}
          {:ok, value} -> {:cont, value}
        end
      end)
      |> case do
        {:error, msg} -> {:error, msg}
        otherwize -> {:ok, otherwize}
      end
    end
  end

  def set_precompile_as_font_by_table(%Prefab{} = self, fontname, tablename) do
    case {Prefab.get_font(self, fontname), Prefab.get_table(self, fontname, tablename)} do
      {nil, _} ->
        {:error, "font_not_found"}

      {_, nil} ->
        {:error, "table_not_found"}

      {font, table} ->
        Enum.reduce_while(table.data_list, self, fn data, acc ->
          case set_precompile_internal(
                 acc,
                 Prefab.get_font(acc, fontname),
                 Prefab.get_table(acc, fontname, tablename),
                 data
               ) do
            {:error, msg} -> {:halt, {:error, msg}}
            {:ok, value} -> {:cont, value}
          end
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          otherwize -> {:ok, otherwize}
        end
    end
  end

  def set_precompile_as_font_by_data(%Prefab{} = self, fontname, tablename, %Data{} = data) do
    case {Prefab.get_font(self, fontname), Prefab.get_table(self, fontname, tablename)} do
      {nil, _} -> {:error, "font_not_found"}
      {_, nil} -> {:error, "table_not_found"}
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

      {:ok, %Data{value_list: v}} ->
        alter_table =
          DataTable.edit_data!(table, &(&1 == data), v |> Map.delete("ID") |> Map.delete("Name"))

        {:ok, Prefab.edit_static_table_if_enable(self, tablename, alter_table)}
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

      {:ok, %Data{value_list: v}} ->
        alter_table =
          DataTable.edit_data!(table, &(&1 == data), v |> Map.delete("ID") |> Map.delete("Name"))

        alter_font = Font.edit_table(font, tablename, alter_table)
        {:ok, Prefab.edit_font_if_enable(self, fontname, alter_font)}
    end
  end
end
