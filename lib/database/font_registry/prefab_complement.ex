defmodule Thaqqa.PrefabComplement do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Data, as: Data
  alias Thaqqa.Column, as: Column

  defp update_fonts(%Prefab{} = self, f), do: %Prefab{self | fonts: f}
  # overwrite_fontは内部にしか使わないのでエラー処理はない
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
    cond do
      Prefab.get_column(self, table_name, column_name) == [] ->
        DataTable.delete_column(datatable, column_name)

      Prefab.get_column(self, table_name, column_name) != [] and
          DataTable.get_column(datatable, fn %Column{name: name} -> name == column_name end) == [] ->
        DataTable.add_column!(datatable, column_name)

      true ->
        datatable
    end
  end

  def complement_table(%Prefab{} = self, font_name, table_name) do
    font = Prefab.get_font(self, font_name)

    cond do
      # フォントが見つからない場合。
      is_nil(font) ->
        self

      # テーブルが見つからない場合。（
      Prefab.get_static_table_list(self) |> Enum.find(fn {k, _} -> k == table_name end) == [] ->
        self

      # loaclテーブル上に見つからない（すなわちglobal上にあると断定できる）場合
      Prefab.get_static_table_list_local(self)
      |> Enum.find(fn {k, _} -> k == table_name end) == [] ->
        overwrite_font(self, font_name, Font.delete_table(font, table_name))

      # 残り、すなわちlocalテーブル上にあると断定できる場合。
      true ->
        table = Prefab.get_table(self, font_name, table_name)

        if is_nil(table) do
          # テーブル自体を補完
          altered_font = Font.add_table(font, Prefab.get_static_table(self, table_name))
          overwrite_font(self, font_name, altered_font)
        else
          # column毎の補完・削除処理。
          # complement_table_base_on_columnに分離するか。
          altered_font =
            Enum.reduce(Prefab.get_column_list(self, table_name), font, fn column, font_alt ->
              altered_table = complement_table_by_column(self, table, column.name)
              Font.edit_table(font_alt, table_name, altered_table)
            end)

          overwrite_font(self, font_name, altered_font)
        end
    end
  end

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Prefab{} = self, font_name),
    do:
      Enum.reduce(Prefab.get_static_table_list_local(self), self, fn {table_name, _}, acc ->
        complement_table(self, font_name, table_name)
      end)

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%Prefab{} = self, table_name),
    do:
      Enum.reduce(Prefab.get_font_list(self), self, fn {font_name, _}, acc ->
        complement_table(self, font_name, table_name)
      end)
end
