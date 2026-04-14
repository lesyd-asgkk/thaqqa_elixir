# これどうしよう？
# Registryから直接読み取る方式のままか
# Prefabの加工・読み取りラッパーにするか

defmodule Thaqqa.GposManager do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const
  #
  def get_gpos_table!(%Prefab{} = prefab, fontname),
    do: Prefab.get_table(prefab, fontname, @gpos)

  def get_gpos_table(%Prefab{} = prefab, fontname) do
    case Prefab.get_table(prefab, fontname, @gpos) do
      nil -> Error.table_not_found(@gpos, fontname)
      table -> {:ok, table}
    end
  end

  def get_gpos!(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_gpos(prefab, fontname, filter_fun) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  def get_gpos(%Prefab{} = prefab, fontname, filter_fun \\ fn _ -> true end) do
    case get_gpos_table(prefab, fontname) do
      {:error, _} = err -> err
      {:ok, table} -> {:ok, DataTable.get_data(table, filter_fun)}
    end
  end

  def add_gpos!(%Prefab{} = prefab, fontname, value_map) do
    case add_gpos(prefab, fontname, value_map) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def add_gpos(%Prefab{} = prefab, fontname, value_map) do
    with {:ok, %DataTable{} = table} <- get_gpos_table(prefab, fontname),
         {:ok, %Data{} = data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.add_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, sort_gpos(new_prefab, fontname)}
    else
      nil -> Error.font_not_found(fontname)
      {:error, _} = err -> err
    end
  end

  def delete_gpos!(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    case delete_gpos(prefab, fontname, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def delete_gpos(%Prefab{} = prefab, fontname, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_gpos_table(prefab, fontname),
         {:ok, %DataTable{} = table} <- DataTable.delete_data(table, data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname) do
      Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table))
    else
      {:error, _} = err -> err
    end
  end

  def edit_gpos!(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    case edit_gpos(prefab, fontname, value_map, data) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  def edit_gpos(%Prefab{} = prefab, fontname, value_map, %Thaqqa.Data{} = data) do
    with {:ok, %DataTable{} = table} <- get_gpos_table(prefab, fontname),
         {:ok, %Data{} = new_data} <- Data.new(value_map, table, prefab),
         {:ok, %DataTable{} = table} <- DataTable.edit_data(table, data, new_data),
         {:ok, %Font{} = font} <- Prefab.get_font_or_error(prefab, fontname),
         {:ok, %Prefab{} = new_prefab} <-
           Prefab.edit_font(prefab, fontname, Font.edit_table(font, @gpos, table)) do
      {:ok, sort_gpos(new_prefab, fontname)}
    else
      {:error, _} = err -> err
    end
  end

  def gpos!(%Prefab{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] do
    case gpos(prefab, fontname, string, writing_direction, gpos_type) do
      {:error, reason} -> raise reason
      {:ok, val} -> val
    end
  end

  # todo with文-化
  def gpos(%Prefab{} = prefab, fontname, string, writing_direction, gpos_type)
      when writing_direction in [@vertical, @horizontal] and gpos_type in @gpos_list do
    get_gpos(prefab, fontname, fn %Thaqqa.Data{} = data ->
      Thaqqa.Data.get_value(data, @writing_direction) in [writing_direction, @universal_language] and
        Thaqqa.Data.get_value(data, @gpos_type) == gpos_type
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, gpos_data_list} ->
        {:ok,
         Enum.reduce(gpos_data_list, %{x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0}, fn gpos_data, acc ->
           reg = Thaqqa.Data.get_value(gpos_data, @precompile)
           x0 = Thaqqa.Data.get_value(gpos_data, "OffsetX0")
           x1 = Thaqqa.Data.get_value(gpos_data, "OffsetX1")
           y0 = Thaqqa.Data.get_value(gpos_data, "OffsetY0")
           y1 = Thaqqa.Data.get_value(gpos_data, "OffsetY1")

           if Regex.match?(reg, string),
             do: %{x0: acc.x0 + x0, y0: acc.y0 + y0, x1: acc.x1 + x1, y1: acc.y1 + y1},
             else: acc
         end)}
    end
  end

  def complement(%Prefab{} = prefab, fontname),
    do: Prefab.complement_table(prefab, fontname, @gpos)

  def sort_gpos(%Prefab{} = prefab, fontname),
    do: Prefab.sort_as_font_table_if_enable(prefab, fontname, @gpos)
end
