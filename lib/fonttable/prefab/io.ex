defmodule Thaqqa.FontRegistryPrefab.IO do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab.ConstRegexKhhylTable, as: ConstRegexKhhylTable
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.StaticTableList, as: StaticTableList
  alias Thaqqa.Filename, as: Filename

  defp read_and_decode_json(file_path) do
    case File.read(file_path) do
      {:error, reason} -> {:error, reason}
      {:ok, json} -> Jason.decode(json)
    end
  end

  defp extract_root(data) do
    case get_in(data, ["root"]) do
      nil -> Error.requried_data_not_found("root", nil)
      otherwise -> {:ok, otherwise}
    end
  end

  defp extract_uuid(data) do
    case get_in(data, ["uuid"]) do
      nil -> Error.requried_data_not_found("uuid", nil)
      otherwise -> {:ok, otherwise}
    end
  end

  def import_from_internal_folder(%Prefab{} = self, uuid_list) do
    uuid_list = Enum.map(uuid_list, fn uuid -> "uuid-" <> to_string(uuid) <> ".json" end)

    file_path_list =
      Path.wildcard(Filename.font_folder() <> "*")
      |> Enum.filter(&(Path.basename(&1) in uuid_list))

    Enum.reduce_while(file_path_list, {:ok, self}, fn file_path, {:ok, acc_prefab} ->
      with {:ok, json} <- read_and_decode_json(file_path),
           {:ok, is_root} <- extract_root(json),
           {:ok, uuid} <- extract_uuid(json),
           {:ok, _} = acc <-
             if(is_root,
               do: import_as_root(acc_prefab, json, uuid),
               else: import_as_font(acc_prefab, json, uuid)
             ) do
        {:cont, acc}
      else
        {:error, _} = err -> err
      end
    end)
  end

  def new_from_request(json) when is_map(json) do
    case Prefab.new(%{}, %{}) |> import_as_root(json["static_tables"], json["uuid"]) do
      {:error, _} = err ->
        err

      {:ok, prefab} ->
        Enum.reduce_while(json["fonts"], {:ok, prefab}, fn {_, font}, {:ok, acc_prefab} ->
          # ニ度手間だが、uuid情報は一旦不要なのでこのような形としている。

          case import_as_font(acc_prefab, font["table_list"], font["uuid"]) do
            {:error, _} = err -> {:halt, err}
            {:ok, acc_prefab} -> {:cont, {:ok, acc_prefab}}
          end
        end)
    end
  end

  def import_as_root(%Prefab{} = self, rootdata, uuid) when is_map(rootdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
    # root,uuidについては処理に不要なデータなので削除
    rootdata = Map.delete(rootdata, "uuid") |> Map.delete("root")

    with {:ok, static_table_list} <-
           Enum.reduce_while(rootdata, {:ok, []}, fn {k, v}, {:ok, acc} ->
             import_table(k, v)
             |> case do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, [value | acc]}}
             end
           end),
         {:ok, name} <-
           extract_datatable_name(rootdata),
         prefab_alter <-
           Prefab.init_static_table_list(self, StaticTableList.new(uuid, name, static_table_list)),
         {:ok, font} <- Prefab.set_precompile_on_root(prefab_alter) do
      Prefab.edit_static_table(prefab_alter, name, font)
    else
      {:error, _} = err -> err
    end
  end

  defp extract_datatable_name(data) do
    case get_in(data, ["FONTDATA", "dataList", "0", "Fontname"]) do
      nil -> Error.requried_data_not_found("Fontname", "FONTDATA")
      otherwise -> {:ok, otherwise}
    end
  end

  def import_as_font(%Prefab{} = self, fontdata, uuid) when is_map(fontdata) do
    # uuidについては処理に不要なデータなので削除
    # ※TODO: edit_fontなどのnameはuuidを直接参照することと…しなくても問題なさそう（1:1に決まるので）
    fontdata = Map.delete(fontdata, "uuid") |> Map.delete("root")

    with {:ok, table_list} <-
           Enum.reduce_while(fontdata, {:ok, []}, fn {k, v}, {:ok, acc} ->
             import_table(k, v)
             |> case do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, [value | acc]}}
             end
           end),
         {:ok, name} <-
           extract_datatable_name(fontdata),
         prefab_alter <- Prefab.init_font(self, Font.new(uuid, name, table_list)),
         {:ok, font} <- Prefab.set_precompile_on_font(prefab_alter, name) do
      Prefab.edit_font(prefab_alter, name, font)
    else
      {:error, _} = err -> err
    end
  end

  defp import_column(v),
    do:
      Column.new(
        Map.get(v, "name"),
        Map.get(v, "type", "none") |> String.to_atom(),
        Map.get(v, "desc", ""),
        Map.get(v, "order", 0),
        Map.get(v, "subtype", "none") |> String.to_atom(),
        Map.get(v, "dev", false)
      )

  defp import_table(name, struct, uuid \\ nil) do
    table =
      DataTable.new(
        name,
        Map.get(struct, "global"),
        Map.get(struct, "compile_rule"),
        Map.get(struct, "single"),
        uuid
      )

    # ↓の順序を変える。かならずcolumnListが先に処理されるように。
    {columns, others} =
      Enum.split_with(struct, fn
        {"columnList", _} -> true
        _ -> false
      end)

    Enum.reduce_while(columns, {:ok, table}, fn {_k, v}, {:ok, ans} ->
      Enum.reduce_while(v, {:ok, ans}, fn {_, v_}, {:ok, ans_} ->
        if Map.get(v_, "name") == nil or Map.get(v_, "type") == nil,
          do:
            {:halt,
             Error.requried_status_not_found(%{
               name: Map.get(v_, "name"),
               type: Map.get(v_, "type")
             })},
          else: {:cont, {:ok, DataTable.add_column!(ans_, import_column(v_))}}
      end)
      |> case do
        {:error, _} = err -> {:halt, err}
        {:ok, table} -> {:cont, {:ok, table}}
      end
    end)
    |> case do
      {:error, _} = err ->
        {:halt, err}

      {:ok, table} ->
        Enum.reduce_while(others, {:ok, table}, fn {_k, v}, {:ok, ans} ->
          if is_map(v) do
            # volatilityとなっている値は追加しない（新たに計算し直す）
            column_volatility =
              DataTable.get_column(ans, fn %Column{type: type} -> type == :volatility end)
              |> Enum.map(fn %Column{name: name} -> name end)

            Enum.reduce_while(v, {:ok, ans}, fn {_, v_}, {:ok, ans_} ->
              v_ = Enum.reduce(column_volatility, v_, fn k, ans__ -> Map.put(ans__, k, nil) end)

              ans_
              |> DataTable.init_data(v_)
              |> case do
                {:error, _} = err -> {:halt, err}
                {:ok, value} -> {:cont, {:ok, value}}
              end
            end)
            |> case do
              {:error, _} = err -> {:halt, err}
              {:ok, table} -> {:cont, {:ok, table}}
            end
          else
            {:cont, {:ok, ans}}
          end
        end)
    end
    |> case do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.sort(table)}
    end
  end

  defp init_const_table(%Prefab{} = prefab),
    do: ConstRegexKhhylTable.set_datalist_hash(prefab)
end
