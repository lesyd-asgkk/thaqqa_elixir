defmodule Thaqqa.GposRegister do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Font, as: Font
  use Thaqqa.DataTable.Const

  def get_gpos_table(fontname) do
    case FontRegistry.get_font(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.font_not_found(fontname)
      {:ok, font} -> {:ok, font |> Font.get_table(@gpos)}
    end
  end

  def get_gpos(fontname, filter_fun \\ fn _ -> true end) do
    case get_gpos_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.table_not_found(@gpos, fontname)
      {:ok, table} -> {:ok, table |> DataTable.get_data(filter_fun)}
    end
  end

  def precompile_gpos_all!(fontname), do: precompile_gpos!(fontname, [], true)

  def precompile_gpos!(fontname, id) when is_integer(id),
    do: precompile_gpos!(fontname, [id], false)

  def precompile_gpos!(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case precompile_gpos(fontname, id_list, all_flag) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def precompile_gpos_all(fontname), do: precompile_gpos(fontname, [], true)

  def precompile_gpos(fontname, id) when is_integer(id),
    do: precompile_gpos(fontname, [id], false)

  def precompile_gpos(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case get_gpos_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@gpos, fontname)

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

  def add_gpos(fontname, value_map) do
    case get_gpos_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@gpos, fontname)

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} ->
            {:error, msg}

          {:ok, val} ->
            {:ok, table |> DataTable.add_data(val)}
        end
    end
  end

  def delete_gpos!(fontname, filter_fun, safety_num \\ 1) do
    case delete_gpos(fontname, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_gpos(fontname, filter_fun, safety_num \\ 1) do
    case get_gpos_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.table_not_found(@gpos, fontname)
      {:ok, table} -> table |> DataTable.delete_data(fontname, filter_fun, safety_num)
    end
  end

  def edit_gpos!(fontname, value_map, filter_fun, safety_num \\ 1) do
    case edit_gpos(fontname, value_map, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_gpos(fontname, value_map, filter_fun, safety_num \\ 1) do
    case get_gpos_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} -> {:error, msg}
          {:ok, val} -> {:ok, table |> DataTable.edit_data(val, safety_num)}
        end
    end
  end

  def gpos!(string, fontname, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list do
    case gpos(string, fontname, writing_direction, gpos_type) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def gpos(string, fontname, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list do
    get_gpos(fontname, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_val(data, @writing_direction) in [writing_direction, @universal_direction] and
        Thaqqa.Data.get_val(data, @gpos_type) == gpos_type
    end)
    |> case do
      {:error, msg} ->
        {:error, msg}

      {:ok, val} ->
        {:ok,
         val
         |> Enum.reduce(%{x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0}, fn p, acc ->
           reg = Thaqqa.Data.get_val(p, @precompile)
           x0 = Thaqqa.Data.get_val(p, "OffsetX0")
           x1 = Thaqqa.Data.get_val(p, "OffsetX1")
           y0 = Thaqqa.Data.get_val(p, "OffsetY0")
           y1 = Thaqqa.Data.get_val(p, "OffsetY1")

           if Regex.match?(reg, string),
             do: %{x0: acc.x0 + x0, y0: acc.y0 + y0, x1: acc.x1 + x1, y1: acc.y1 + y1},
             else: acc
         end)}
    end
  end

  def sort_gpos(fontname) do
    case get_gpos_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, table} -> table |> Thaqqa.DataTable.sort()
    end
  end
end
