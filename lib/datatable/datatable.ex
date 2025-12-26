defmodule Thaqqa.DataTable do
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data

  defstruct [
    :name,
    :parent,
    column_list: [],
    data_list: [],
    desc: ""
  ]

  def new(name, parent),
    do: %__MODULE__{name: name, parent: parent, desc: "", column_list: [], data_list: []}

  def get_column(%__MODULE__{column_list: cols}, column_name),
    do: Enum.find(cols, fn %Column{name: name} -> name == column_name end)

  def add_column!(
        %__MODULE__{column_list: cols, data_list: datas} = table,
        column_name,
        type,
        desc \\ "",
        order \\ 0,
        subtype \\ "",
        val_init \\ nil,
        dev \\ false
      ) do
    case add_column(table, column_name, type, desc, order, subtype, val_init, dev) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def add_column(
        %__MODULE__{column_list: cols, data_list: datas} = table,
        column_name,
        type,
        desc \\ "",
        order \\ 0,
        subtype \\ "",
        val_init \\ nil,
        dev \\ false
      ) do
    if !Column.is_available_type(type) do
      {:error, "Invalid type: #{type}"}
    else
      val_init =
        val_init ||
          case type do
            "char" -> ""
            "float" -> 0.0
            "INTEGER" -> 0
            "bool" -> false
            _ -> nil
          end

      Enum.map(datas, fn data -> Data.set_val(data, column_name, val_init) end)

      ans = %{
        table
        | column_list:
            cols ++
              [
                %Column{
                  name: column_name,
                  type: type,
                  desc: desc,
                  order: order,
                  subtype: subtype,
                  dev: dev
                }
              ],
          data_list: datas
      }

      {:ok, ans}
    end
  end

  def delete_column(
        %__MODULE__{column_list: cols, data_list: datas} = table,
        column_name
      ) do
    new_cols = Enum.filter(cols, fn %Column{name: name} -> name != column_name end)

    new_datas =
      Enum.map(datas, fn data ->
        %{data | value_list: Map.delete(data.value_list, column_name)}
      end)

    %{table | column_list: new_cols, data_list: new_datas}
  end

  def edit_column(
        %__MODULE__{column_list: cols} = table,
        column_name,
        new_name \\ nil,
        new_desc \\ nil,
        new_order \\ nil,
        new_subtype \\ nil,
        new_dev \\ nil
      ) do
    new_cols =
      Enum.map(cols, fn
        %Column{name: ^column_name} = col ->
          %Column{
            col
            | name: new_name || col.name,
              desc: new_desc || col.desc,
              order: new_order || col.order,
              subtype: new_subtype || col.subtype,
              dev: new_dev || col.dev
          }

        col ->
          col
      end)

    if new_name != nil do
      # データのキーも変更する
      new_datas =
        Enum.map(table.data_list, fn data ->
          val = Data.get_val(data, column_name)
          data = Data.set_val(data, new_name, val)
          %{data | value_list: Map.delete(data.value_list, column_name)}
        end)

      %{table | column_list: new_cols, data_list: new_datas}
    else
      %{table | column_list: new_cols}
    end
  end

  def get_data(%__MODULE__{data_list: datas}, filter_fun \\ fn _ -> true end) do
    Enum.filter(datas, filter_fun)
  end

  def get_least_available_id(%__MODULE__{data_list: datas}) do
    existing_ids =
      Enum.map(datas, fn data ->
        Data.get_val(data, "ID")
      end)
      |> Enum.filter(&is_integer/1)
      |> Enum.sort()

    find_least_missing(existing_ids, 1)
  end

  defp find_least_missing([], candidate), do: candidate

  defp find_least_missing([head | tail], candidate) do
    cond do
      head == candidate -> find_least_missing(tail, candidate + 1)
      head > candidate -> candidate
      true -> find_least_missing(tail, candidate)
    end
  end

  def add_data(%__MODULE__{data_list: datas} = table, value_list) do
    value_list =
      Enum.reduce(table.column_list, value_list, fn %Column{
                                                      name: name,
                                                      type: type,
                                                      subtype: subtype
                                                    },
                                                    acc ->
        if Map.has_key?(acc, name) do
          # 事前にコンパイルしておく
          if type == "char" and subtype == "PARSED",
            do: Map.put(acc, name, Map.get(acc, name) |> Regex.compile!()),
            else: acc
        else
          val_init =
            case type do
              "char" -> ""
              "float" -> 0.0
              "INTEGER" -> 0
              "bool" -> false
              _ -> nil
            end

          Map.put(acc, name, val_init)
        end
      end)

    value_list =
      if Map.has_key?(value_list, "ID") do
        value_list
      else
        least_id = get_least_available_id(table)
        Map.put(value_list, "ID", least_id)
      end

    new_data = %Data{value_list: value_list}
    %{table | data_list: datas ++ [new_data]}
  end

  def delete_data(%__MODULE__{data_list: datas} = table, filter_fun) do
    new_datas = Enum.filter(datas, fn data -> not filter_fun.(data) end)
    %{table | data_list: new_datas}
  end

  def edit_data(%__MODULE__{data_list: datas} = table, filter_fun, new_value_list) do
    new_datas =
      Enum.map(datas, fn data ->
        if filter_fun.(data) do
          %Data{data | value_list: Map.merge(data.value_list, new_value_list)}
        else
          data
        end
      end)

    %{table | data_list: new_datas}
  end

  def update_fontmanager(%__MODULE__{name: name, parent: nil} = table) do
    Thaqqa.FontRegistry.edit_static_table(name, table)
    table
  end

  def update_fontmanager(%__MODULE__{name: name, parent: parent} = table) do
    Thaqqa.FontRegistry.edit_static_table(name, table)
    table
  end
end
