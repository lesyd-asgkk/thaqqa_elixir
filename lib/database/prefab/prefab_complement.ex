defmodule Thaqqa.PrefabComplement do
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
    cond do
      # ここもcolumn_exist?に変更したうえでwithにする
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
    with %Font{} = font <- Prefab.get_font(self, font_name),
         true <- Prefab.static_table_exists?(self, table_name) do
      case Prefab.local_static_table_exists?(self, table_name) do
        false -> overwrite_font(self, font_name, Font.delete_table(font, table_name))
        true -> complement_local_table(self, font, font_name, table_name)
      end
    else
      _ -> self
    end
  end

  defp complement_local_table(self, font, font_name, table_name) do
    case Prefab.get_table(self, font_name, table_name) do
      nil ->
        altered_font =
          Font.add_table(font, Prefab.get_static_table(self, table_name))

        overwrite_font(self, font_name, altered_font)

      table ->
        altered_font =
          Enum.reduce(
            Prefab.get_column_list(self, table_name),
            font,
            fn column, font_acc ->
              altered_table =
                complement_table_by_column(self, table, column.name)

              Font.edit_table(font_acc, table_name, altered_table)
            end
          )

        overwrite_font(self, font_name, altered_font)
    end
  end

  ## 追加された(される)fontをstatic_tableの設定に合わせる
  def complement_font(%Prefab{} = self, font_name),
    do:
      Enum.reduce(Prefab.get_local_static_table_list(self), self, fn {table_name, _}, acc ->
        complement_table(self, font_name, table_name)
      end)

  # static_tableの変更に伴ってfontテーブル側を変更する
  def complement_by_static_table(%Prefab{} = self, table_name),
    do:
      Enum.reduce(Prefab.get_font_list(self), self, fn {font_name, _}, acc ->
        complement_table(self, font_name, table_name)
      end)
end
