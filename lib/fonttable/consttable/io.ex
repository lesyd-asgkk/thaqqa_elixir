defmodule Thaqqa.ConstTable.IO do
  alias Thaqqa.ConstTable, as: ConstTable
  alias Thaqqa.DataTable, as: DataTable

  def new_from_request(json) when is_map(json),
    do: ConstTable.new() |> import_as_const(json["const_tables"])

  def import_as_const(%ConstTable{} = self, constdata) when is_map(constdata) do
    # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
    # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)

    Enum.reduce_while(constdata, {:ok, self}, fn {k, v}, {:ok, acc} ->
      case DataTable.import_table(k, v) do
        {:error, _} = err -> {:halt, err}
        {:ok, value} -> {:cont, {:ok, ConstTable.init_const_table(acc, value)}}
      end
    end)
  end
end
