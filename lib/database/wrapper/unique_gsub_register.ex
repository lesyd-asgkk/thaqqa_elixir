defmodule Thaqqa.UniqueGsubRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Font, as: Font
  use Thaqqa.DataTable.Const

  def get_unique_gsub_table(fontname),
    do: FontRegistry.get_table_from_font(fontname, @unique_gsub)

  def get_unique_gsub(fontname, filter_fun \\ fn _ -> true end) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.table_not_found(@unique_gsub, fontname)
      {:ok, table} -> {:ok, table |> DataTable.get_data(filter_fun)}
    end
  end

  def precompile_unique_gsub_all!(fontname), do: precompile_unique_gsub!(fontname, [], true)

  def precompile_unique_gsub!(fontname, id) when is_integer(id),
    do: precompile_unique_gsub!(fontname, [id], false)

  def precompile_unique_gsub!(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case precompile_unique_gsub(fontname, id_list, all_flag) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def precompile_unique_gsub_all(fontname), do: precompile_unique_gsub(fontname, [], true)

  def precompile_unique_gsub(fontname, id) when is_integer(id),
    do: precompile_unique_gsub(fontname, [id], false)

  def precompile_unique_gsub(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@unique_gsub, fontname)

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

  def add_unique_gsub(fontname, value_map) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@unique_gsub, fontname)

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} ->
            {:error, msg}

          {:ok, val} ->
            {:ok, table |> DataTable.add_data(val)}
        end
    end
  end

  def delete_unique_gsub!(fontname, filter_fun, safety_num \\ 1) do
    case delete_unique_gsub(fontname, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_unique_gsub(fontname, filter_fun, safety_num \\ 1) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.table_not_found(@unique_gsub, fontname)
      {:ok, table} -> table |> DataTable.delete_data(fontname, filter_fun, safety_num)
    end
  end

  def edit_unique_gsub!(fontname, value_map, filter_fun, safety_num \\ 1) do
    case edit_unique_gsub(fontname, value_map, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_unique_gsub(fontname, value_map, filter_fun, safety_num \\ 1) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} -> {:error, msg}
          {:ok, val} -> {:ok, table |> DataTable.edit_data(val, safety_num)}
        end
    end
  end

  def unique_gsub!(string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    case unique_gsub(string, fontname, writing_direction) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def unique_gsub(string, fontname, writing_direction)
      when writing_direction in [@vertical, @horizontal] do
    get_unique_gsub(fontname, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_val(data, @writing_direction) in [writing_direction, @universal_direction]
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

  def sort_unique_gsub(fontname) do
    case get_unique_gsub_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> table |> Thaqqa.DataTable.sort()
    end
  end
end
