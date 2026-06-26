defmodule Thaqqa.Bundle.IO do
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable
  alias Thaqqa.FontRegistry.Error, as: Error

  def attach_id(value_map, %DataTable{} = table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, DataTable.get_least_available_id(table))
  end

  def new_from_request(json) when is_map(json) do
    case Bundle.new() |> import_as_root(json["static_tables"]) do
      {:error, _} = err ->
        err

      {:ok, prefab} ->
        Enum.reduce_while(json["fonts"], {:ok, prefab}, fn {_, font}, {:ok, acc_prefab} ->
          # ニ度手間だが、filename情報は不要なのでこのような形としている。

          case import_as_font(acc_prefab, font["table_list"]) do
            {:error, _} = err -> {:halt, err}
            {:ok, acc_prefab} -> {:cont, {:ok, acc_prefab}}
          end
        end)
    end
  end

  def import_as_root(%Bundle{} = self, rootdata) when is_map(rootdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
    with {:ok, prefab} <-
           Enum.reduce_while(rootdata, {:ok, self}, fn {k, v}, {:ok, acc} ->
             case DataTable.import_table(k, v) do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, Bundle.init_static_table(acc, value)}}
             end
           end),
         {:ok, uuid} <- extract_from_bundlesysdata(rootdata, "UUID"),
         {:ok, owner} <- extract_from_bundlesysdata(rootdata, "Owner"),
         {:ok, co_owner} <- extract_from_bundlesysdata(rootdata, "CoOwner"),
         {:ok, static_table_list} <- Bundle.set_precompile_on_root(prefab) do
      %Bundle{
        prefab
        | static_tables: static_table_list,
          uuid: uuid,
          owner: owner,
          co_owner: String.split(co_owner, ",")
      }
      |> init_const_table()
    else
      {:error, _} = err -> err
    end
  end

  defp extract_from_bundlesysdata(data, column) do
    case get_in(data, ["BUNDLESYSDATA", "dataList", "0", column]) do
      nil -> Error.requried_data_not_found(column, "BUNDLESYSDATA")
      name -> {:ok, name}
    end
  end

  defp extract_datatable_name(data) do
    case get_in(data, ["FONTDATA", "dataList", "0", "Fontname"]) do
      nil -> Error.requried_data_not_found("Fontname", "FONTDATA")
      name -> {:ok, name}
    end
  end

  def import_as_font(%Bundle{} = self, fontdata) when is_map(fontdata) do
    with {:ok, table_map} <-
           Enum.reduce_while(fontdata, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
             DataTable.import_table(k, v)
             |> case do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, Map.put(acc, value.name, value)}}
             end
           end),
         {:ok, name} <- extract_datatable_name(fontdata),
         {:ok, prefab_alter} <- {:ok, Bundle.init_font(self, Font.new(name, table_map))},
         {:ok, font} <- Bundle.set_precompile_on_font(prefab_alter, name),
         {:ok, font} <- Bundle.edit_font(prefab_alter, name, font) do
      {:ok, font}
    else
      {:error, _} = err -> err
    end
  end

  def init_const_table(%Bundle{} = prefab),
    do: ConstRegexKhhylTable.set_datalist_hash(prefab)
end
