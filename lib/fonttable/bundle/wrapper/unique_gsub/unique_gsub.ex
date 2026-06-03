defmodule Thaqqa.Bundle.UniqueGsubTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.UniqueGsubTable.Op, as: Op
  alias Thaqqa.Bundle.UniqueGsubTable.Query, as: Query
  alias Thaqqa.Bundle.UniqueGsubTable.Converter, as: Converter

  use Thaqqa.DataTable.Const

  def get_unique_gsub_table!(%Bundle{} = prefab, fontname) do
    case get_unique_gsub_table(prefab, fontname) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_unique_gsub_table(%Bundle{} = prefab, fontname),
    do: Bundle.get_table_or_error(prefab, fontname, @unique_gsub)

  def get_unique_gsub!(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_unique_gsub!(prefab, fontname, filter_fun)

  def get_unique_gsub(%Bundle{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_unique_gsub(prefab, fontname, filter_fun)

  def add_unique_gsub!(%Bundle{} = prefab, fontname, value_map),
    do: Op.add_unique_gsub!(prefab, fontname, value_map)

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_unique_gsub(%Bundle{} = prefab, fontname, value_map),
    do: Op.add_unique_gsub(prefab, fontname, value_map)

  def delete_unique_gsub!(%Bundle{} = prefab, fontname, %Data{} = data),
    do: Op.delete_unique_gsub!(prefab, fontname, data)

  def delete_unique_gsub(%Bundle{} = prefab, fontname, %Data{} = data),
    do: Op.delete_unique_gsub(prefab, fontname, data)

  def edit_unique_gsub!(%Bundle{} = prefab, fontname, value_map, %Data{} = data),
    do: Op.edit_unique_gsub!(prefab, fontname, value_map, data)

  def edit_unique_gsub(%Bundle{} = prefab, fontname, value_map, %Data{} = data),
    do: Op.edit_unique_gsub(prefab, fontname, value_map, data)

  def unique_gsub!(%Bundle{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.unique_gsub!(prefab, string, fontname, writing_direction)

  # todo with文-化
  def unique_gsub(%Bundle{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.unique_gsub(prefab, string, fontname, writing_direction)

  def complement(%Bundle{} = prefab, fontname),
    do: Bundle.complement_table(prefab, fontname, @unique_gsub)

  def sort_unique_gsub(%Bundle{} = prefab, fontname),
    do: Bundle.sort_as_font_table_if_enable(prefab, fontname, @unique_gsub)
end
