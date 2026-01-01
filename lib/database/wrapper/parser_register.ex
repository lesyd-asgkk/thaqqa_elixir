defmodule Thaqqa.ParserRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  # alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_parser_table(), do: Thaqqa.FontRegistry.get_static_table(@parser)

  def get_parser(filter_fun \\ fn _ -> true end),
    do: FontRegistry.get_static_table(@parser) |> DataTable.get_data(filter_fun)

  def add_parser!(value_map) do
    case add_parser(value_map) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_parser(value_map) do
    case validate_and_modify_precompile(value_map) do
      {:error, msg} -> {:error, msg}
      {:ok, val} -> {:ok, FontRegistry.get_static_table(@parser) |> DataTable.add_data(val)}
    end
  end

  defp precompile_parser(id_list) when is_list(id_list) do
  end

  defp precompile_parser(id) when is_integer(id), do: precompile_parser([id])

  defp validate_and_modify_precompile(value_map) do
    name = Map.get(value_map, @name)

    if name != nil do
      case Regex_Khhyl.compile(name) do
        {:error, msg} -> {:error, msg}
        {:ok, val} -> {:ok, Map.put(value_map, @precompile, val)}
      end
    else
      {:ok, value_map}
    end
  end

  def delete_parser!(filter_fun, safety_num \\ 1) do
    case delete_parser(filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_parser(filter_fun, safety_num \\ 1),
    do: FontRegistry.get_static_table(@parser) |> DataTable.delete_data(filter_fun, safety_num)

  def edit_parser!(value_map, filter_fun, safety_num \\ 1) do
    case edit_parser(value_map, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_parser(value_map, filter_fun, safety_num \\ 1) do
    case validate_and_modify_precompile(value_map) do
      {:error, msg} ->
        {:error, msg}

      {:ok, val} ->
        {:ok, FontRegistry.get_static_table(@parser) |> DataTable.edit_data(val, safety_num)}
    end
  end

  def parse(string, language) do
  end
end
