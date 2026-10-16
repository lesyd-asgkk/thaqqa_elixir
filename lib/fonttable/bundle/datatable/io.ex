defmodule Thaqqa.DataTable.IO do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

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

  def import_table(name, struct) do
    table =
      DataTable.new(
        name,
        Map.get(struct, "global", false),
        Map.get(struct, "static", false),
        Map.get(struct, "compile_rule", "none"),
        Map.get(struct, "single", false)
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
end
