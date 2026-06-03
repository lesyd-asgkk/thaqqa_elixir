defmodule Thaqqa.Bundle.ParserTable do
  alias Thaqqa.Bundle.ParserTable.Interpreter, as: Interpreter
  alias Thaqqa.Bundle.ParserTable.Op, as: Op
  alias Thaqqa.Bundle.ParserTable.Query, as: Query
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Bundle, as: Bundle
  use Thaqqa.DataTable.Const

  def get_parser_table!(%Bundle{} = prefab) do
    case get_parser_table(prefab) do
      {:error, reason} -> raise reason
      {:ok, table} -> table
    end
  end

  def get_parser_table(%Bundle{} = prefab), do: Bundle.get_static_table_or_error(prefab, @parser)

  def get_parser!(%Bundle{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_parser!(prefab, filter_fun)

  def get_parser(%Bundle{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_parser(prefab, filter_fun)

  def add_parser!(%Bundle{} = prefab, value_map), do: Op.add_parser!(prefab, value_map)

  def add_parser(%Bundle{} = prefab, value_map), do: Op.add_parser(prefab, value_map)

  def delete_parser!(%Bundle{} = prefab, %Data{} = data),
    do: Op.delete_parser!(prefab, data)

  def delete_parser(%Bundle{} = prefab, %Data{} = data), do: Op.delete_parser(prefab, data)

  def edit_parser!(%Bundle{} = prefab, value_map, %Data{} = data),
    do: Op.edit_parser!(prefab, value_map, data)

  def edit_parser(%Bundle{} = prefab, value_map, %Data{} = data),
    do: Op.edit_parser(prefab, value_map, data)

  def interpret(%Bundle{} = prefab, string, language) when language in [@khehyelu, @samlhta],
    do: Interpreter.interpret(prefab, string, language)

  def complement(%Bundle{} = prefab), do: Bundle.complement_by_static_table(prefab, @parser)
  def sort_parser(%Bundle{} = prefab), do: Bundle.sort_as_static_if_enable(prefab, @parser)
end
