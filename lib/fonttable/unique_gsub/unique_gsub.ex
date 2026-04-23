# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.FontRegistryPrefab.UniqueGsubTable do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.UniqueGsubTable.Op, as: Op
  alias Thaqqa.FontRegistryPrefab.UniqueGsubTable.Query, as: Query
  alias Thaqqa.FontRegistryPrefab.UniqueGsubTable.Converter, as: Converter

  use Thaqqa.DataTable.Const

  def get_unique_gsub_table!(%Prefab{} = prefab, fontname) do
    case get_unique_gsub_table(prefab, fontname) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_unique_gsub_table(%Prefab{} = prefab, fontname),
    do: Prefab.get_table_or_error(prefab, fontname, @unique_gsub)

  def get_unique_gsub!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_unique_gsub!(prefab, fontname, filter_fun)

  def get_unique_gsub(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end),
    do: Query.get_unique_gsub(prefab, fontname, filter_fun)

  def add_unique_gsub!(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_unique_gsub!(prefab, fontname, value_map)

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_unique_gsub(%Prefab{} = prefab, fontname, value_map),
    do: Op.add_unique_gsub(prefab, fontname, value_map)

  def delete_unique_gsub!(%Prefab{} = prefab, fontname, %Data{} = data),
    do: Op.delete_unique_gsub!(prefab, fontname, data)

  def delete_unique_gsub(%Prefab{} = prefab, fontname, %Data{} = data),
    do: Op.delete_unique_gsub(prefab, fontname, data)

  def edit_unique_gsub!(%Prefab{} = prefab, fontname, value_map, %Data{} = data),
    do: Op.edit_unique_gsub!(prefab, fontname, value_map, data)

  def edit_unique_gsub(%Prefab{} = prefab, fontname, value_map, %Data{} = data),
    do: Op.edit_unique_gsub(prefab, fontname, value_map, data)

  def unique_gsub!(%Prefab{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.unique_gsub!(prefab, string, fontname, writing_direction)

  # todo with文-化
  def unique_gsub(%Prefab{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal],
      do: Converter.unique_gsub(prefab, string, fontname, writing_direction)

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @unique_gsub)

  def sort_unique_gsub(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @unique_gsub)
end
