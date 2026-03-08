# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.ParserManager do
  alias Thaqqa.DataTable, as: DataTable
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

  def get_parser!(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_parser(prefab, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_parser(%Prefab{} = prefab, filter_fun \\ fn _ -> true end) do
    case get_parser_table(prefab) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_parser!(%Prefab{} = prefab, value_map) do
    case add_parser(prefab, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_parser(%Prefab{} = prefab, value_map) do
    with {:ok, %DataTable{} = table} <- get_parser_table(prefab),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @parser, table) do
      {:ok, sort_parser(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def delete_parser!(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    case delete_parser(prefab, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_parser(%Prefab{} = prefab, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_parser_table(prefab),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data) do
      Prefab.edit_static_table(prefab, @parser, table)
    else
      {:error, _} = err -> err
    end
  end

  def edit_parser!(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    case edit_parser(prefab, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_parser(%Prefab{} = prefab, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_parser_table(prefab),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Prefab{} = new_prefab} <- Prefab.edit_static_table(prefab, @parser, table) do
      {:ok, sort_parser(new_prefab)}
    else
      {:error, _} = err -> err
    end
  end

  def parse!(%Prefab{} = prefab, string, language) when language in [@khehyelu, @samlhta] do
    case parse(prefab, string, language) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def parse(%Prefab{} = prefab, string, language) when language in [@khehyelu, @samlhta] do
    string =
      String.split(string, "")
      |> Enum.slice(1..-2//1)
      |> Enum.map(&("R(" <> &1 <> ")"))
      |> Enum.join("")

    get_parser(prefab, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_val(data, @language) in [language, @universal_language]
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, parser_data_list} ->
        {:ok,
         Enum.reduce(parser_data_list, string, fn parser_data, acc ->
           reg = Thaqqa.Data.get_val(parser_data, @precompile)
           alt = Thaqqa.Data.get_val(parser_data, @name_alt)
           Regex.replace(reg, acc, alt)
         end)}
    end
  end

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @parser)
  def sort_parser(%Prefab{} = prefab), do: Prefab.sort_as_static(prefab, @parser)
end
