defmodule Thaqqa.Bundle.Query do
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Data, as: Data
  alias Thaqqa.FontRegistry.Error, as: Error

  def get_font(%Bundle{} = self, name), do: Map.get(self.fonts, name)

  def get_font_or_error(%Bundle{} = self, name) do
    case get_font(self, name) do
      nil -> {:error, Error.font_not_found(name)}
      otherwise -> {:ok, otherwise}
    end
  end

  def get_font_from_filename(%Bundle{} = self, filename),
    do:
      get_font_list(self)
      |> Enum.filter(fn {_, val} -> val.filename == filename end)
      |> Enum.at(0)

  def get_font_list(%Bundle{} = self), do: self.fonts

  def get_static_table(%Bundle{} = self, name), do: Map.get(get_static_table_list(self), name)

  def get_static_table_or_error(%Bundle{} = self, name) do
    case get_static_table(self, name) do
      nil -> Error.table_not_found(name)
      table -> {:ok, table}
    end
  end

  def get_static_table_list(%Bundle{} = self), do: self.static_tables

  def get_global_static_table_list(%Bundle{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> val.global end)

  def get_local_static_table_list(%Bundle{} = self),
    do: get_static_table_list(self) |> Enum.filter(fn {_, val} -> !val.global end)

  def static_table_exists?(self, table_name),
    do:
      get_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def local_static_table_exists?(self, table_name),
    do:
      get_local_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def global_static_table_exists?(self, table_name),
    do:
      get_global_static_table_list(self)
      |> Enum.any?(fn {k, _} -> k == table_name end)

  def get_table(%Bundle{} = self, fontname, tablename) do
    case get_font(self, fontname) do
      nil -> nil
      font -> Font.get_table(font, tablename)
    end
  end

  def get_table_or_error(%Bundle{} = self, fontname, tablename) do
    case get_font_or_error(self, fontname) do
      {:error, _} = err ->
        err

      {:ok, font} ->
        case Font.get_table(font, tablename) do
          nil -> Error.table_not_found(tablename, fontname)
          datatable -> {:ok, datatable}
        end
    end
  end

  def get_single_data_or_nil(%Bundle{} = self, fontname, tablename) do
    case get_table(self, fontname, tablename) do
      nil -> nil
      table -> table.data_list |> Enum.at(0)
    end
  end

  def get_single_data(%Bundle{} = self, fontname, tablename) do
    case get_table(self, fontname, tablename) do
      nil -> Error.table_not_found(tablename, fontname)
      table -> {:ok, table.data_list |> Enum.at(0)}
    end
  end

  def get_single_data_value_or_nil(%Bundle{} = self, fontname, tablename, column) do
    case get_single_data_or_nil(self, fontname, tablename) do
      nil -> nil
      data -> Data.get_value(data, column)
    end
  end

  def get_single_data_value(%Bundle{} = self, fontname, tablename, column) do
    case get_single_data(self, fontname, tablename) do
      {:error, _} = err -> err
      {:ok, data} -> Data.get_value_or_error(data, column)
    end
  end

  def get_fontdata(%Bundle{} = self, fontname, list) when is_list(list) do
    case get_single_data(self, fontname, "FONTDATA") do
      {:ok, %Data{} = data} ->
        {value_map, err_list} =
          Enum.reduce(list, {%{}, []}, fn arg, {acc, acc_err} ->
            case Data.get_value(data, arg) do
              nil -> {acc, [arg | acc_err]}
              otherwise -> {Map.put(acc, String.to_atom(arg), otherwise), acc_err}
            end
          end)

        if length(err_list) == 0,
          do: {:ok, value_map},
          else: Error.data_not_found(nil, err_list, "FONTDATA", fontname)

      {:error, _} = err ->
        err
    end
  end

  def get_column_list(%Bundle{} = self, name) do
    case get_static_table(self, name) do
      nil -> nil
      datatable -> datatable.column_list
    end
  end

  def get_column(%Bundle{} = self, table_name, column_name) do
    case get_static_table(self, table_name) do
      nil -> nil
      datatable -> datatable.column_list |> Enum.find(&(&1.name == column_name))
    end
  end
end
