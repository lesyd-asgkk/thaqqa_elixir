# Regex_khhylに依存した固定regex文の機能を補佐するために作成。
# 具体的には、regex文の翻訳データの作成による可読性担保と時間短縮
# add,delete等の機能の拡張は必要に応じて行う(内部でしか使用せず、rootファイルを直接編集で事足りるため必要に乏しい)

defmodule Thaqqa.ConstRegexManager do
  alias Thaqqa.Data, as: Data
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.Font, as: Font
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  use Thaqqa.DataTable.Const
  #

  @regex_const "REGEX_CONST"
  def set_datalist_hash(%Prefab{} = prefab) do
    case get_static_table(prefab) do
      {:error, reason} ->
        {:error, reason}

      {:ok, table} ->
        dh =
          table.data_list
          |> Map.new(fn %Thaqqa.Data{value_list: vl} = table -> {Map.get(vl, @name), table} end)

        Prefab.edit_static_table(prefab, @regex_const, %DataTable{table | data_hash: dh})
    end
  end

  def get_const_table!(%Prefab{} = prefab),
    do: Prefab.get_static_table(prefab, @regex_const)

  def get_static_table(%Prefab{} = prefab) do
    case Prefab.get_static_table(prefab, @regex_const) do
      nil -> Error.table_not_found(@regex_const)
      table -> {:ok, table}
    end
  end

  def get_const(%Prefab{} = prefab, name) do
    case get_static_table(prefab) do
      {:error, reason} ->
        {:error, reason}

      {:ok, table} ->
        case table.data_hash do
          #   %{} ->
          #     case set_datalist_hash(prefab) do
          #       {:error, reason} -> {:error, reason}
          #       {:ok, prefab} -> get_const(prefab, name)
          #     end

          hash ->
            {:ok, Map.get(hash, name)}
        end
    end
  end

  def whole_of_string_match_at_once?(%Prefab{} = prefab, name, string) do
    case get_const(prefab, name) do
      {:error, reason} ->
        {:error, reason}

      {:ok, nil} ->
        {:error, "(仮) data_not_found"}

      {:ok, data} ->
        case Thaqqa.Data.get_val(data, @precompile) |> Regex.replace(string, "", global: false) do
          "" -> {:ok, true}
          otherwise -> {:ok, otherwise}
        end
    end
  end

  def whole_of_string_match?(%Prefab{} = prefab, name, string) do
    case get_const(prefab, name) do
      {:error, reason} ->
        {:error, reason}

      {:ok, nil} ->
        {:error, "(仮) data_not_found"}

      {:ok, data} ->
        case Thaqqa.Data.get_val(data, @precompile) |> Regex.replace(string, "") do
          "" -> {:ok, true}
          otherwise -> {:ok, otherwise}
        end
    end
  end

  def match?(%Prefab{} = prefab, name, string) do
    case get_const(prefab, name) do
      {:error, reason} -> {:error, reason}
      {:ok, nil} -> {:error, "(仮) data_not_found"}
      {:ok, data} -> {:ok, Thaqqa.Data.get_val(data, @precompile) |> Regex.match?(string)}
    end
  end

  def complement(%Prefab{} = prefab), do: Prefab.complement_by_static_table(prefab, @regex_const)
  def sort_gsub(%Prefab{} = prefab), do: Prefab.sort_as_static(prefab, @regex_const)
end
