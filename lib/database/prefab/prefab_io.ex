defmodule Thaqqa.PrefabIO do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font

  def import_as_root(%Prefab{} = self, rootdata) when is_map(rootdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
    Enum.reduce_while(rootdata, self, fn {k, v}, acc ->
      import_table(k, v)
      |> case do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, value} -> {:cont, Prefab.init_static_table(acc, value)}
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      value -> Prefab.set_precompile_as_root(value)
    end
  end

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "dataList", "0", "Fontname"])

  def import_as_font(%Prefab{} = self, fontdata, filename) when is_map(fontdata) do
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
          nil ->
            # 仮ERROR
            {:error, "Cannot load font: Fontname is not found"}

          name ->
            Prefab.init_font(self, Font.new(filename, name, value))
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

    Enum.reduce_while(columns, table, fn {k, v}, ans ->
      column =
        Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
          if Map.get(v_, "name") == nil or Map.get(v_, "type") == nil,
            do:
              {:halt,
               Error.requried_status_not_found(%{
                 name: Map.get(v_, "name"),
                 type: Map.get(v_, "type")
               })},
            else: {:cont, DataTable.add_column!(ans_, import_column(v_))}
        end)
        |> case do
          {:error, msg} -> {:halt, {:error, msg}}
          otherwize -> {:cont, otherwize}
        end
    end)
    |> case do
      {:error, msg} ->
        {:halt, {:error, msg}}

      table ->
        Enum.reduce_while(others, table, fn {k, v}, ans ->
          if is_map(v) do
            # volatilityとなっている値は追加しません　→ subtypeから考えます
            column_volatility =
              DataTable.get_column(ans, fn %Column{type: type} -> type == :volatility end)
              |> Enum.map(fn %Column{name: name} -> name end)

            data =
              Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
                v_ = Enum.reduce(column_volatility, v_, fn k, ans__ -> Map.put(ans__, k, nil) end)

                ans_
                |> DataTable.add_data(v_)
                |> case do
                  {:error, msg} -> {:halt, {:error, msg}}
                  {:ok, value} -> {:cont, value}
                  value -> {:cont, value}
                end
              end)

            case data do
              {:error, _msg} -> {:halt, data}
              _ -> {:cont, data}
            end
          else
            {:cont, ans}
          end
        end)
        |> case do
          {:error, msg} -> {:error, msg}
          value -> {:ok, value}
        end
    end
  end
end
