defmodule Thaqqa.LetterRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry

  use Thaqqa.DataTable.Const

  def get_table(),
    do:
      @lettertable_list
      |> Enum.reduce(%{}, fn k, acc ->
        Map.put(acc, k, FontRegistry.get_static_table(k))
      end)

  def get_letter(filter_fun \\ fn _ -> true end),
    do:
      get_table()
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        if v != nil,
          do: Map.put(acc, k, DataTable.get_data(v, filter_fun)),
          else: Map.put(acc, k, [])
      end)

  defp unique_validation_letter(value_map, op),
    do:
      get_table()
      |> Enum.reduce_while(%{}, fn {k, v}, acc ->
        case DataTable.unique_validation(v, value_map, op) do
          {:error, msg} -> {:halt, {:error, msg}}
          {:ok, value} -> {:cont, {:ok}}
        end
      end)

  def add_letter!(value_map, table_name) when table_name in @lettertable_list do
    case add_letter!(value_map, table_name) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_letter(value_map, table_name) when table_name in @lettertable_list do
    unique_validation_letter(value_map, :add)
    |> case do
      {:error, msg} -> {:error, msg}
      {:ok, val} -> FontRegistry.get_static_table(table_name) |> DataTable.add_data(value_map)
    end
  end

  # todo:delete,editの仕様変更につきここも個別errorに対応する
  def delete_letter(filter_fun),
    do:
      get_table()
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        table_ = DataTable.delete_data(v, filter_fun)
        Map.put(acc, k, table_)
      end)

  def edit_letter!(value_map, filter_fun, table_name) when table_name in @lettertable_list do
    case add_letter!(value_map, table_name) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_letter(value_map, filter_fun) do
    unique_validation_letter(value_map, :edit)
    |> case do
      {:error, msg} ->
        {:error, msg}

      {:ok, val} ->
        get_letter(filter_fun)
        |> Enum.reduce_while(%{}, fn {k, v}, acc ->
          if v == [] do
            {:cont, {:ok, acc}}
          else
            table_ =
              FontRegistry.get_static_table(k) |> DataTable.edit_data(filter_fun, value_map)

            case table_ do
              {:error, msg} -> {:halt, {:error, msg}}
              {:ok, value} -> {:cont, {:ok, Map.put(acc, k, table_)}}
            end
          end
        end)
    end
    |> case do
      {:error, msg} -> {:error, msg}
      {:ok, val} -> {:ok, val}
    end
  end
end
