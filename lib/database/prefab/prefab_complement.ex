defmodule Thaqqa.PrefabComplement do
  # prefabのFontのDatabase部分をstatic_tableで定義されているDatabase要素に同期させるモジュール
  # static_tableで定義されたテーブルがfontのtableとしてない場合、static_tableで定義されたデフォルト値込みのテーブルをそのまま反映させる。
  # static_tableで定義されていないテーブルがfontのtableに存在している場合、Fontのテーブルを削除する。

  # columnの整合性もチェックする。fontのtable上に存在しないcolumnは補完し、余分なcolumnは削除する。
  # type/subtypeが異なる場合も変更する。

  # PrefabComplement は宣言的完全同期を行うため、
  # static_table に定義されていない構造は保持されない。
  # 冪等性を持つ（連続でPrefabComplementによる同期処理を行っても結果は変化しない）

  # PrefabのFont,DataTable(local)の変更を伴う処理の後に実行すること。
  # ユーザーが意図的に入れた拡張も削除してしまう。
  # （json仕様側にdialect欄を付け加えることで、root側との重複が認められない限り削除処理を実行しない仕様を加えることは容易に可能。）
  # （現時点の当機能追加は未定。）

  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column
  alias Thaqqa.FontRegistry.Error, as: Error

  defp update_fonts(%Prefab{} = self, f), do: %Prefab{self | fonts: f}

  # overwrite_fontはどうせ内部にしか使わないのでエラー処理はない
  defp overwrite_font(%Prefab{} = self, name, %Thaqqa.Font{} = font) do
    if Prefab.get_font(self, name) != nil,
      do: update_fonts(self, Map.put(self.fonts, name, font)),
      else: self
  end

  ## static_tableの設定に合わせてfontの仕様を同期させる

  def complement_table_by_column(
        %Prefab{} = self,
        %DataTable{name: table_name} = datatable,
        column_name
      ) do
    static_table_column = Prefab.get_column(self, table_name, column_name)

    font_column =
      DataTable.get_column(datatable, fn %Column{name: name} -> name == column_name end)
      |> Enum.at(0)

    cond do
      # ここもcolumn_exist?に変更したうえでwithにする...必要もなさそう
      static_table_column == nil ->
        DataTable.delete_column(datatable, column_name)

      static_table_column != nil and font_column == nil ->
        DataTable.add_column!(datatable, static_table_column)

      true ->
        cond do
          static_table_column.type != font_column.type ||
              static_table_column.subtype != font_column.subtype ->
            DataTable.edit_column!(datatable, column_name, static_table_column)

          true ->
            datatable
        end

        # ここにcolumnのtype,subtypeの整合性チェックを追加
        #
    end
  end

  def complement_table(%Prefab{} = self, font_name, table_name) do
    font = Prefab.get_font(self, font_name)

    with %Font{} <- font,
         true <- Prefab.static_table_exists?(self, table_name) do
      case Prefab.local_static_table_exists?(self, table_name) do
        false ->
          overwrite_font(self, font_name, Font.delete_table(font, table_name))

        true ->
          complement_local_table(self, font, font_name, table_name)
      end
    else
      false ->
        overwrite_font(self, font_name, Font.delete_table(font, table_name))

      _ ->
        self
    end
  end

  defp complement_local_table(self, font, font_name, table_name) do
    case Prefab.get_table(self, font_name, table_name) do
      nil ->
        altered_font =
          Font.add_table(font, Prefab.get_static_table(self, table_name))

        overwrite_font(self, font_name, altered_font)

      table ->
        column_list = Prefab.get_column_list(self, table_name)

        if column_list == table.column_list do
          self
        else
          altered_prefab =
            Enum.reduce(
              column_list ++ table.column_list,
              self,
              fn %Column{name: column_name}, acc ->
                table_alt = Prefab.get_table(acc, font_name, table_name)
                font_alt = Prefab.get_font(acc, font_name)

                altered_table =
                  complement_table_by_column(acc, table_alt, column_name)

                altered_font = Font.edit_table(font_alt, table_name, altered_table)
                overwrite_font(acc, font_name, altered_font)
              end
            )
        end
    end
  end

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Prefab{} = self, font_name) do
    table_list =
      (Prefab.get_local_static_table_list(self)
       |> Enum.map(fn {k, _v} -> k end)) ++
        (Prefab.get_font(self, font_name).table_list
         |> Enum.map(fn %DataTable{name: name} -> name end))

    Enum.reduce(table_list, self, fn table_name, acc ->
      complement_table(acc, font_name, table_name)
    end)
  end

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%Prefab{} = self, table_name),
    do:
      Enum.reduce(Prefab.get_font_list(self), self, fn {font_name, _}, acc ->
        complement_table(acc, font_name, table_name)
      end)
end
