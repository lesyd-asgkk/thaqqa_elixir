defmodule Thaqqa.GlyphRegister do
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias SVG.Path, as: Path
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Font, as: Font
  use Thaqqa.DataTable.Const

  def get_glyph_table(fontname) do
    case FontRegistry.get_font(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.font_not_found(fontname)
      {:ok, font} -> {:ok, font |> Font.get_table(@glyph)}
    end
  end

  def precompile_glyph() do
  end

  def precompile_glyph_all!(fontname), do: precompile_glyph!(fontname, [], true)

  def precompile_glyph!(fontname, id) when is_integer(id),
    do: precompile_glyph!(fontname, [id], false)

  def precompile_glyph!(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case precompile_glyph(fontname, id_list, all_flag) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def precompile_glyph_all(fontname), do: precompile_glyph(fontname, [], true)

  def precompile_glyph(fontname, id) when is_integer(id),
    do: precompile_glyph(fontname, [id], false)

  def precompile_glyph(fontname, id_list, all_flag \\ false) when is_list(id_list) do
    case get_glyph_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@glyph, fontname)

      {:ok, table} ->
        table_alter =
          Enum.reduce_while(DataTable.get_data(table), table, fn %Thaqqa.Data{
                                                                   value_list: value_list
                                                                 },
                                                                 acc ->
            if Map.get(value_list, @id) in id_list or all_flag do
              path = Map.get(value_list, @path)
              path_result = SVG.Path.parse_string(path)

              case path_result do
                {:error, _msg} ->
                  {:halt, path_result}

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
    path = Map.get(value_map, @path)

    if path != nil do
      case SVG.Path.parse_string(path) do
        {:error, msg} -> {:error, msg}
        {:ok, val} -> {:ok, Map.put(value_map, @precompile, val)}
      end
    else
      {:ok, value_map}
    end
  end

  def add_glyph(fontname, value_map) do
    case get_glyph_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, nil} ->
        Error.table_not_found(@glyph, fontname)

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} ->
            {:error, msg}

          {:ok, val} ->
            {:ok, table |> DataTable.add_data(val)}
        end
    end
  end

  def delete_glyph!(fontname, filter_fun, safety_num \\ 1) do
    case delete_glyph(fontname, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def delete_glyph(fontname, filter_fun, safety_num \\ 1) do
    case get_glyph_table(fontname) do
      {:error, msg} -> {:error, msg}
      {:ok, nil} -> Error.table_not_found(@glyph, fontname)
      {:ok, table} -> table |> DataTable.delete_data(fontname, filter_fun, safety_num)
    end
  end

  def edit_glyph!(fontname, value_map, filter_fun, safety_num \\ 1) do
    case edit_glyph(fontname, value_map, filter_fun, safety_num) do
      {:error, msg} -> raise msg
      {:ok, val} -> val
    end
  end

  def edit_glyph(fontname, value_map, filter_fun, safety_num \\ 1) do
    case get_glyph_table(fontname) do
      {:error, msg} ->
        {:error, msg}

      {:ok, table} ->
        case validate_and_modify_precompile(value_map) do
          {:error, msg} -> {:error, msg}
          {:ok, val} -> {:ok, table |> DataTable.edit_data(val, safety_num)}
        end
    end
  end
end
