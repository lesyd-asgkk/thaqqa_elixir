defmodule Thaqqa.PrefabIO do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  alias Thaqqa.FontRegistry.Error, as: Error

  def import_as_root(%Prefab{} = self, rootdata) when is_map(rootdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
    Enum.reduce_while(rootdata, {:ok, self}, fn {k, v}, {:ok, acc} ->
      import_table(k, v)
      |> case do
        {:error, _} = err -> {:halt, err}
        {:ok, value} -> {:cont, {:ok, Prefab.init_static_table(acc, value)}}
      end
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, prefab} ->
        case Prefab.set_precompile_as_root(prefab) do
          {:error, reason} -> {:error, reason}
          {:ok, prefab} -> init_const_table(prefab)
        end
    end
  end

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "dataList", "0", "Fontname"])

  def import_as_font(%Prefab{} = self, fontdata, filename) when is_map(fontdata) do
    Enum.reduce_while(fontdata, {:ok, []}, fn {k, v}, {:ok, acc} ->
      import_table(k, v)
      |> case do
        {:error, _} = err -> {:halt, err}
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
      end
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, prefab} ->
        case extract_datatable_name(fontdata) do
          nil ->
            Error.requried_data_not_found("Fontname", "FONTDATA")

          name ->
            Prefab.init_font(self, Font.new(filename, name, prefab))
            |> Prefab.set_precompile_as_font(name)
        end
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
    do: ConstRegexManager.set_datalist_hash(prefab)
end
