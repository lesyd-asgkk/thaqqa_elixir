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

  # DataTableを新たに作る関数。
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

  # globalなテーブルか否かを返す関数。
  def is_global?(%__MODULE__{global: global}), do: global

  ### column系統
  # 指定したColumnをDataTableが保持するかを返す関数。
  def has_column?(%__MODULE__{} = datatable, column_name) when is_binary(column_name),
    do: get_column(datatable, column_name) != nil

  # 条件に一致した全てのColumnの取得。
  def get_column(%__MODULE__{column_list: columns}, filter_fun) when is_function(filter_fun),
    do: Enum.filter(columns, filter_fun)

  # 名前の一致するColumnの取得。
  def get_column(%__MODULE__{column_list: columns}, column_name) when is_binary(column_name),
    do: Enum.find(columns, fn %Column{name: name} -> name == column_name end)

  def get_column(%__MODULE__{} = datatable), do: get_column(datatable, fn _ -> true end)

  # Columnを追加したDataTableを{:ok,%DataTable{}}の形式で返す関数。
  # 以下の条件でエラーを吐く。
  # 1.Columnの名前の重複
  # 2.不正なtype指定のされたColumn
  def add_column(
        %__MODULE__{data_list: datalist, column_list: col_list} = table,
        %Column{name: column_name, type: type} = column,
        val_init \\ nil
      ) do
    if has_column?(table, column_name) do
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

  # Columnを追加したDataTableを返す関数。
  # エラーを吐いた場合は即raise。
  def add_column!(%__MODULE__{} = table, %Column{} = column, val_init \\ nil) do
    case add_column(table, column, val_init) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  # Column情報を編集したDataTableを返す関数。削除するColumnの指定にはそのColumnのNameを使用する。
  # 返り値は{:ok,%DataTable{}}。削除すべきColumnが存在しない場合は{:error,%Error{}}。
  def delete_column(
        %__MODULE__{column_list: column_list, data_list: data_list, name: table_name} = table,
        column_name
      ) do
    if !has_column?(table, column_name) do
      Error.column_not_found(table_name, column_name, :delete)
    else
      new_columnlist = Enum.filter(column_list, fn %Column{name: name} -> name != column_name end)

      new_datalist = Enum.map(data_list, fn data -> Data.delete_value(data, column_name) end)

      {:ok, %{table | column_list: new_columnlist, data_list: new_datalist}}
    end
  end

  def delete_column!(%__MODULE__{} = table, column_name) do
    case delete_column(table, column_name) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  # Column情報を編集したDataTableを{:ok,%DataTable{}}の形式で返す関数。
  # 以下の条件で{:error,%Error{}}の形式でエラーを吐く。
  # 1.Columnの変更先の名前の重複
  # 2.不正なtype指定
  def edit_column(
        %__MODULE__{column_list: col_list} = table,
        column_name,
        %Column{name: new_name, type: type} = column
      ) do
    if has_column?(table, column_name) and
         column_name != new_name do
      Error.nominal_conflict_column(column_name, :edit)
    else
      if !Column.is_available_type(type) do
        Error.invalid_datatype(type)
      else
        new_cols =
          Enum.map(col_list, fn
            %Column{name: ^column_name} -> column
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
  end

  def edit_column!(%__MODULE__{} = table, column_name, %Column{} = column) do
    case edit_column(table, column_name, column) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  # DataTable内で使用可能な最も小さいIDを返す。
  def get_least_available_id(%__MODULE__{data_list: datas}),
    do:
      Enum.map(datas, fn data -> Data.get_value(data, "ID") end)
      |> Enum.sort()
      |> find_least_missing(0)

  # ↑の為のサブルーチン。
  # 簡単に言えば事前に昇順に整列したIDのリストを元に、配列の頭の値と照合用の値（初期値0）と照合。
  # 同じ値でなければ照合用の値を返し、同じ値であれば 配列の次の値と(照合用の値+1)とを照合。
  # 仕様上ありえないが、配列の頭の値 < 照合用の値 となった場合は即raiseとした。
  defp find_least_missing([], candidate), do: candidate

  defp find_least_missing([head | tail], candidate) do
    cond do
      head == candidate -> find_least_missing(tail, candidate + 1)
      head > candidate -> candidate
      # 仕様上発生し得ないので即エラー処理(IDは0以上)
      # 不正なID指定を自動で修正するシステムを作っても良い。
      true -> raise "minus ID found: #{head}"
    end
  end

  # IDをくっつけるサブルーチン。
  defp attach_id(value_map, table) when is_map(value_map) do
    if Map.has_key?(value_map, @id) and Map.get(value_map, @id) != nil,
      do: value_map,
      else: Map.put(value_map, @id, get_least_available_id(table))
  end

  # 指定したDataをDataTableが保持するかを返す関数。
  def has_data?(%__MODULE__{} = datatable, %Data{} = data), do: get_data(datatable, data) != nil

  # DataTableの保持するDataを条件指定で取得する関数。
  # 直接第二引数でDataを指定した場合はそのDataと完全一致するDataのみを返す。
  # 第二引数に何も指定しなかった場合は全てのDataを返す。
  def get_data(%__MODULE__{data_list: datas}, filter_fun) when is_function(filter_fun),
    do: Enum.filter(datas, filter_fun)

  def get_data(%__MODULE__{data_list: datas}, %Data{} = data),
    do: Enum.find(datas, fn %Data{} = dt -> dt == data end)

  def get_data(%__MODULE__{} = datatable), do: get_data(datatable, fn _ -> true end)

  # value_mapから足りていないColumnを補う関数。
  defp modify_value_map(value_map, %__MODULE__{column_list: column_list})
       when is_map(value_map) do
    Enum.reduce(column_list, value_map, fn %Column{name: name} = column, acc ->
      if Map.has_key?(acc, name) do
        acc
      else
        val_init = Column.init_value(column, nil)
        Map.put(acc, name, val_init)
      end
    end)
  end

  # DataTableの初期化に用いる関数。
  # value_mapをDataにした上で追加する。
  def init_data(%__MODULE__{data_list: datas} = table, value_map)
      when is_map(value_map) do
    case DataMapValidator.validate_data(table, value_map, :add) do
      {:error, _} = err ->
        err

      {:ok, _v} ->
        new_data = value_map |> modify_value_map(table) |> attach_id(table) |> Data.new()
        {:ok, %{table | data_list: [new_data | datas]}}
    end
  end

  def add_data!(%__MODULE__{} = table, %Data{} = data) do
    case add_data(table, data) do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  def add_data(%__MODULE__{data_list: datas} = table, %Data{value_list: value_map} = data) do
    case DataMapValidator.validate_data(table, value_map, :add) do
      {:error, _} = err -> err
      {:ok, _} -> {:ok, %__MODULE__{table | data_list: [data | datas]}}
    end
  end

  def delete_data!(%__MODULE__{} = table, %Data{} = data) do
    case delete_data(table, data) do
      {:error, reason} -> raise reason
      {:ok, value} -> value
    end
  end

  # 指定したデータを削除したDataTableを{:ok,%DataTable{}}の形で返す関数。
  # 削除するデータが存在しない場合は{:error,%Error{}}を返す
  def delete_data(%__MODULE__{data_list: datas, name: tablename} = table, %Data{} = data) do
    if !has_data?(table, data) do
      Error.data_struct_not_found(data, tablename, nil)
    else
      new_datas = Enum.filter(datas, &(&1 != data))
      {:ok, %__MODULE__{table | data_list: new_datas}}
    end
  end

  # 指定したデータを書き換えたDataTableを{:ok,%DataTable{}}の形で返す関数。
  # 新たなデータがvalidate_dataの要件を満たさない場合は{:error,%Error{}}
  def edit_data(
        %__MODULE__{data_list: data_list, name: tablename} = table,
        %Data{} = data,
        %Data{value_list: new_value_map} = new_data
      ) do
    if !has_data?(table, data) do
      Error.data_struct_not_found(data, tablename, nil)
    else
      case DataMapValidator.validate_data(table, new_value_map, :edit, data) do
        {:error, _} = err -> err
        {:ok, _} -> {:ok, %{table | data_list: [new_data | List.delete(data_list, data)]}}
      end
    end
  end

  # 指定したデータを書き換えたDataTableを返す関数。
  # エラーが生じた場合はraise。
  def edit_data!(%__MODULE__{} = table, %Data{} = data, %Data{} = new_data) do
    edit_data(table, data, new_data)
    |> case do
      {:error, reason} -> raise reason
      {:ok, v} -> v
    end
  end

  # Order,Priorityの値に応じて昇順で並び替える。
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

#
