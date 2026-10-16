defmodule Thaqqa.Bundle.UniqueGsubTable.Converter do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Bundle.UniqueGsubTable, as: UniqueGsubTable
  use Thaqqa.DataTable.Const

  def unique_gsub!(%Bundle{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case unique_gsub(prefab, string, fontname, writing_direction) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def unique_gsub(%Bundle{} = prefab, string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    UniqueGsubTable.get_unique_gsub(prefab, fontname, fn %Data{} = data ->
      Data.get_value(data, @writing_direction) in [writing_direction, @universal_language]
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, uniquegsub_data_list} ->
        {:ok,
         Enum.reduce(uniquegsub_data_list, string, fn uniquegsub_data, acc ->
           reg = Data.get_value(uniquegsub_data, @precompile)
           alt = Data.get_value(uniquegsub_data, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end
end
