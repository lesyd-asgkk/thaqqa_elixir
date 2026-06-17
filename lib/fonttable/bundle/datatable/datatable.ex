defmodule Thaqqa.DataTable do
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data

  alias Thaqqa.DataTable.Query, as: Query
  alias Thaqqa.DataTable.Op, as: Op
  alias Thaqqa.DataTable.DataMapModifier, as: Modifier

  use Thaqqa.DataTable.Const

  defstruct [
    :name,
    :global,
    :static,
    :compile_rule,
    column_list: [],
    data_list: [],
    desc: "",
    single: false,
    data_hash: %{}
  ]

  # DataTableを新たに作る関数。
  def new(name, global \\ false, static \\ false, compile_rule \\ "none", single \\ false),
    do: %__MODULE__{
      name: name,
      global: global,
      static: static,
      compile_rule: compile_rule,
      desc: "",
      column_list: [],
      data_list: [],
      single: single,
      data_hash: %{}
    }

  # globalなテーブルか否かを返す関数。
  def is_global?(%__MODULE__{} = datatable), do: Query.is_global?(datatable)

  ### column系統
  # 指定したColumnをDataTableが保持するかを返す関数。
  def has_column?(%__MODULE__{} = datatable, column_name) when is_binary(column_name),
    do: Query.has_column?(datatable, column_name)

  # 条件に一致した全てのColumnの取得。
  def get_column(%__MODULE__{} = datatable, filter_fun) when is_function(filter_fun),
    do: Query.get_column(datatable, filter_fun)

  # 名前の一致するColumnの取得。
  def get_column(%__MODULE__{} = datatable, column_name) when is_binary(column_name),
    do: Query.get_column(datatable, column_name)

  def get_column(%__MODULE__{} = datatable), do: Query.get_column(datatable)

  # Columnを追加したDataTableを{:ok,%DataTable{}}の形式で返す関数。
  # 以下の条件でエラーを吐く。
  # 1.Columnの名前の重複
  # 2.不正なtype指定のされたColumn
  def add_column(%__MODULE__{} = table, %Column{} = column, val_init \\ nil),
    do: Op.add_column!(table, column, val_init)

  # Columnを追加したDataTableを返す関数。
  # エラーを吐いた場合はraise。
  def add_column!(%__MODULE__{} = table, %Column{} = column, val_init \\ nil),
    do: Op.add_column!(table, column, val_init)

  # Column情報を編集したDataTableを返す関数。削除するColumnの指定にはそのColumnのNameを使用する。
  # 返り値は{:ok,%DataTable{}}。削除すべきColumnが存在しない場合は{:error,%Error{}}。
  def delete_column(%__MODULE__{} = table, column_name), do: Op.delete_column(table, column_name)

  # Column情報を編集したDataTableを返す関数。削除するColumnの指定にはそのColumnのNameを使用する。
  # 削除すべきColumnが存在しない場合はraise。
  def delete_column!(%__MODULE__{} = table, column_name),
    do: Op.delete_column!(table, column_name)

  # Column情報を編集したDataTableを{:ok,%DataTable{}}の形式で返す関数。
  # 以下の条件で{:error,%Error{}}の形式でエラーを吐く。
  # 1.Columnの変更先の名前の重複
  # 2.不正なtype指定
  def edit_column(%__MODULE__{} = table, column_name, %Column{} = column),
    do: Op.edit_column(table, column_name, column)

  # Column情報を編集したDataTableを返す関数。
  # エラーを吐いた場合は即raise。
  def edit_column!(%__MODULE__{} = table, column_name, %Column{} = column),
    do: Op.edit_column!(table, column_name, column)

  # DataTable内で使用可能な最も小さいIDを返す。
  def get_least_available_id(%__MODULE__{} = datatable),
    do: Query.get_least_available_id(datatable)

  # 指定したDataをDataTableが保持するかを返す関数。
  def has_data?(%__MODULE__{} = datatable, %Data{} = data), do: Query.has_data?(datatable, data)

  # DataTableの保持するDataを条件指定で取得する関数。
  # 直接第二引数でDataを指定した場合はそのDataと完全一致するDataのみを返す。
  # 第二引数に何も指定しなかった場合は全てのDataを返す。
  def get_data(%__MODULE__{} = datatable, filter_fun) when is_function(filter_fun),
    do: Query.get_data(datatable, filter_fun)

  def get_data(%__MODULE__{} = datatable, %Data{} = data),
    do: Query.get_data(datatable, data)

  def get_data(%__MODULE__{} = datatable), do: Query.get_data(datatable)

  # IDをくっつけるサブルーチン。
  def attach_id(value_map, %__MODULE__{} = table) when is_map(value_map),
    do: Modifier.attach_id(value_map, table)

  # value_mapから足りていないColumnを補う関数。
  def modify_value_map(value_map, %__MODULE__{} = table) when is_map(value_map),
    do: Modifier.modify_value_map(value_map, table)

  # DataTableの初期化に用いる関数。
  # value_mapをDataにした上で追加する。
  def init_data(%__MODULE__{} = table, value_map)
      when is_map(value_map), do: Op.init_data(table, value_map)

  def add_data!(%__MODULE__{} = table, %Data{} = data), do: Op.add_data!(table, data)

  def add_data(%__MODULE__{data_list: datas} = table, %Data{} = data),
    do: Op.add_data(table, data)

  def delete_data!(%__MODULE__{} = table, %Data{} = data), do: Op.delete_data!(table, data)

  # 指定したデータを削除したDataTableを{:ok,%DataTable{}}の形で返す関数。
  # 削除するデータが存在しない場合は{:error,%Error{}}を返す
  def delete_data(%__MODULE__{} = table, %Data{} = data), do: Op.delete_data(table, data)

  # 指定したデータを書き換えたDataTableを{:ok,%DataTable{}}の形で返す関数。
  # 新たなデータがvalidate_dataの要件を満たさない場合は{:error,%Error{}}
  def edit_data(%__MODULE__{} = table, %Data{} = data, %Data{} = new_data),
    do: edit_data(table, data, new_data)

  # 指定したデータを書き換えたDataTableを返す関数。
  # エラーが生じた場合はraise。
  def edit_data!(%__MODULE__{} = table, %Data{} = data, %Data{} = new_data),
    do: edit_data!(table, data, new_data)

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
