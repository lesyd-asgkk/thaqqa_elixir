# todo too_many_subjectの適応、かつ初期制限(safety_num)引数の追加

defmodule Thaqqa.DataTable do
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
  # defp init_val(val, type), do: init_val(val, type, :none)

  defp init_val(val, type, subtype) do
    val ||
      case type do
        :string ->
          ""

        :float ->
          0.0

        :int ->
          cond do
            subtype == :natural -> 1
            subtype == :id -> nil
            true -> 0
          end

        :bool ->
          false

        _ ->
          nil
      end
  end

  def is_value_valid?(val, type) do
    case type do
      :string -> is_binary(val)
      # integerでも問題はない
      :float -> is_float(val) || is_integer(val)
      :int -> is_integer(val)
      :bool -> is_boolean(val)
      :volatility -> true
    end
  end

  # :alig_x0,:alig_x1,:alig_y0は -1,0,1のみを取る
  # :non_negativeは0以上、:naturalは1以上

  def is_value_range_valid?(val, :int, subtype) do
    if !is_integer(val) do
      false
    else
      case subtype do
        h when h in [:alig_x0, :alig_x1, :alig_y0] -> val in [-1, 0, 1]
        :non_negative -> val >= 0
        :natural -> val >= 1
        _ -> true
      end
    end
  end

  def is_value_range_valid?(_val, :volatility, _subtype), do: true

  def is_value_range_valid?(val, :string, subtype) do
    if !is_binary(val) do
      false
    else
      case subtype do
        :language -> val in @language_list
        :writing_direction -> val in @writing_direction_list
        :gpos -> val in @gpos_list
        _ -> true
      end
    end
  end

  def is_value_range_valid?(val, type, _subtype) when type in [:float, :bool] do
    case type do
      :float -> is_float(val) || is_integer(val)
      :bool -> is_boolean(val)
    end
  end

  # column系統

  def get_column(%__MODULE__{column_list: columns}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(columns, filter_fun)

  def add_column!(
        %__MODULE__{} = table,
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
      Error.nominal_conflict_column(column_name, :add)
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
    if get_column(table, fn %Column{name: name} -> name == column_name end) != [] do
      Error.nominal_conflict_column(column_name, :edit)
    else
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

  defp id_validation(%__MODULE__{} = table, data_alt, _op) do
    column_list =
      get_column(table, fn %Column{subtype: st} -> st == :id end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, _v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if k_str in column_list,
        do: [Error.edit_locked(k_str, :id) | acc],
        else: [{:ok, nil} | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} -> {:cont, {:ok, acc}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  # unique_column_conflictはtablenameを反映させるようにする
  def unique_validation(%__MODULE__{name: tablename} = table, data_alt, op) do
    column_list =
      get_column(table, fn %Column{subtype: st} -> st in [:name, :id] end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if k_str in column_list do
        if get_data(table, &(&1 |> Thaqqa.Data.get_val(k_str) == v and v not in ["", nil])) != [],
          do: [Error.unique_column_conflict(tablename, k_str, v, op) | acc],
          else: [{:ok, nil} | acc]
      else
        [{:ok, nil} | acc]
      end
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} -> {:cont, {:ok, acc}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  def column_validation(%__MODULE__{name: tablename} = table, data_alt, op) do
    column_list =
      get_column(table, fn %Column{subtype: st} -> st in [:name, :id] end)
      |> Enum.map(fn %Column{name: name} -> name end)

    Enum.reduce(data_alt, [], fn {k, v}, acc ->
      k_str = if is_atom(k), do: Atom.to_string(k), else: k

      if k_str in column_list,
        do: [{:ok, nil} | acc],
        else: [Error.column_not_found(tablename, k_str, v, op) | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} ->
        {:cont, {:ok, acc}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> {:ok, nil}
    end
  end

  defp validate_data(table, new_value_map, column_list, :add = op, force) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        if force do
          unique_validation(table, new_value_map, op)
        else
          case column_validation(table, new_value_map, op) do
            {:error, msg} -> {:error, msg}
            {:ok, _} -> unique_validation(table, new_value_map, op)
          end
        end
    end
  end

  defp validate_data(table, new_value_map, column_list, :edit = op, _force) do
    case validate_value_map(new_value_map, column_list) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        case id_validation(table, new_value_map, op) do
          {:error, msg} ->
            {:error, msg}

          {:ok, _} ->
            unique_validation(table, new_value_map, op)
        end
    end
  end

  def get_data(%__MODULE__{data_list: datas}, filter_fun \\ fn _ -> true end),
    do: Enum.filter(datas, filter_fun)

  defp validate_value_map(value_map, column_list) when is_map(value_map) do
    # ※volatilityの編集拒否はwrapper module側(LetterEditorとか)で行う
    Enum.reduce(column_list, [], fn %Column{name: name, type: type, subtype: subtype}, acc ->
      if Map.has_key?(value_map, name),
        do:
          (cond do
             !is_value_valid?(Map.get(value_map, name), type) ->
               [Error.invalid_value_type(Map.get(value_map, name), type) | acc]

             !is_value_range_valid?(Map.get(value_map, name), type, subtype) ->
               [Error.invalid_value_range(Map.get(value_map, name), type, subtype) | acc]

             true ->
               [{:ok, nil} | acc]
           end),
        else: [{:ok, nil} | acc]
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, _str}, {:ok, acc} ->
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
    Enum.reduce(table.column_list, value_map, fn %Column{name: name, type: type, subtype: subtype},
                                                 acc ->
      if Map.has_key?(acc, name) do
        acc
      else
        val_init = init_val(nil, type, subtype)
        Map.put(acc, name, val_init)
      end
    end)
  end

  def add_data!(%__MODULE__{} = table, value_map, force \\ false) when is_map(value_map) do
    add_data(table, value_map, force)
    |> case do
      {:error, msg} -> raise msg
      {:ok, v} -> v
    end
  end

  def add_data(
        %__MODULE__{data_list: datas, column_list: column_list} = table,
        value_map,
        force \\ false
      )
      when is_map(value_map) do
    case validate_data(table, value_map, column_list, :add, force) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _v} ->
        value_map = value_map |> modify_value_map(table) |> attach_id(table)
        new_data = %Data{value_list: value_map}
        {:ok, %{table | data_list: [new_data | datas]} |> Thaqqa.DataTable.sort(force)}
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
    case validate_data(table, new_value_map, column_list, :edit, false) do
      {:error, msg} ->
        {:error, msg}

      {:ok, _} ->
        new_datas =
          Enum.map(datas, fn %Data{} = data ->
            if filter_fun.(data),
              do: %Data{data | value_list: Map.merge(data.value_list, new_value_map)},
              else: data
          end)

        data_sub = datas -- new_datas

        if length(data_sub) > safety_num,
          do: Error.too_many_subject(data_sub, :delete),
          else: {:ok, %{table | data_list: new_datas} |> Thaqqa.DataTable.sort()}
    end
  end

  def sort(%__MODULE__{data_list: datas} = dt, force \\ false) do
    if force do
      dt
    else
      sorted =
        Enum.sort(
          datas,
          &cond do
            Thaqqa.Data.get_val(&1, "Order") < Thaqqa.Data.get_val(&2, "Order") -> true
            Thaqqa.Data.get_val(&1, "Order") > Thaqqa.Data.get_val(&2, "Order") -> false
            true -> Thaqqa.Data.get_val(&1, "Priority") <= Thaqqa.Data.get_val(&2, "Priority")
          end
        )

      %__MODULE__{dt | data_list: sorted}
    end
  end

  def update_fontregistry(%__MODULE__{name: name, parent: nil} = table),
    do: FontRegistry.edit_static_table(name, table)

  def update_fontregistry(%__MODULE__{name: name, parent: parent} = table) do
    {:ok, parent_font} = FontRegistry.get_font(parent)
    parent_font |> Font.edit_table(name, table) |> Font.update_fontregistry()
  end

  def update_fontregistry(%{} = map),
    do: Enum.map(map, fn %__MODULE__{} = table -> update_fontregistry(table) end)
end
