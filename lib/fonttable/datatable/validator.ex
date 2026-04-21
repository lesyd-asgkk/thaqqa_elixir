defmodule Thaqqa.DataTable.DataMapValidator do
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  use Thaqqa.DataTable.Const

  # ID系統（何がなんでも編集不能）を編集しようとしたか確かめる関数。
  defp id_validation(%DataTable{} = table, new_value_map, _op, subject_data)
       when is_map(new_value_map) do
    column_set =
      DataTable.get_column(table, fn %Column{subtype: st} -> st == @id_subtype end)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    Enum.find_value(new_value_map, fn {k, v} ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if MapSet.member?(column_set, k_str) and Thaqqa.Data.get_value(subject_data, k_str) != v,
        do: {:halt, Error.edit_locked(k_str, @id_subtype)},
        else: {:cont, :ok}
    end)
    |> case do
      {:error, _} = err -> err
      _ -> :ok
    end
  end

  # nameといったunique属性のついてsubtypeに対するvalidation。
  # 重複があったらerror,そうじゃなかったらok
  # 空文字(""。stringの基本的な初期値としている)かnilは重複判定に入れない。Regex_khhylのscript構文にも検知されない仕様。
  def unique_validation(
        %DataTable{name: tablename} = table,
        new_value_map,
        op,
        subject_data \\ nil
      )
      when is_map(new_value_map) do
    column_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in @unique_subtypes end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce_while(new_value_map, :ok, fn {k, v}, _ ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      # 空文字かnilなら素通り。""はRegex_khhylのscript構文にも検知されない。
      if k_str in column_list and
           DataTable.get_data(
             table,
             &(&1 |> Thaqqa.Data.get_value(k_str) == v and v not in ["", nil])
           ) != [] and Thaqqa.Data.get_value(subject_data, k_str) != v,
         do: {:halt, Error.unique_column_conflict(tablename, k_str, v, op)},
         else: {:cont, :ok}
    end)
  end

  # 追加時、最低限idとuniqueタイプのColumnを所持しているか(ないと破綻するので)
  def column_validation(%DataTable{name: tablename} = table, new_value_map, op)
      when is_map(new_value_map) do
    column_validate_list =
      DataTable.get_column(table, fn %Column{subtype: st} -> st in @unique_subtypes end)
      |> Enum.map(fn %Column{name: name} -> name end)

    column_list =
      Enum.reduce(new_value_map, [], fn {k, _}, acc ->
        if is_atom(k), do: Atom.to_string(k), else: [k | acc]
      end)

    # ここは軽量化の為にMapSetに一度変換している。
    # 端的に表現すれば、「「unique_subtypes」に指定しているsubtypeを持つColumnを全て含んでいるか」の判定。
    if MapSet.subset?(MapSet.new(column_validate_list), MapSet.new(column_list)) do
      :ok
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

  # Columnに対して取りうる値であるかの確認。
  defp validate_value_map(value_map, column_list)
       when is_map(value_map) and is_list(column_list) do
    Enum.reduce_while(column_list, :ok, fn %Column{name: name} = column, _ ->
      if Map.has_key?(value_map, name) do
        case Column.validate(column, Map.get(value_map, name)) do
          :ok -> {:cont, :ok}
          {:error, _} = err -> {:halt, err}
        end
      else
        {:cont, :ok}
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
      )
      when is_map(new_value_map) do
    with :ok <- validate_value_map(new_value_map, column_list),
         :ok <- column_validation(table, new_value_map, op),
         :ok <- unique_validation(table, new_value_map, op) do
      :ok
    else
      {:error, _} = err -> err
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
      )
      when is_map(new_value_map) do
    with :ok <- validate_value_map(new_value_map, column_list),
         :ok <- id_validation(table, new_value_map, op, subject_data),
         :ok <- unique_validation(table, new_value_map, op, subject_data) do
      :ok
    else
      {:error, _} = err -> err
    end
  end
end
