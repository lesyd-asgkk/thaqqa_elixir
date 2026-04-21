# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.UniqueGsubManager do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_unique_gsub_table!(%Prefab{} = prefab, fontname),
    do: Prefab.get_table(prefab, fontname, @unique_gsub)

  def get_unique_gsub_table(%Prefab{} = prefab, fontname) do
    case Prefab.get_table(prefab, fontname, @unique_gsub) do
      nil -> Error.table_not_found(@unique_gsub, fontname)
      table -> {:ok, table}
    end
  end

  def get_unique_gsub!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_unique_gsub(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_unique_gsub(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_unique_gsub_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_unique_gsub!(%Prefab{} = prefab, fontname, value_map) do
    case add_unique_gsub(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_unique_gsub(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- get_unique_gsub_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      {:ok, sort_unique_gsub(new_prefab, fontname)}
    else
      nil -> Error.font_not_found(fontname)
      {:error, _} = err -> err
    end
  end

  def delete_unique_gsub!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_unique_gsub(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_unique_gsub(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_unique_gsub_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         %Font{} = font <- Prefab.get_font(prefab, fontname) do
      Prefab.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table))
    else
      nil -> Error.font_not_found(fontname)
      {:error, _} = err -> err
    end
  end

  def edit_unique_gsub!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_unique_gsub(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_unique_gsub(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_unique_gsub_table(prefab, fontname),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      {:ok, sort_unique_gsub(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def unique_gsub!(%Prefab{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case unique_gsub(prefab, string, fontname, writing_direction) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def unique_gsub(%Prefab{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    get_unique_gsub(prefab, fontname, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_value(data, @writing_direction) in [writing_direction, @universal_language]
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, uniquegsub_data_list} ->
        {:ok,
         Enum.reduce(uniquegsub_data_list, string, fn uniquegsub_data, acc ->
           reg = Thaqqa.Data.get_value(uniquegsub_data, @precompile)
           alt = Thaqqa.Data.get_value(uniquegsub_data, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @unique_gsub)

  def sort_unique_gsub(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @unique_gsub)
end
