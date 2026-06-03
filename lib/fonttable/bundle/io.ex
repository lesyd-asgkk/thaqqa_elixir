defmodule Thaqqa.Bundle.IO do
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable
  alias Thaqqa.FontRegistry.Error, as: Error

  def new_from_request(json) when is_map(json) do
    case Bundle.new() |> import_as_root(json["static_tables"]) do
      {:error, _} = err ->
        err

      {:ok, prefab} ->
        Enum.reduce_while(json["fonts"], {:ok, prefab}, fn {_, font}, {:ok, acc_prefab} ->
          # ニ度手間だが、filename情報は不要なのでこのような形としている。

          case import_as_font(acc_prefab, font["table_list"], font["filename"]) do
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
             case import_table(k, v) do
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

  def import_as_font(%Bundle{} = self, fontdata, filename) when is_map(fontdata) do
    with {:ok, prefab} <-
           Enum.reduce_while(fontdata, {:ok, []}, fn {k, v}, {:ok, acc} ->
             import_table(k, v)
             |> case do
               {:error, _} = err -> {:halt, err}
               {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
             end
           end),
         {:ok, name} <- extract_datatable_name(fontdata),
         {:ok, prefab_alter} <- {:ok, Bundle.init_font(self, Font.new(filename, name, prefab))},
         {:ok, font} <- Bundle.set_precompile_on_font(prefab_alter, name),
         {:ok, font} <- Bundle.edit_font(prefab_alter, name, font) do
      {:ok, font}
    else
      {:error, _} = err -> err
    end
  end

  defp build_column_sub(v),
    do:
      Column.new(
        Map.get(v, "name"),
        Map.get(v, "type", "none") |> String.to_atom(),
        Map.get(v, "desc", ""),
        Map.get(v, "order", 0),
        Map.get(v, "subtype", "none") |> String.to_atom(),
        Map.get(v, "dev", false)
      )

  defp build_column(columns, table) do
    Enum.reduce_while(columns, {:ok, table}, fn {_k, v}, {:ok, ans} ->
      Enum.reduce_while(v, {:ok, ans}, fn {_, v_}, {:ok, ans_} ->
        if Map.get(v_, "name") == nil or Map.get(v_, "type") == nil,
          do:
            {:halt,
             Error.requried_status_not_found(%{
               name: Map.get(v_, "name"),
               type: Map.get(v_, "type")
             })},
          else: {:cont, {:ok, DataTable.add_column!(ans_, build_column_sub(v_))}}
      end)
      |> case do
        {:err, _} = err -> {:halt, err}
        {:ok, _} = ok -> {:cont, ok}
      end
    end)
  end

  defp build_datatable(others, table) do
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

  defp import_table(name, struct) do
    table =
      DataTable.new(
        name,
        Map.get(struct, "global"),
        nil,
        Map.get(struct, "compile_rule"),
        Map.get(struct, "single")
      )

    # ↓の順序を変える。かならずcolumnListが先に処理されるように。
    {columns, others} =
      Enum.split_with(struct, fn
        {"columnList", _} -> true
        _ -> false
      end)

    with {:ok, table} <- build_column(columns, table),
         {:ok, table} <- build_datatable(others, table) do
      {:ok, DataTable.sort(table)}
    else
      {:error, _} = err -> err
    end
  end

  defp init_const_table(%Bundle{} = prefab),
    do: ConstRegexKhhylTable.set_datalist_hash(prefab)
end
