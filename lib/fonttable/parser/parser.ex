# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.FontRegistryPrefab.ParserTable do
  alias Thaqqa.FontRegistryPrefab.ParserTable.Interpreter, as: Interpreter
  alias Thaqqa.FontRegistryPrefab.ParserTable.Op, as: Op
  alias Thaqqa.FontRegistryPrefab.ParserTable.Query, as: Query
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_parser_table!(%Prefab{} = prefab), do: Prefab.get_static_table(prefab, @parser)

  def get_parser_table(%Prefab{} = prefab) do
    case Prefab.get_static_table(prefab, @parser) do
      nil -> Error.table_not_found(@parser)
      table -> {:ok, table}
    end
  end

  def get_parser!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_parser!(prefab, filter_fun)

  def get_parser(%Prefab{} = prefab, filter_fun \\ fn _ -> true end),
    do: Query.get_parser(prefab, filter_fun)

  def add_parser!(%Prefab{} = prefab, value_map), do: Op.add_parser!(prefab, value_map)

  def add_parser(%Prefab{} = prefab, value_map), do: Op.add_parser(prefab, value_map)

  def delete_parser!(%Prefab{} = prefab, %Data{} = data),
    do: Op.delete_parser!(prefab, data)

  def delete_parser(%Prefab{} = prefab, %Data{} = data), do: Op.delete_parser(prefab, data)

  def edit_parser!(%Prefab{} = prefab, value_map, %Data{} = data),
    do: Op.edit_parser!(prefab, value_map, data)

  def edit_parser(%Prefab{} = prefab, value_map, %Data{} = data),
    do: Op.edit_parser(prefab, value_map, data)

  def interpret(%Prefab{} = prefab, string, language) when language in [@khehyelu, @samlhta],
    do: Interpreter.interpret(prefab, string, language)

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @parser)
  def sort_parser(%Prefab{} = prefab), do: Prefab.sort_as_static_if_enable(prefab, @parser)
end
