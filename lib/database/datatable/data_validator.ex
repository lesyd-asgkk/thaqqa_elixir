defmodule Thaqqa.DataValidator do
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  # こちらも同じく、editの場合は端折る
  defp id_validation(%DataTable{} = table, data_alt, _op, subject_data \\ nil) do
    column_set =
      DataTable.get_column(table, fn %Column{subtype: st} -> st == :id end)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    Enum.reduce_while(data_alt, nil, fn {k, v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if MapSet.member?(column_set, k_str) and Thaqqa.Data.get_val(subject_data, k_str) != v,
        do: {:halt, Error.edit_locked(k_str, :id)},
        else: {:cont, nil}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, nil}
    end
  end

  # TODO:unique_column_conflictはtablenameを反映させるようにする
  # 「editの場合、変更者自身」である場合と全く同じ値は無視するように変更
  #
  def unique_validation(%DataTable{name: tablename} = table, data_alt, op, subject_data \\ nil) do
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
           ) != [] and Thaqqa.Data.get_val(subject_data, k_str) != v,
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

  # 追加時、最低限idがあるか(ないと破綻するので)
  def column_validation(%DataTable{name: tablename} = table, data_alt, op) do
    column_validate_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in [:name, :id] end)
      |> Enum.map(fn %Column{name: name} -> name end)

    column_list =
      Enum.reduce(data_alt, [], fn {k, _v}, acc ->
        if is_atom(k), do: Atom.to_string(k), else: [k | acc]
      end)

    if MapSet.subset?(MapSet.new(column_validate_list), MapSet.new(column_list)) do
      {:ok, nil}
    else
      column_list =
        Enum.reduce(column_validate_list, [], fn k, acc ->
          if k in column_list,
            do: acc,
            else: [acc | k]
        end)

      Error.column_not_found(tablename, column_list, op)
    end
  end

  defp validate_value_map(value_map, column_list) do
    # ※volatilityの編集拒否はwrapper module側(LetterEditorとか)で行う

    Enum.reduce_while(column_list, nil, fn %Column{name: name, type: type, subtype: subtype} =
                                             column,
                                           acc ->
      if Map.has_key?(value_map, name) do
        val = Map.get(value_map, name)

        cond do
          !Column.is_value_valid?(column, val) ->
            {:halt, Error.invalid_value_type(val, type)}

          !Column.is_value_range_valid?(column, val) ->
            {:halt, Error.invalid_value_range(val, type, subtype)}

          true ->
            {:cont, nil}
        end
      else
        {:cont, nil}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, value_map}
    end
  end

  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :add = op
      ) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        case column_validation(table, new_value_map, op) do
          {:error, msg} -> {:error, msg}
          {:ok, _} -> unique_validation(table, new_value_map, op)
        end
    end
  end

  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :edit = op,
        subject_data
      ) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        case id_validation(table, new_value_map, op, subject_data) do
          {:error, msg} -> {:error, msg}
          {:ok, _} -> unique_validation(table, new_value_map, op, subject_data)
        end
    end
  end
end
