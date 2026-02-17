defmodule Thaqqa.DataValidator do
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  defp id_validation(%DataTable{} = table, data_alt, _op) do
    column_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st == :id end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, _v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if k_str in column_list,
        do: [Error.edit_locked(k_str, :id) | acc],
        else: [{:ok, nil} | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} -> {:cont, {:ok, acc}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  # TODO:unique_column_conflictはtablenameを反映させるようにする
  # 「editの場合、変更者自身」である場合は当然無視する
  def unique_validation(%DataTable{name: tablename} = table, data_alt, op) do
    column_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in [:name, :id] end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      # 空文字かnilなら許す
      if k_str in column_list and
           DataTable.get_data(
             table,
             &(&1 |> Thaqqa.Data.get_val(k_str) == v and v not in ["", nil])
           ) != [],
         do: [Error.unique_column_conflict(tablename, k_str, v, op) | acc],
         else: [{:ok, nil} | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} -> {:cont, {:ok, acc}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  def column_validation(%DataTable{name: tablename} = table, data_alt, op) do
    column_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in [:name, :id] end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if k_str in column_list,
        do: [{:ok, nil} | acc],
        else: [Error.column_not_found(tablename, k_str, v, op) | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} ->
        {:cont, {:ok, acc}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  defp validate_value_map(value_map, column_list) do
    # ※volatilityの編集拒否はwrapper module側(LetterEditorとか)で行う

    Enum.reduce(column_list, [], fn %Column{name: name, type: type, subtype: subtype} = column,
                                    acc ->
      if Map.has_key?(value_map, name) do
        val = Map.get(value_map, name)

        cond do
          !Column.is_value_valid?(column, val) ->
            [Error.invalid_value_type(val, type) | acc]

          !Column.is_value_range_valid?(column, val) ->
            [Error.invalid_value_range(val, type, subtype) | acc]

          true ->
            [{:ok, nil} | acc]
        end
      else
        [{:ok, nil} | acc]
      end
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} -> {:cont, {:ok, acc}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, value_map}
    end
  end

  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :add = op,
        force
      ) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        if force do
          unique_validation(table, new_value_map, op)
        else
          case column_validation(table, new_value_map, op) do
            {:error, msg} -> {:error, msg}
            {:ok, _} -> unique_validation(table, new_value_map, op)
          end
        end
    end
  end

  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :edit = op,
        _force
      ) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        case id_validation(table, new_value_map, op) do
          {:error, msg} ->
            {:error, msg}

          {:ok, _} ->
            unique_validation(table, new_value_map, op)
        end
    end
  end
end
