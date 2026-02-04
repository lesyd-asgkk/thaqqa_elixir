# todo too_many_subjectの適応、かつ初期制限(safety_num)引数の追加

defmodule Thaqqa.DataTable do
  alias Thaqqa.FontRegisteryPrefab, as: FontRegisteryPrefab

  alias Thaqqa.DataValidator, as: DataValidator
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Font, as: Font

  use Thaqqa.DataTable.Const

  defstruct [
    :name,
    :global,
    :parent,
    column_list: [],
    data_list: [],
    desc: ""
  ]

  def new(name, global, parent),
    do: %__MODULE__{
      name: name,
      global: global,
      parent: parent,
      desc: "",
      column_list: [],
      data_list: []
    }

  def is_global?(%__MODULE__{global: global}), do: global

  # 初期値設定のため

  # column系統。get_column以外は全部書き換える（見づらすぎ）

  def get_column(%__MODULE__{column_list: columns}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(columns, filter_fun)

  def add_column!(%__MODULE__{} = table, %Column{} = column, val_init \\ nil) do
    case add_column(table, column, val_init) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
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
        val_init = Column.init_val(column, val_init)
        datalist = Enum.map(datalist, fn data -> Data.set_val(data, column_name, val_init) end)

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

    new_datalist =
      Enum.map(datalist, fn data ->
        %{data | value_list: Map.delete(data.value_list, column_name)}
      end)

    %{table | column_list: new_cols, data_list: new_datalist}
  end

  def edit_column(
        %__MODULE__{column_list: col_list} = table,
        column_name,
        %Column{name: new_name} = column
      ) do
    if get_column(table, fn %Column{name: name} -> name == column_name end) != [] do
      Error.nominal_conflict_column(column_name, :edit)
    else
      new_cols =
        Enum.map(col_list, fn
          %Column{name: ^column_name} = col -> column
          col -> col
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
  end

  # data系統

  def get_least_available_id(%__MODULE__{data_list: datas}) do
    existing_ids =
      Enum.map(datas, fn data -> Data.get_val(data, "ID") end)
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
        val_init = Column.init_val(column, nil)
        Map.put(acc, name, val_init)
      end
    end)
  end

  # init_dataを付け加える

  def init_data(
        %__MODULE__{data_list: datas, column_list: column_list} = table,
        value_map
      )
      when is_map(value_map) do
    case DataValidator.validate_data(table, value_map, :add, true) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _v} ->
        value_map = value_map |> modify_value_map(table) |> attach_id(table)
        new_data = %Data{value_list: value_map}
        {:ok, %{table | data_list: [new_data | datas]}}
    end
  end

  def add_data!(%__MODULE__{} = table, value_map) when is_map(value_map) do
    add_data(table, value_map)
    |> case do
      {:error, msg} -> raise msg
      {:ok, v} -> v
    end
  end

  def add_data(
        %__MODULE__{data_list: datas, column_list: column_list} = table,
        value_map
      )
      when is_map(value_map) do
    case DataValidator.validate_data(table, value_map, :add, false) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _v} ->
        value_map = value_map |> modify_value_map(table) |> attach_id(table)
        new_data = %Data{value_list: value_map}
        {:ok, %{table | data_list: [new_data | datas]} |> Thaqqa.DataTable.sort()}
    end
  end

  def delete_data!(%__MODULE__{} = table, filter_fun, safety_num \\ 1) do
    delete_data(table, filter_fun, safety_num)
    |> case do
      {:error, msg} -> raise msg
      {:ok, v} -> v
    end
  end

  def delete_data(%__MODULE__{data_list: datas} = table, filter_fun, safety_num \\ 1) do
    new_datas = Enum.filter(datas, filter_fun)
    data_sub = datas -- new_datas

    if length(data_sub) > safety_num,
      do: Error.too_many_subject(data_sub, :delete),
      else: {:ok, %{table | data_list: new_datas}}
  end

  def edit_data!(%__MODULE__{} = table, filter_fun, new_value_map, safety_num \\ 1) do
    edit_data(table, filter_fun, new_value_map, safety_num)
    |> case do
      {:error, msg} -> raise msg
      {:ok, v} -> v
    end
  end

  def edit_data(
        %__MODULE__{data_list: datas, column_list: column_list} = table,
        filter_fun,
        new_value_map,
        safety_num \\ 1
      ) do
    case DataValidator.validate_data(table, new_value_map, :edit, false) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        new_datas =
          Enum.map(datas, fn %Data{} = data ->
            if filter_fun.(data),
              do: %Data{data | value_list: Map.merge(data.value_list, new_value_map)},
              else: data
          end)

        data_substraction = datas -- new_datas

        if length(data_substraction) > safety_num,
          do: Error.too_many_subject(data_substraction, :delete),
          else: {:ok, %{table | data_list: new_datas} |> Thaqqa.DataTable.sort()}
    end
  end

  def sort(%__MODULE__{data_list: datas} = dt) do
    sorted =
      Enum.sort(
        datas,
        &if(Thaqqa.Data.get_val(&1, "Order") == Thaqqa.Data.get_val(&2, "Order"),
          do: Thaqqa.Data.get_val(&1, "Priority") <= Thaqqa.Data.get_val(&2, "Priority"),
          else: Thaqqa.Data.get_val(&1, "Order") < Thaqqa.Data.get_val(&2, "Order")
        )
      )

    %__MODULE__{dt | data_list: sorted}
  end

  def update_fontregistry(%__MODULE__{name: name, parent: nil} = table),
    do: FontRegistry.edit_static_table(name, table)

  def update_fontregistry(%__MODULE__{name: name, parent: parent} = table) do
    {:ok, parent_font} = FontRegistry.get_font(parent)
    parent_font |> Font.edit_table(name, table) |> Font.update_fontregistry()
  end

  def update_fontregistry(%{} = map),
    do: Enum.map(map, fn %__MODULE__{} = table -> update_fontregistry(table) end)

  def update_prefab(
        %__MODULE__{name: name, parent: nil} = table,
        %FontRegisteryPrefab{} = prefab
      ),
      do: FontRegisteryPrefab.edit_static_table(prefab, name, table)

  def update_prefab(
        %__MODULE__{name: name, parent: parent} = table,
        %FontRegisteryPrefab{} = prefab
      ) do
    {:ok, parent_font} = FontRegisteryPrefab.get_font(parent)
    parent_font |> Font.edit_table(name, table) |> Font.update_prefab(prefab)
  end

  def update_prefab(%{} = map, %FontRegisteryPrefab{} = prefab),
    do: Enum.map(map, fn %__MODULE__{} = table -> update_prefab(table, prefab) end)
end
