defmodule Thaqqa.ConstTable.Complement do
  # prefabのFontのDatabase部分をstatic_tableで定義されているDatabase要素に同期させるモジュール
  # static_tableで定義されたテーブルがfontのtableとしてない場合、static_tableで定義されたデフォルト値込みのテーブルをそのまま反映させる。
  # static_tableで定義されていないテーブルがfontのtableに存在している場合、Fontのテーブルを削除する。

  # columnの整合性もチェックする。fontのtable上に存在しないcolumnは補完し、余分なcolumnは削除する。
  # type/subtypeが異なる場合も変更する。

  # Bundle.Complement は宣言的完全同期を行うため、
  # static_table に定義されていない構造は保持されない。
  # 冪等性を持つ（連続でBundle.Complementによる同期処理を行っても結果は変化しない）

  # BundleのFont,DataTable(local)の変更を伴う処理の後に実行すること。
  # ユーザーが意図的に入れた拡張も削除してしまう。
  # （json仕様側にdialect欄を付け加えることで、root側との重複が認められない限り削除処理を実行しない仕様を加えることは容易に可能。）
  # （現時点の当機能追加は未定。）

  # なお、後から並列化可能な形としている。

  @concurrency_percentage 50
  @chunk_percentage 25

  alias Thaqqa.ConstTable, as: ConstTable
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  ## const_tableの設定に合わせてbundleのstの仕様を同期させる

  def complement_table_by_column(
        %ConstTable{} = self,
        %DataTable{name: table_name} = datatable,
        %Column{name: column_name}
      ) do
    const_table_column = ConstTable.get_column(self, table_name, column_name)

    bundle_table_column =
      DataTable.get_column(datatable, fn %Column{name: name} -> name == column_name end)
      |> Enum.at(0)

    cond do
      # ここもcolumn_exist?に変更したうえでwithにする...必要もなさそう
      const_table_column == nil ->
        DataTable.delete_column(datatable, column_name)

      const_table_column != nil and bundle_table_column == nil ->
        DataTable.add_column!(datatable, const_table_column)

      const_table_column.type != bundle_table_column.type ||
          const_table_column.subtype != bundle_table_column.subtype ->
        DataTable.edit_column!(datatable, column_name, const_table_column)

      true ->
        datatable
    end
  end

  # 指定したtable(指定はtable_name)をbundle側と照らし合わせて削除する
  # bundle側に存在しない(あるいはglobalとして存在))場合は削除処理
  # 存在する場合はcomplement_local_tableに映る。
  # 返り値はtable型
  def complement_table(%ConstTable{} = self, %DataTable{name: table_name} = table) do
    with true <- ConstTable.const_table_exists?(self, table_name),
         false <- ConstTable.static_const_table_exists?(self, table_name) do
      complement_local_table(self, table)
    else
      false -> nil
      true -> ConstTable.get_const_table(self, table_name)
      _ -> table
    end
  end

  # bundle側にしか存在しない場合はそのテーブルの複製・追加処理
  # bundle側にもfont側にも存在する場合はfont側をbundleと照らし合わせて
  # 過不足がない状態にする。

  defp complement_local_table(
         %ConstTable{} = self,
         %DataTable{name: table_name} = table
       ) do
    column_list = ConstTable.get_column_list(self, table_name)
    tmp = ConstTable.get_const_table(self, table_name)
    table = %{table | global: tmp.global, static: tmp.static}

    if column_list == table.column_list do
      table
    else
      Enum.reduce(
        column_list ++ table.column_list,
        table,
        fn %Column{name: column_name}, acc ->
          complement_table_by_column(self, acc, column_name)
        end
      )
    end
  end

  def complement_bundle(%ConstTable{} = self, %Bundle{} = bundle) do
    tablename_list = bundle.static_tables |> Enum.map(fn v -> v.name end)

    table_list =
      ((ConstTable.get_const_table_list(self)
        |> Enum.map(fn {k, v} -> if k in tablename_list, do: nil, else: v end)) ++
         bundle.static_tables)
      |> Enum.filter(fn v -> v != nil end)
      |> Enum.map(fn %DataTable{} = table -> complement_table(self, table) end)
      |> Enum.filter(fn v -> v != nil end)
      |> Enum.reduce(%{}, fn table, acc -> Map.put(acc, table.name, table) end)

    %Bundle{bundle | static_tables: table_list}
  end

  # static_tableの変更に伴ってfontテーブル側を変更する
  # TODO:帰り値はbundle型にするのと
  # 並列化を行う
  def complement(%ConstTable{} = self, bundles) when is_map(bundles) do
    Enum.reduce(%{}, fn {bundle_name, bundle}, acc ->
      bundle = complement_bundle(self, bundle) |> Bundle.complement()
      Map.put(acc, bundle_name, bundle)
    end)
  end
end
