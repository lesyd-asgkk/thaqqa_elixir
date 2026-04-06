#
defimpl Jason.Encoder, for: Thaqqa.DataTable do
  def encode(datatable, opts) do
    datalist_map =
      datatable.data_list
      |> Enum.with_index()
      |> Map.new(fn {v, i} -> {Integer.to_string(i), v.value_list} end)

    column_volatility =
      Thaqqa.DataTable.get_column(datatable, fn %Thaqqa.Column{type: type} ->
        type == :volatility
      end)
      |> Enum.map(fn %Thaqqa.Column{name: name} -> name end)

    datalist_map =
      Enum.reduce(datalist_map, %{}, fn {k, v}, acc ->
        v =
          Enum.reduce(v, %{}, fn {k, v}, acc ->
            if k in column_volatility, do: acc, else: Map.put(acc, k, v)
          end)

        Map.put(acc, k, v)
      end)

    Jason.Encode.map(
      %{
        name: datatable.name,
        compile_rule: datatable.compile_rule,
        single: datatable.single,
        columnList: datatable.column_list |> Map.new(fn v -> {v.name, v} end),
        dataList: datalist_map
      },
      opts
    )
  end
end

defmodule Thaqqa.DataTable do
  alias Thaqqa.DataMapValidator, as: DataMapValidator
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data

  use Thaqqa.DataTable.Const

  defstruct [
    :name,
    :global,
    :parent,
    :compile_rule,
    column_list: [],
    data_list: [],
    desc: "",
    single: false,
    data_hash: %{}
  ]

  def new(name, global, parent, compile_rule, single),
    do: %__MODULE__{
      name: name,
      global: global,
      parent: parent,
      compile_rule: compile_rule,
      desc: "",
      column_list: [],
      data_list: [],
      single: single,
      data_hash: %{}
    }

  def is_global?(%__MODULE__{global: global}), do: global

  # column系統

  def get_column(%__MODULE__{column_list: columns}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(columns, filter_fun)

  def add_column!(%__MODULE__{} = table, %Column{} = column, val_init \\ nil) do
    case add_column(table, column, val_init) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def add_column(
        %__MODULE__{data_list: datalist, column_list: col_list} = table,
        %Column{name: column_name, type: type} = column,
        val_init \\ nil
      ) do
    if get_column(table, fn %Column{name: name} -> name == column_name end) != [] do
      Error.nominal_conflict_column(column_name, :add)
    else
      if !Column.is_available_type(type) do
        Error.invalid_datatype(type)
      else
        val_init = Column.init_value(column, val_init)
        datalist = Enum.map(datalist, fn data -> Data.set_value(data, column_name, val_init) end)

        ans = %{table | column_list: col_list ++ [column], data_list: datalist}

        {:ok, ans}
      end
    end
  end

  def delete_column(
        %__MODULE__{column_list: cols, data_list: datalist} = table,
        column_name
      ) do
    new_cols = Enum.filter(cols, fn %Column{name: name} -> name != column_name end)

    new_datalist = Enum.map(datalist, fn data -> Data.delete_value(data, column_name) end)

    %{table | column_list: new_cols, data_list: new_datalist}
  end

  def edit_column!(%__MODULE__{} = table, column_name, %Column{name: new_name} = column) do
    case edit_column(table, column_name, column) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def edit_column(
        %__MODULE__{column_list: col_list} = table,
        column_name,
        %Column{name: new_name} = column
      ) do
    if get_column(table, fn %Column{name: name} -> name == column_name end) != [] and
         column_name != new_name do
      Error.nominal_conflict_column(column_name, :edit)
    else
      new_cols =
        Enum.map(col_list, fn
          %Column{name: ^column_name} = col -> column
          col -> col
        end)

      # データのキーも変更する
      new_datas =
        Enum.map(table.data_list, fn data ->
          raw_val = Data.get_value(data, column_name)
          # Columnのtype,subtypeが変わった場合の値の補正。
          val = Column.adjust_value(column, raw_val)
          data = Data.set_value(data, new_name, val)

          if new_name == column_name,
            do: %{data | value_list: data.value_list},
            else: %{data | value_list: Map.delete(data.value_list, column_name)}
        end)

      {:ok, %{table | column_list: new_cols, data_list: new_datas}}
    end
  end

  # data系統

  def get_least_available_id(%__MODULE__{data_list: datas}) do
    existing_ids =
      Enum.map(datas, fn data -> Data.get_value(data, "ID") end)
      |> Enum.filter(&is_integer/1)
      |> Enum.sort()

    find_least_missing(existing_ids, 0)
  end

  defp find_least_missing([], candidate), do: candidate

  defp find_least_missing([head | tail], candidate) do
    cond do
      head == candidate -> find_least_missing(tail, candidate + 1)
      head > candidate -> candidate
      # 仕様上発生し得ないので即エラー処理(IDは0以上)
      # 不正なIDを改変する関数を作ってもいい
      true -> raise "minus ID found: #{head}"
    end
  end

  defp attach_id(value_map, table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, get_least_available_id(table))
  end

  def get_data(%__MODULE__{data_list: datas}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(datas, filter_fun)

  defp modify_value_map(value_map, table) when is_map(value_map) do
    Enum.reduce(table.column_list, value_map, fn %Column{name: name} = column, acc ->
      if Map.has_key?(acc, name) do
        acc
      else
        val_init = Column.init_value(column, nil)
        Map.put(acc, name, val_init)
      end
    end)
  end

  def init_data(
        %__MODULE__{data_list: datas, column_list: column_list} = table,
        value_map
      )
      when is_map(value_map) do
    case DataMapValidator.validate_data(table, value_map, :add) do
      {:error, _} = err ->
        err

      {:ok, _v} ->
        new_data = value_map |> modify_value_map(table) |> attach_id(table) |> Data.new()
        {:ok, %{table | data_list: [new_data | datas]}}
    end
  end

  # add_data系統とかそういうのくらいはdataを直接くっつけるようにする

  def add_data!(%__MODULE__{} = table, %Data{} = data) do
    case add_data(table, data) do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def add_data(%__MODULE__{data_list: datas} = table, %Data{value_list: value_map} = data) do
    case DataMapValidator.validate_data(table, value_map, :add) do
      {:error, _} = err -> err
      {:ok, _v} -> {:ok, %{table | data_list: [data | datas]}}
    end
  end

  def delete_data!(%__MODULE__{} = table, %Data{} = data) do
    case delete_data(table, data) do
      # {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def delete_data(%__MODULE__{data_list: datas} = table, %Data{} = data) do
    # 削除したいdataが見つからない場合に律儀にエラーを返すようにするか？
    new_datas = Enum.filter(datas, &(&1 != data))
    # data_sub = datas -- new_datas

    # if length(data_sub) > safety_num and safety_num >= 0,
    #   do: Error.too_many_subject(data_sub, :delete),
    #  else:
    {:ok, %{table | data_list: new_datas}}
  end

  def edit_data!(%__MODULE__{} = table, %Data{} = data, %Data{} = new_data) do
    edit_data(table, data, new_data)
    |> case do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def edit_data(
        %__MODULE__{column_list: column_list, data_list: data_list} = table,
        %Data{} = data,
        %Data{value_list: new_value_map} = new_data
      ) do
    case DataMapValidator.validate_data(table, new_value_map, :edit, data) do
      {:error, _} = err -> err
      {:ok, _} -> {:ok, %{table | data_list: [new_data | List.delete(data_list, data)]}}
    end
  end

  # |> Thaqqa.DataTable.sort()
  def sort(%__MODULE__{data_list: datas} = dt) do
    sorted =
      Enum.sort(
        datas,
        &if(Thaqqa.Data.get_value(&1, "Order") == Thaqqa.Data.get_value(&2, "Order"),
          do: Thaqqa.Data.get_value(&1, "Priority") >= Thaqqa.Data.get_value(&2, "Priority"),
          else: Thaqqa.Data.get_value(&1, "Order") > Thaqqa.Data.get_value(&2, "Order")
        )
      )

    %__MODULE__{dt | data_list: sorted}
  end
end
