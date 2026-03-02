# Regex_khhylに依存した固定regex文の機能を補佐するために作成。
# 具体的には、regex文の翻訳データの作成による可読性担保と時間短縮
# add,delete等の機能の拡張は必要に応じて行う(内部でしか使用せず、rootファイルを直接編集で事足りるため必要に乏しい)

defmodule Thaqqa.ConstRegexManager do
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const
  #
  @regex_const "REGEX_CONST"
  def get_const_table!(%Prefab{} = prefab),
    do: Prefab.get_static_table(prefab, @regex_const)

  def get_static_table(%Prefab{} = prefab) do
    case Prefab.get_static_table(prefab, @regex_const) do
      nil -> Error.table_not_found(@regex_const)
      table -> {:ok, table}
    end
  end

  def get_const(%Prefab{} = prefab, name) do
    [value] =
      Prefab.get_static_table(prefab, @regex_const)
      |> Thaqqa.DataTable.get_data(fn data ->
        Thaqqa.Data.get_val(data, @name) == name
      end)

    value
  end

  def match?(%Prefab{} = prefab, name, string) do
    case get_const(prefab, name) do
      nil ->
        {:error, "(仮) data_not_found"}

      otherwise ->
        otherwise
        |> Thaqqa.Data.get_val(@precompile)
        |> Regex.match?(string)
    end
  end

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @regex_const)
  def sort_gsub(%Prefab{} = prefab), do: Prefab.sort_as_static(prefab, @regex_const)
end
