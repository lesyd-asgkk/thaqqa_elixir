# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.UniqueGsubManager do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.DataValidator, as: DataValidator
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
      {:error, msg} -> raise msg
      {:ok, value} -> value
    end
  end

  def get_unique_gsub(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_unique_gsub_table(prefab, fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_unique_gsub!(%Prefab{} = prefab, fontname, value_map) do
    case add_unique_gsub(prefab, fontname, value_map) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  # ぶっちゃけ直接加工＋単にsortにしてしまったほうが早い
  # 　ただし変更の優先順位は低め
  def add_unique_gsub(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- get_unique_gsub_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, value_map),
         %Font{} = font <- Prefab.get_font(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      complement(new_prefab, fontname)
    else
      nil -> Error.font_not_found(fontname)
      {:error, msg} -> {:error, msg}
    end
  end

  def delete_unique_gsub!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_unique_gsub(prefab, fontname, data) do
      {:error, msg} -> raise msg
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
      {:error, msg} -> {:error, msg}
    end
  end

  def edit_unique_gsub!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_unique_gsub(prefab, fontname, value_map, data) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_unique_gsub(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_unique_gsub_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, value_map),
         %Font{} = font <- Prefab.get_font(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @unique_gsub, table)) do
      complement(new_prefab, fontname)
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def unique_gsub!(%Prefab{} = prefab, fontname, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case unique_gsub(prefab, fontname, string, writing_direction) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def unique_gsub(%Prefab{} = prefab, fontname, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    get_unique_gsub(prefab, fontname, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_val(data, @writing_direction) in [writing_direction, @universal_language]
    end)
    |> case do
      {:error, msg} ->
        {:error, msg}

      {:ok, val} ->
        {:ok,
         val
         |> Enum.reduce(string, fn p, acc ->
           reg = Thaqqa.Data.get_val(p, @precompile)
           alt = Thaqqa.Data.get_val(p, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @unique_gsub)

  def sort_unique_gsub(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table(prefab, fontname, @unique_gsub)
end
