defmodule Thaqqa.Bundle.LetterTable.DataMapValidator do
  alias Thaqqa.Bundle.LetterTable, as: LetterTable
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.DataTable.DataMapValidator, as: DataMapValidator
  use Thaqqa.DataTable.Const

  def unique_letter_validation(
        %Bundle{} = prefab,
        value_map,
        table_name,
        op,
        subject_data \\ nil
      ) do
    case LetterTable.get_table_all(prefab) do
      {:error, _} = err ->
        err

      {:ok, table} ->
        Enum.reduce_while(table, [], fn {k, v}, acc ->
          if v == nil do
            {:cont, [:ok | acc]}
          else
            # IDだけは全てのテーブルと照合せず、table_nameの個体とのみ判断
            value_map = if table_name == k, do: value_map, else: Map.delete(value_map, @id)

            case DataMapValidator.unique_validation(v, value_map, op, subject_data) do
              {:error, _} = err -> {:halt, err}
              {:ok, _value} -> {:cont, [:ok | acc]}
            end
          end
        end)
        |> case do
          {:error, _} = err -> err
          _ -> :ok
        end
    end
  end
end
