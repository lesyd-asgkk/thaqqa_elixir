# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.GsubManager do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_gsub_table!(%Prefab{} = prefab), do: Prefab.get_static_table(prefab, @gsub)

  def get_gsub_table(%Prefab{} = prefab) do
    case Prefab.get_static_table(prefab, @gsub) do
      nil -> Error.table_not_found(@gsub)
      table -> {:ok, table}
    end
  end

  def get_gsub!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_gsub(prefab, filter_fun) do
      {:error, msg} -> raise msg
      {:ok, value} -> value
    end
  end

  def get_gsub(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_gsub_table(prefab) do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_gsub!(%Prefab{} = prefab, value_map) do
    case add_gsub(prefab, value_map) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_gsub(%Prefab{} = prefab, value_map) do
    with {:ok, %DataTable{} = table} <- get_gsub_table(prefab),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @gsub, table) do
      {:ok, sort_gsub(new_prefab)}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def delete_gsub!(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    case delete_gsub(prefab, data) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_gsub(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_gsub_table(prefab),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Prefab.edit_static_table(prefab, @gsub, table)
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def edit_gsub!(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    case edit_gsub(prefab, value_map, data) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_gsub(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_gsub_table(prefab),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @gsub, table) do
      {:ok, sort_gsub(new_prefab)}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def gsub!(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case gsub(prefab, string, writing_direction) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def gsub(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    get_gsub(prefab, fn %Thaqqa.Data{} = data ->
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

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @gsub)
  def sort_gsub(%Prefab{} = prefab), do: Prefab.sort_as_static(prefab, @gsub)
end
