defmodule Thaqqa.LetterRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_table(),
    do:
      @lettertable_list
      |> Enum.reduce(%{}, fn k, acc ->
        Map.put(acc, k, FontRegistry.get_static_table(k))
      end)

  def get_vowel_table(), do: Thaqqa.FontRegistry.get_static_table(@vowel)
  def get_consonant_table(), do: Thaqqa.FontRegistry.get_static_table(@consonant)
  def get_punctuation__table(), do: Thaqqa.FontRegistry.get_static_table(@punctuation)

  def get_diacritic_v_table(), do: Thaqqa.FontRegistry.get_static_table(@diacritic_v)
  def get_diacritic_c_table(), do: Thaqqa.FontRegistry.get_static_table(@diacritic_c)
  def get_diacritic_p_table(), do: Thaqqa.FontRegistry.get_static_table(@diacritic_p)

  def get_letter(filter_fun \\ fn _ -> true end),
    do:
      get_table()
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        if v != nil,
          do: Map.put(acc, k, DataTable.get_data(v, filter_fun)),
          else: Map.put(acc, k, [])
      end)

  defp unique_validation_letter(value_map, op) do
    get_table()
    |> Enum.reduce_while([], fn {_k, v}, acc ->
      if v == nil do
        {:cont, [:ok | acc]}
      else
        case DataTable.unique_validation(v, value_map, op) do
          {:error, msg} -> {:halt, {:error, msg}}
          {:ok, _value} -> {:cont, [:ok | acc]}
        end
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      _ -> {:ok}
    end
  end

  defp get_letter_num(filter_fun \\ fn _ -> true end) do
    get_letter(filter_fun)
    |> Enum.reduce(0, fn {_k, v}, acc ->
      acc + length(v)
    end)
  end

  def add_letter!(value_map, table_name) when table_name in @lettertable_list do
    case add_letter(value_map, table_name) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_letter(value_map, table_name) when table_name in @lettertable_list do
    unique_validation_letter(value_map, :add)
    |> case do
      {:error, msg} -> {:error, msg}
      {:ok} -> FontRegistry.get_static_table(table_name) |> DataTable.add_data(value_map)
    end
  end

  def delete_letter!(table_name, filter_fun, safety_num \\ 1) do
    case delete_letter(table_name, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_letter(table_name, filter_fun, safety_num \\ 1) do
    if get_letter_num(filter_fun) > safety_num,
      do: Error.too_many_subject(get_letter(filter_fun), :delete),
      else:
        FontRegistry.get_static_table(table_name)
        |> DataTable.delete_data(filter_fun, safety_num)
  end

  def edit_letter!(value_map, filter_fun, table_name, safety_num \\ 1)
      when table_name in @lettertable_list do
    case edit_letter!(value_map, filter_fun, table_name, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_letter(value_map, table_name, filter_fun, safety_num \\ 1)
      when table_name in @lettertable_list do
    if get_letter_num(filter_fun) > safety_num,
      do: Error.too_many_subject(get_letter(filter_fun), :edit),
      else:
        unique_validation_letter(value_map, :edit)
        |> (case do
              {:error, msg} ->
                {:error, msg}

              {:ok} ->
                FontRegistry.get_static_table(table_name)
                |> DataTable.edit_data(filter_fun, safety_num)
            end)
  end
end
