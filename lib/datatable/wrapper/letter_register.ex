defmodule Thaqqa.LetterRegister do
  alias Thaqqa.DataTable, as: DataTable

  @vowel "VOWEL"
  @consonant "CONSONANT"
  @punctuation "PUCTUATION"
  @diacritic_v "DIACRITIC_V"
  @diacritic_c "DIACRITIC_C"
  @diacritic_p "DIACRITIC_P"

  @lettertable_list [@vowel, @consonant, @punctuation, @diacritic_v, @diacritic_c, @diacritic_p]

  def get_table(),
    do:
      @lettertable_list
      |> Enum.reduce(%{}, fn k, acc ->
        Map.put(acc, k, Thaqqa.FontRegistry.get_static_table(k))
      end)

  def get_letter(filter_fun \\ fn _ -> true end),
    do:
      get_table()
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        if v != nil,
          do: Map.put(acc, k, DataTable.get_data(v, filter_fun)),
          else: Map.put(acc, k, [])
      end)

  def add_letter(value_map, table_name) when table_name in @lettertable_list do
    # DataTable.unique_validation(table, new_value_map, :add)
  end

  def delete_letter() do
  end

  def edit_letter() do
  end
end
