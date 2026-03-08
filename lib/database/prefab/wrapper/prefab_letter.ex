# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.LetterManager do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataMapValidator, as: DataMapValidator
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  use Thaqqa.DataTable.Const

  def get_table(%Prefab{} = prefab) do
    Enum.reduce_while(@lettertable_list, {:ok, %{}}, fn k, {:ok, acc} ->
      case Prefab.get_static_table(prefab, k) do
        nil -> {:halt, Error.table_not_found(k)}
        otherwise -> {:cont, {:ok, Map.put(acc, k, otherwise)}}
      end
    end)
  end

  defp get_internal!(%Prefab{} = prefab, table), do: Prefab.get_static_table(prefab, table)
  def get_vowel_table!(%Prefab{} = prefab), do: get_internal!(prefab, @vowel)
  def get_consonant_table!(%Prefab{} = prefab), do: get_internal!(prefab, @consonant)
  def get_punctuation_table!(%Prefab{} = prefab), do: get_internal!(prefab, @punctuation)
  def get_diacritic_v_table!(%Prefab{} = prefab), do: get_internal!(prefab, @diacritic_v)
  def get_diacritic_c_table!(%Prefab{} = prefab), do: get_internal!(prefab, @diacritic_c)
  def get_diacritic_p_table!(%Prefab{} = prefab), do: get_internal!(prefab, @diacritic_p)

  defp get_internal(%Prefab{} = prefab, table) do
    case Prefab.get_static_table(prefab, table) do
      nil -> Error.table_not_found(table)
      table -> {:ok, table}
    end
  end

  def get_vowel_table(%Prefab{} = prefab), do: get_internal(prefab, @vowel)
  def get_consonant_table(%Prefab{} = prefab), do: get_internal(prefab, @consonant)
  def get_punctuation_table(%Prefab{} = prefab), do: get_internal(prefab, @punctuation)
  def get_diacritic_v_table(%Prefab{} = prefab), do: get_internal(prefab, @diacritic_v)
  def get_diacritic_c_table(%Prefab{} = prefab), do: get_internal(prefab, @diacritic_c)
  def get_diacritic_p_table(%Prefab{} = prefab), do: get_internal(prefab, @diacritic_p)

  # get_letterの帰り値を{:ok, table_map}の形にするし
  # get_letterを用いる関数も修正する
  def get_letter!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_letter(prefab, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_letter(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_table(prefab) do
      {:error, _} = err ->
        err

      {:ok, table} ->
        {:ok,
         Enum.reduce(table, %{}, fn {k, v}, acc ->
           if v != nil,
             do: Map.put(acc, k, DataTable.get_data(v, filter_fun)),
             else: Map.put(acc, k, [])
         end)}
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
          _ -> {:ok}
        end
    end
  end

  def add_letter!(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    case add_letter(prefab, value_map, table_name) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_letter(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    with {:ok} <- unique_letter_validation(prefab, value_map, table_name, :add),
         {:ok, %DataTable{} = table} <- get_internal(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, value_map),
         {:ok, %Prefab{} = prefab} <- Prefab.edit_static_table(prefab, table_name, table) do
      {:ok, sort_letter(prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_letter!(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    case delete_letter(prefab, table_name, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_letter(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    with {:ok, %DataTable{} = table} <- get_internal(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Prefab.edit_static_table(prefab, table_name, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_letter!(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    case edit_letter!(prefab, value_map, table_name, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_letter(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list do
    with {:ok} <- unique_letter_validation(prefab, value_map, table_name, :edit, data),
         {:ok, %DataTable{} = table} <- get_internal(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, value_map),
         {:ok, %Prefab{} = prefab} <- Prefab.edit_static_table(prefab, table_name, table) do
      {:ok, sort_letter(prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def sort_letter(%Prefab{} = prefab),
    do:
      Prefab.sort_as_static(prefab, @vowel)
      |> Prefab.sort_as_static(@consonant)
      |> Prefab.sort_as_static(@punctuation)
      |> Prefab.sort_as_static(@diacritic_v)
      |> Prefab.sort_as_static(@diacritic_c)
      |> Prefab.sort_as_static(@diacritic_p)

  def complement(%Prefab{} = prefab) do
    with {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @vowel),
         {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @consonant),
         {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @punctuation),
         {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @diacritic_v),
         {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @diacritic_c),
         {:ok, %Prefab{} = prefab} <- Prefab.complement_by_static_table(prefab, @diacritic_p) do
      {:ok, prefab}
    else
      {:error, _} = err -> err
    end
  end

  defp apply_letter_font_sub(%Prefab{fonts: fonts} = prefab) do
    Enum.reduce_while(fonts, {:ok, prefab}, fn %Font{name: fontname}, {:ok, acc} ->
      case Prefab.set_precompile_as_font(acc, fontname) do
        {:error, _} = err -> {:halt, err}
        {:ok, new_f} -> {:cont, {:ok, Prefab.edit_font_if_enable(acc, fontname, new_f)}}
      end
    end)
  end

  # 変更し終わった後に一括で変更する
  def apply_letter(%Prefab{} = prefab) do
    with {:ok, %Prefab{} = prefab} <- Prefab.set_precompile_as_root(prefab),
         {:ok, %Prefab{} = prefab} <- apply_letter_font_sub(prefab) do
      ConstRegexManager.set_datalist_hash(prefab)
    else
      {:error, _} = err -> err
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
