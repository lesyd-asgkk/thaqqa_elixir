# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.LetterManager do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataValidator, as: DataValidator
  use Thaqqa.DataTable.Const

  def get_table(%Prefab{} = prefab) do
    Enum.reduce_while(@lettertable_list, %{}, fn k, acc ->
      case Prefab.get_static_table(k) do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, val} -> {:cont, Map.put(acc, k, val)}
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      val -> {:ok, val}
    end
  end

  def get_vowel_table(%Prefab{} = prefab), do: Prefab.get_static_table(@vowel)
  def get_consonant_table(%Prefab{} = prefab), do: Prefab.get_static_table(@consonant)
  def get_punctuation__table(%Prefab{} = prefab), do: Prefab.get_static_table(@punctuation)

  def get_diacritic_v_table(%Prefab{} = prefab), do: Prefab.get_static_table(@diacritic_v)
  def get_diacritic_c_table(%Prefab{} = prefab), do: Prefab.get_static_table(@diacritic_c)
  def get_diacritic_p_table(%Prefab{} = prefab), do: Prefab.get_static_table(@diacritic_p)

  # get_letterの帰り値を{:ok, table_map}の形にするし
  # get_letterを用いる関数も修正する
  def get_letter(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_table(prefab) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        Enum.reduce(table, %{}, fn {k, v}, acc ->
          if v != nil,
            do: Map.put(acc, k, DataTable.get_data(v, filter_fun)),
            else: Map.put(acc, k, [])
        end)
    end
  end

  defp unique_letter_validation(
         %Prefab{} = prefab,
         value_map,
         table_name,
         op,
         subject_data \\ nil
       ) do
    case get_table(prefab) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        Enum.reduce_while(table, [], fn {k, v}, acc ->
          if v == nil do
            {:cont, [:ok | acc]}
          else
            # IDだけは全てのテーブルと照合せず、table_nameの個体とのみ判断
            value_map = if table_name == k, do: value_map, else: Map.delete(value_map, @id)

            case DataValidator.unique_validation(v, value_map, op, subject_data) do
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
  end

  # 将来的に一括変更・一括削除をする場合に備えて保存
  # defp get_letter_num(filter_fun \\ fn _ -> true end) do
  #   get_letter(filter_fun)
  #   |> Enum.reduce(0, fn {_k, v}, acc ->
  #     acc + length(v)
  #   end)
  # end

  def add_letter!(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    case add_letter(prefab, value_map, table_name) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_letter(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    case unique_letter_validation(prefab, value_map, table_name, :add) do
      {:error, msg} -> {:error, msg}
      {:ok} -> Prefab.get_static_table(prefab, table_name) |> DataTable.add_data(value_map)
    end
  end

  def delete_letter!(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data) do
    case delete_letter(prefab, table_name, data) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_letter(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data) do
    Prefab.get_static_table(prefab, table_name)
    |> DataTable.delete_data(data)
  end

  def edit_letter!(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    case edit_letter!(prefab, value_map, table_name, data) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_letter(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    unique_letter_validation(prefab, value_map, table_name, :edit, data)
    |> case do
      {:error, msg} ->
        {:error, msg}

      {:ok} ->
        Prefab.get_static_table(prefab, table_name)
        |> DataTable.edit_data(data, value_map)
    end
  end
end
