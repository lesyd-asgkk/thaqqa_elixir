defmodule Thaqqa.Bundle.Complement do
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

  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Column, as: Column

  ## static_tableの設定に合わせてfontの仕様を同期させる

  def complement_table_by_column(
        %Bundle{} = self,
        %DataTable{name: table_name} = datatable,
        %Column{name: column_name}
      ) do
    static_table_column = Bundle.get_column(self, table_name, column_name)

    font_column =
      DataTable.get_column(datatable, fn %Column{name: name} -> name == column_name end)
      |> Enum.at(0)

    cond do
      # ここもcolumn_exist?に変更したうえでwithにする...必要もなさそう
      static_table_column == nil ->
        DataTable.delete_column(datatable, column_name)

      static_table_column != nil and font_column == nil ->
        DataTable.add_column!(datatable, static_table_column)

      static_table_column.type != font_column.type ||
          static_table_column.subtype != font_column.subtype ->
        DataTable.edit_column!(datatable, column_name, static_table_column)

      true ->
        datatable
    end
  end

  # 指定したtable(指定はtable_name)をbundle側と照らし合わせて削除する
  # bundle側に存在しない(あるいはglobalとして存在))場合は削除処理
  # 存在する場合はcomplement_local_tableに映る。
  # 返り値はtable型
  def complement_table(
        %Bundle{} = self,
        %DataTable{name: table_name} = table
      ) do
    with true <- Bundle.static_table_exists?(self, table_name),
         false <- Bundle.local_static_table_exists?(self, table_name) do
      complement_local_table(self, table)
    else
      false -> nil
      _ -> table
    end
  end

  # bundle側にしか存在しない場合はそのテーブルの複製・追加処理
  # bundle側にもfont側にも存在する場合はfont側をbundleと照らし合わせて
  # 過不足がない状態にする。

  defp complement_local_table(
         %Bundle{} = self,
         %DataTable{name: table_name} = table
       ) do
    column_list = Bundle.get_column_list(self, table_name)

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

  # 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Bundle{} = self, %Font{name: font_name} = font) do
    tablename_list = font.table_list |> Enum.map(fn {_, v} -> v.name end)
    font_table_list = font.table_list |> Enum.map(fn {k, v} -> {k, v} end)

    table_list =
      ((Bundle.get_local_static_table_list(self)
        |> Enum.map(fn {k, v} -> if k in tablename_list, do: {k, nil}, else: {k, v} end)) ++
         font_table_list)
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.map(fn {k, %DataTable{} = table} ->
        {k, complement_table(self, table)}
      end)
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Map.new(fn {k, v} -> {k, v} end)

    %Bundle{self | fonts: Map.put(self.fonts, font_name, %Font{font | table_list: table_list})}
  end

  # static_tableの変更に伴ってfontテーブル側を変更する
  # TODO:帰り値はbundle型にするのと
  # 並列化を行う
  def complement_by_static_table(%Bundle{} = self, %DataTable{name: table_name} = datatable) do
    fonts =
      Enum.reduce(Bundle.get_font_list(self), %{}, fn {font_name, font}, acc ->
        font = %Font{
          font
          | table_list: Map.put(font.table_list, table_name, complement_table(self, datatable))
        }

        Map.put(acc, font_name, font)
      end)

    %Bundle{self | fonts: fonts}
  end

  def complement(%Bundle{} = self) do
    fonts =
      Enum.reduce(Bundle.get_font_list(self), %{}, fn {_, font}, acc ->
        complement_font(acc, font)
      end)

    %Bundle{self | fonts: fonts}
  end
end
