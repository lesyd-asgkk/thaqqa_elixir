defmodule Thaqqa.FontRegistryPrefab.GsubTable.Converter do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistryPrefab.GsubTable, as: GsubTable
  use Thaqqa.DataTable.Const

  def gsub!(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case gsub(prefab, string, writing_direction) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def gsub(%Prefab{} = prefab, string, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    GsubTable.get_gsub(prefab, fn %Data{} = data ->
      Data.get_value(data, @writing_direction) in [writing_direction, @universal_language]
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, gsub_data_list} ->
        {:ok,
         gsub_data_list
         |> Enum.reduce(string, fn gsub_data, acc ->
           reg = Data.get_value(gsub_data, @precompile)
           alt = Data.get_value(gsub_data, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end
end
