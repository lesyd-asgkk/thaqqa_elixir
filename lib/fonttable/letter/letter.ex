defmodule Thaqqa.FontRegistryPrefab.LetterTable do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.LetterTable.Validator, as: Validator
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  alias Thaqqa.FontRegistryPrefab.LetterTable.Op, as: Op
  use Thaqqa.DataTable.Const

  def get_table_all(%Prefab{} = prefab) do
    Enum.reduce_while(@lettertable_list, {:ok, %{}}, fn k, {:ok, acc} ->
      case get_letter_table_from_name(prefab, k) do
        {:error, _} = err -> {:halt, err}
        {:ok, datatable} -> {:cont, {:ok, Map.put(acc, k, datatable)}}
      end
    end)
  end

  def get_letter_table_from_name!(%Prefab{} = prefab, table),
    do: Prefab.get_static_table(prefab, table)

  def get_vowel_table!(%Prefab{} = prefab), do: get_letter_table_from_name!(prefab, @vowel)

  def get_consonant_table!(%Prefab{} = prefab),
    do: get_letter_table_from_name!(prefab, @consonant)

  def get_punctuation_table!(%Prefab{} = prefab),
    do: get_letter_table_from_name!(prefab, @punctuation)

  def get_diacritic_v_table!(%Prefab{} = prefab),
    do: get_letter_table_from_name!(prefab, @diacritic_v)

  def get_diacritic_c_table!(%Prefab{} = prefab),
    do: get_letter_table_from_name!(prefab, @diacritic_c)

  def get_diacritic_p_table!(%Prefab{} = prefab),
    do: get_letter_table_from_name!(prefab, @diacritic_p)

  def get_letter_table_from_name!(%Prefab{} = prefab, table_name)
      when table_name in @lettertable_list do
    case get_letter_table_from_name(prefab, table_name) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_letter_table_from_name(%Prefab{} = prefab, table_name)
      when table_name in @lettertable_list,
      do: Prefab.get_static_table_or_error(prefab, table_name)

  def get_vowel_table(%Prefab{} = prefab), do: get_letter_table_from_name(prefab, @vowel)
  def get_consonant_table(%Prefab{} = prefab), do: get_letter_table_from_name(prefab, @consonant)

  def get_punctuation_table(%Prefab{} = prefab),
    do: get_letter_table_from_name(prefab, @punctuation)

  def get_diacritic_v_table(%Prefab{} = prefab),
    do: get_letter_table_from_name(prefab, @diacritic_v)

  def get_diacritic_c_table(%Prefab{} = prefab),
    do: get_letter_table_from_name(prefab, @diacritic_c)

  def get_diacritic_p_table(%Prefab{} = prefab),
    do: get_letter_table_from_name(prefab, @diacritic_p)

  # get_letterの帰り値を{:ok, table_map}の形にするし
  # get_letterを用いる関数も修正する
  def get_letter!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_letter(prefab, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_letter(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_table_all(prefab) do
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

  def add_letter!(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list, do: Op.add_letter!(prefab, value_map, table_name)

  def add_letter(%Prefab{} = prefab, value_map, table_name)
      when table_name in @lettertable_list, do: Op.add_letter(prefab, value_map, table_name)

  def delete_letter!(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list,
      do: Op.delete_letter!(prefab, table_name, data)

  def delete_letter(%Prefab{} = prefab, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list,
      do: Op.delete_letter(prefab, table_name, data)

  def edit_letter!(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list,
      do: Op.edit_letter!(prefab, value_map, table_name, data)

  def edit_letter(%Prefab{} = prefab, value_map, table_name, %Thaqqa.Data{} = data)
      when table_name in @lettertable_list,
      do: Op.edit_letter(prefab, value_map, table_name, data)

  def unique_letter_validation(
        %Prefab{} = prefab,
        value_map,
        table_name,
        op,
        subject_data \\ nil
      ),
      do: Validator.unique_letter_validation(prefab, value_map, table_name, op, subject_data)

  def sort_letter(%Prefab{} = prefab),
    do:
      Prefab.sort_as_static_if_enable(prefab, @vowel)
      |> Prefab.sort_as_static_if_enable(@consonant)
      |> Prefab.sort_as_static_if_enable(@punctuation)
      |> Prefab.sort_as_static_if_enable(@diacritic_v)
      |> Prefab.sort_as_static_if_enable(@diacritic_c)
      |> Prefab.sort_as_static_if_enable(@diacritic_p)

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
