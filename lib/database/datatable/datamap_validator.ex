# DataMapValidatorに変更

defmodule Thaqqa.DataMapValidator do
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  use Thaqqa.DataTable.Const

  # こちらも同じく、editの場合は端折る
  defp id_validation(%DataTable{} = table, data_alt, _op, subject_data) do
    column_set =
      DataTable.get_column(table, fn %Column{subtype: st} -> st == @id_subtype end)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    Enum.find_value(data_alt, fn {k, v} ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if MapSet.member?(column_set, k_str) and Thaqqa.Data.get_value(subject_data, k_str) != v,
        do: {:halt, Error.edit_locked(k_str, @id_subtype)},
        else: {:cont, nil}
    end)
    |> case do
      {:error, _} = err -> err
      _ -> {:ok, nil}
    end
  end

  def unique_validation(%DataTable{name: tablename} = table, data_alt, op, subject_data \\ nil) do
    column_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in @unique_subtypes end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce_while(data_alt, {:ok, nil}, fn {k, v}, {:ok, _} ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      # 空文字かnilなら許す
      if k_str in column_list and
           DataTable.get_data(
             table,
             &(&1 |> Thaqqa.Data.get_value(k_str) == v and v not in ["", nil])
           ) != [] and Thaqqa.Data.get_value(subject_data, k_str) != v,
         do: {:halt, Error.unique_column_conflict(tablename, k_str, v, op)},
         else: {:cont, {:ok, nil}}
    end)
  end

  # 追加時、最低限idがあるか(ないと破綻するので)
  def column_validation(%DataTable{name: tablename} = table, data_alt, op) do
    column_validate_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in @unique_subtypes end)
      |> Enum.map(fn %Column{name: name} -> name end)

    column_list =
      Enum.reduce(data_alt, [], fn {k, _}, acc ->
        if is_atom(k), do: Atom.to_string(k), else: [k | acc]
      end)

    # 軽量化の為にMapSetに一度変換している
    if MapSet.subset?(MapSet.new(column_validate_list), MapSet.new(column_list)) do
      {:ok, nil}
    else
      column_list =
        Enum.reduce(column_validate_list, [], fn k, acc ->
          if k in column_list,
            do: acc,
            else: [k | acc]
        end)

      Error.column_not_found(tablename, column_list, op)
    end
  end

  defp validate_value_map(value_map, column_list) do
    # ※volatilityの編集拒否はwrapper module側(LetterEditorとか)で行う

    Enum.reduce_while(column_list, {:ok, value_map}, fn %Column{
                                                          name: name,
                                                          type: type,
                                                          subtype: subtype
                                                        } =
                                                          column,
                                                        {:ok, _} ->
      if Map.has_key?(value_map, name) do
        case Column.validate(column, Map.get(value_map, name)) do
          :ok -> {:cont, {:ok, value_map}}
          {:error, _} = err -> {:halt, err}
        end
      else
        {:cont, {:ok, value_map}}
      end
    end)
  end

  # 受け取ったvalue_mapのチェック
  # columnチェック(idの存在チェック。ないと破綻するので)
  # unique列チェック
  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :add = op
      ) do
    with {:ok, _} <- validate_value_map(new_value_map, column_list),
         {:ok, _} <- column_validation(table, new_value_map, op),
         {:ok, _} <- unique_validation(table, new_value_map, op) do
      {:ok, nil}
    end
  end

  # 受け取ったvalue_mapのチェック
  # idチェック
  # unique列チェック
  def validate_data(
        %DataTable{column_list: column_list} = table,
        new_value_map,
        :edit = op,
        subject_data
      ) do
    with {:ok, _} <- validate_value_map(new_value_map, column_list),
         {:ok, _} <- id_validation(table, new_value_map, op, subject_data),
         {:ok, _} <- unique_validation(table, new_value_map, op, subject_data) do
      {:ok, nil}
    end
  end
end
