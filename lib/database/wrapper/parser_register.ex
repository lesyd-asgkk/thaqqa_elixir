defmodule Thaqqa.ParserRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  # alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const

  def get_parser_table(), do: Thaqqa.FontRegistry.get_static_table(@parser)

  def get_parser(filter_fun \\ fn _ -> true end) do
    case get_parser_table() do
      {:ok, val} -> val |> DataTable.get_data(filter_fun)
      {:error, msg} -> {:error, msg}
    end
  end

  def add_parser!(value_map) do
    case add_parser(value_map) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def add_parser(value_map) do
    table_ = get_parser_table()

    case table_ do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} -> {:error, msg}
          {:ok, val} -> {:ok, table |> DataTable.add_data(val)}
        end
    end
  end

  def precompile_parser_all!(), do: precompile_parser!([], true)
  def precompile_parser!(id) when is_integer(id), do: precompile_parser!([id], false)

  def precompile_parser!(id_list, all_flag \\ false) when is_list(id_list) do
    case precompile_parser(id_list, all_flag) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def precompile_parser_all(), do: precompile_parser([], true)

  def precompile_parser(id) when is_integer(id), do: precompile_parser([id], false)

  def precompile_parser(id_list, all_flag \\ false) when is_list(id_list) do
    case get_parser_table() do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        table_alter =
          Enum.reduce_while(DataTable.get_data(table), table, fn %Thaqqa.Data{
                                                                   value_list: value_list
                                                                 },
                                                                 acc ->
            if Map.get(value_list, @id) in id_list or all_flag do
              name = Map.get(value_list, @name)
              reg_result = Regex_Khhyl.compile(name)

              case reg_result do
                {:error, _msg} ->
                  {:halt, reg_result}

                {:ok, reg} ->
                  value_list_ = Map.put(%{}, @precompile, reg)

                  case DataTable.edit_data(
                         acc,
                         &(&1.value_list == value_list),
                         value_list_
                       ) do
                    {:error, msg} -> {:halt, {:error, msg}}
                    {:ok, data} -> {:cont, data}
                  end
              end
            else
              {:cont, acc}
            end
          end)

        case table_alter do
          {:error, _msg} -> table_alter
          _ -> {:ok, table_alter}
        end
    end
  end

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

  def delete_parser(filter_fun, safety_num \\ 1) do
    case get_parser_table() do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> table |> DataTable.delete_data(filter_fun, safety_num)
    end
  end

  def edit_parser!(value_map, filter_fun, safety_num \\ 1) do
    case edit_parser(value_map, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_parser(value_map, filter_fun, safety_num \\ 1) do
    case get_parser_table() do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} -> {:error, msg}
          {:ok, val} -> {:ok, table |> DataTable.edit_data(val, safety_num)}
        end
    end
  end

  def parse(string, language) when language in [@khehyelu, @samlhta] do
    string =
      String.split(string, "")
      |> Enum.slice(1..-2//1)
      |> Enum.map(&("R(" <> &1 <> ")"))
      |> Enum.join("")

    get_parser(fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_val(data, @language) in [language, @universal_language]
    end)
    |> Enum.reduce(string, fn p, acc ->
      reg = Thaqqa.Data.get_val(p, @precompile)
      alt = Thaqqa.Data.get_val(p, @name_alt)
      Regex.replace(reg, acc, alt)
    end)
  end

  def sort_parser() do
    case get_parser_table() do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> table |> Thaqqa.DataTable.sort()
    end
  end
end
