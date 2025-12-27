defmodule Thaqqa.DataTable do
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Font, as: Font

  defstruct [
    :name,
    :parent,
    column_list: [],
    data_list: [],
    desc: ""
  ]

  def new(name, parent),
    do: %__MODULE__{name: name, parent: parent, desc: "", column_list: [], data_list: []}

  # 初期値設定のため
  defp init_val(val, type, subtype \\ nil) do
    val ||
      case type do
        :string -> ""
        :float -> 0.0
        :int -> if subtype == :natural, do: 1, else: 0
        :bool -> false
        _ -> nil
      end
  end

  def is_value_valid?(val, type) do
    case type do
      :string -> is_binary(val)
      # integerでも問題はない
      :float -> is_float(val) || is_integer(val)
      :int -> is_integer(val)
      :bool -> is_boolean(val)
    end
  end

  def get_column(%__MODULE__{column_list: columns}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(columns, filter_fun)

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
        subtype \\ :none,
        val_init \\ nil,
        dev \\ false
      ) do
    if get_column(table, fn %Column{name: name} -> name == column_name end) != [] do
      Error.nominal_conflict_column(column_name)
    else
      if !Column.is_available_type(type) do
        Error.invalid_datatype(type)
      else
        val_init = init_val(val_init, type, subtype)

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
    if Map.has_key?(value_map, "ID") do
      value_map
    else
      least_id = get_least_available_id(table)
      Map.put(value_map, "ID", least_id)
      value_map
    end
  end

  defp valify_value_map(value_map, table) when is_map(value_map) do
    # Enum.reduce_while
    Enum.reduce(table.column_list, [], fn %Column{
                                            name: name,
                                            type: type,
                                            subtype: subtype
                                          },
                                          acc ->
      if Map.has_key?(value_map, name) do
        if !is_value_valid?(Map.get(value_map, name), type),
          do: [Error.invalid_value_type(Map.get(value_map, name), type) | acc],
          else: [{:ok, nil} | acc]
      end
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, str}, {:ok, acc} ->
        {:cont, {:ok, acc}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, value_map}
    end
  end

  defp modify_value_map(value_map, table) when is_map(value_map) do
    Enum.reduce(table.column_list, value_map, fn %Column{
                                                   name: name,
                                                   type: type,
                                                   subtype: subtype
                                                 },
                                                 acc ->
      if Map.has_key?(acc, name) do
        # 事前にコンパイルしておく
        if type == :string and subtype == :pre_compiled,
          do: Map.put(acc, name, Map.get(acc, name) |> Regex.compile!()),
          else: acc
      else
        val_init = init_val(nil, type, subtype)
        Map.put(acc, name, val_init)
      end
    end)
  end

  # todo:subtypeが:nameの項目の値が重複する場合(空文字を除く)は作成拒否する
  # editでも同様。さらにeditでは問答無用でid相手への編集を弾く
  # precompileの編集拒否はwrapper module側(LetterEditorとか)で行う

  # 値チェックも行う（intに対してfloatを入れるとエラーを吐くとか、subtype上の問題でエラーを吐くとか）
  # is_value_valid?()
  #
  def add_data!(%__MODULE__{} = table, value_map) when is_map(value_map) do
    case add_data(table, value_map) do
      {:error, msg} -> raise msg
      {:ok, v} -> v
    end
  end

  def add_data(%__MODULE__{data_list: datas} = table, value_map) when is_map(value_map) do
    value_map = value_map |> valify_value_map(table)

    case value_map do
      {:error, msg} ->
        {:error, msg}

      {:ok, v} ->
        value_map = v |> modify_value_map(table) |> attach_id(table)
        new_data = %Data{value_list: value_map}
        {:ok, %{table | data_list: datas ++ [new_data]}}
    end
  end

  def delete_data(%__MODULE__{data_list: datas} = table, filter_fun) do
    new_datas = Enum.filter(datas, filter_fun)
    %{table | data_list: new_datas}
  end

  def edit_data(%__MODULE__{data_list: datas} = table, filter_fun, new_value_list) do
    new_datas =
      Enum.map(datas, fn data ->
        if filter_fun.(data),
          do: %Data{data | value_list: Map.merge(data.value_list, new_value_list)},
          else: data
      end)

    %{table | data_list: new_datas}
  end

  def update_fontregistry(%__MODULE__{name: name, parent: nil} = table),
    do: Thaqqa.FontRegistry.edit_static_table(name, table)

  def update_fontregistry(%__MODULE__{name: name, parent: parent} = table),
    do: Font.edit_table(parent, name, table) |> Font.update_fontregistry()
end
