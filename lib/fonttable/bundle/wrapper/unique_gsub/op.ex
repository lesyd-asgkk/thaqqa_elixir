defmodule Thaqqa.Bundle.UniqueGsubTable.Op do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.UniqueGsubTable, as: UniqueGsubTable
  use Thaqqa.DataTable.Const

  def add_unique_gsub!(%Bundle{} = prefab, fontname, value_map) do
    case add_unique_gsub(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_unique_gsub(%Bundle{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- UniqueGsubTable.get_unique_gsub_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Bundle.get_font(prefab, fontname),
         {:ok, %Bundle{} = new_prefab} <-
           Bundle.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      {:ok, UniqueGsubTable.sort_unique_gsub(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_unique_gsub!(%Bundle{} = prefab, fontname, %Data{} = data) do
    case delete_unique_gsub(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_unique_gsub(%Bundle{} = prefab, fontname, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- UniqueGsubTable.get_unique_gsub_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         %Font{} = font <- Bundle.get_font(prefab, fontname) do
      Bundle.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table))
    else
      {:error, _} = err -> err
    end
  end

  def edit_unique_gsub!(%Bundle{} = prefab, fontname, value_map, %Data{} = data) do
    case edit_unique_gsub(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_unique_gsub(%Bundle{} = prefab, fontname, value_map, %Data{} = data) do
    with {:ok, %DataTable{} = table} <- UniqueGsubTable.get_unique_gsub_table(prefab, fontname),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Font{} = font} <- Bundle.get_font_or_error(prefab, fontname),
         {:ok, %Bundle{} = new_prefab} <-
           Bundle.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      {:ok, UniqueGsubTable.sort_unique_gsub(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end
end
