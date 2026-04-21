defmodule Thaqqa.FontRegistryPrefab.ParserTable.Interpreter do
  alias Thaqqa.FontRegistryPrefab.ParserTable, as: ParserTable
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Data, as: Data
  use Thaqqa.DataTable.Const

  def interpret!(%Prefab{} = prefab, string, language) when language in [@khehyelu, @samlhta] do
    case interpret(prefab, string, language) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def interpret(%Prefab{} = prefab, string, language) when language in [@khehyelu, @samlhta] do
    ParserTable.get_parser(prefab, fn %Data{} = data ->
      Data.get_value(data, @language) in [language, @universal_language]
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, parser_data_list} ->
        string =
          String.split(string, "")
          |> Enum.slice(1..-2//1)
          |> Enum.map(&("R(" <> &1 <> ")"))
          |> Enum.join("")

        {:ok,
         Enum.reduce(parser_data_list, string, fn parser_data, acc ->
           reg = Data.get_value(parser_data, @precompile)
           alt = Data.get_value(parser_data, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end
end
