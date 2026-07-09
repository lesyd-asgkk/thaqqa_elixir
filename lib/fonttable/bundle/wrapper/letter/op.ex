defmodule Thaqqa.Bundle.LetterTable.Op do
  alias Thaqqa.Bundle.LetterTable, as: LetterTable
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  def add_letter!(%Bundle{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    case add_letter(prefab, value_map, table_name) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_letter(%Bundle{} = prefab, value_map, table_name)
      when table_name in @lettertable_list do
    with :ok <- LetterTable.unique_letter_validation(prefab, value_map, table_name, :add),
         {:ok, %DataTable{} = table} <- LetterTable.get_letter_table_from_name(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, value_map),
         {:ok, %Bundle{} = prefab} <- Bundle.edit_static_table(prefab, table_name, table) do
      {:ok, LetterTable.sort_letter(prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_letter!(%Bundle{} = prefab, table_name, %Data{} = data)
      when table_name in @lettertable_list do
    case delete_letter(prefab, table_name, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_letter(%Bundle{} = prefab, table_name, %Data{} = data)
      when table_name in @lettertable_list do
    with {:ok, %DataTable{} = table} <- LetterTable.get_letter_table_from_name(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Bundle.edit_static_table(prefab, table_name, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_letter!(%Bundle{} = prefab, value_map, table_name, %Data{} = data)
      when table_name in @lettertable_list do
    case edit_letter!(prefab, value_map, table_name, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_letter(%Bundle{} = prefab, value_map, table_name, %Data{} = data)
      when table_name in @lettertable_list do
    with :ok <- LetterTable.unique_letter_validation(prefab, value_map, table_name, :edit, data),
         {:ok, %DataTable{} = table} <- LetterTable.get_letter_table_from_name(prefab, table_name),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, value_map),
         {:ok, %Bundle{} = prefab} <- Bundle.edit_static_table(prefab, table_name, table) do
      {:ok, LetterTable.sort_letter(prefab)}
    else
      {:error, _} = err -> err
    end
  end
end
