defmodule Thaqqa.DataTable.Query do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Data, as: Data

  use Thaqqa.DataTable.Const

  # globalなテーブルか否かを返す関数。
  def is_global?(%DataTable{global: global}), do: global

  ### column系統
  # 指定したColumnをDataTableが保持するかを返す関数。
  def has_column?(%DataTable{} = datatable, column_name) when is_binary(column_name),
    do: get_column(datatable, column_name) != nil

  # 条件に一致した全てのColumnの取得。
  def get_column(%DataTable{column_list: columns}, filter_fun) when is_function(filter_fun),
    do: Enum.filter(columns, filter_fun)

  # 名前の一致するColumnの取得。
  def get_column(%DataTable{column_list: columns}, column_name) when is_binary(column_name),
    do: Enum.find(columns, fn %Column{name: name} -> name == column_name end)

  def get_column(%DataTable{} = datatable), do: get_column(datatable, fn _ -> true end)

  def get_least_available_id(%DataTable{data_list: datas}),
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

  def has_data?(%DataTable{} = datatable, %Data{} = data), do: get_data(datatable, data) != nil

  def get_data(%DataTable{data_list: datas}, filter_fun) when is_function(filter_fun),
    do: Enum.filter(datas, filter_fun)

  def get_data(%DataTable{data_list: datas}, %Data{} = data),
    do: Enum.find(datas, fn %Data{} = dt -> dt == data end)

  def get_data(%DataTable{} = datatable), do: get_data(datatable, fn _ -> true end)
end
