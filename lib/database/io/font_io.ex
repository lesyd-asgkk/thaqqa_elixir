defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  # ※import系統がバグりうる（中途半端な状態で保存されかねない）ので原子化を行う

  @root_file "data/root.json"
  @font_folder "data/"
  @font_file "/main.json"

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.ParserRegister, as: ParserRegister
  alias Thaqqa.GsubRegister, as: GsubRegister
  alias Thaqqa.UniqueGsubRegister, as: UniqueGsubRegister
  alias Thaqqa.GlyphRegister, as: GlyphRegister
  alias Thaqqa.GposRegister, as: GposRegister

  def import() do
    # json → struct

    case import_json_data() do
      {:error, msg} -> {:error, msg}
      _ -> set_precompile()
    end
  end

  defp set_precompile() do
    precompiled_tables = [
      ParserRegister.precompile_parser_all(),
      GsubRegister.precompile_gsub_all()
    ]

    Enum.reduce_while(precompiled_tables, nil, fn table, acc ->
      case table do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, data} -> {:cont, data |> DataTable.update_fontregistry()}
      end
    end)
    |> case do
      {:error, msg} ->
        FontRegistry.rollback()
        {:error, msg}

      _ ->
        {:ok, FontRegistry.commit()}
    end
  end

  defp import_json_data() do
    {:ok, json} = File.read(@root_file)
    {:ok, data} = Jason.decode(json)

    # 逆にArchtype表に存在しないテーブルの補完機能も実装する。
    Enum.reduce_while(data, nil, fn {k, v}, _acc ->
      table_ = import_table(k, false, v)

      case table_ do
        {:error, _msg} ->
          {:halt, table_}

        {:ok, value} ->
          case FontRegistry.add_static_table(value) do
            {:ok, _} -> {:cont, nil}
            {:error, msg} -> {:halt, {:error, msg}}
          end
      end
    end)
  end

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "data", "0", "Fontname"])

  defp set_precompile(name) do
    precompiled_tables = [
      UniqueGsubRegister.precompile_unique_gsub_all(name),
      GlyphRegister.precompile_glyph_all(name),
      GposRegister.precompile_gpos_all(name)
    ]

    Enum.reduce_while(precompiled_tables, nil, fn table, acc ->
      case table do
        {:error, msg} -> {:halt, {:error, msg}}
        {:ok, data} -> {:cont, data |> DataTable.update_fontregistry()}
      end
    end)
    |> case do
      {:error, msg} ->
        FontRegistry.rollback()
        {:error, msg}

      _ ->
        {:ok, FontRegistry.commit()}
    end
  end

  defp import_json_data(filename) do
    {:ok, json} = File.read(@font_folder <> filename <> @font_file)
    {:ok, data} = Jason.decode(json)

    # 逆にroot上に存在しないテーブルの補完機能も実装する。
    Enum.reduce_while(data, [], fn {k, v}, acc ->
      table_ =
        case FontRegistry.get_static_table(k) do
          {:ok, nil} -> {:enforced_continue, nil}
          {:error, msg} -> {:error, msg}
          _ -> import_table(k, false, v)
        end

      case table_ do
        {:error, msg} -> {:halt, {:error, msg}}
        {:enforced_continue, nil} -> {:cont, acc}
        {:ok, value} -> {:cont, [value | acc]}
      end
    end)
    |> case do
      {:error, msg} ->
        {:error, msg}

      table ->
        name = extract_datatable_name(data)

        if name == nil do
          {:error, "Cannot load font: Fontname is not found"}
        else
          {:ok,
           Enum.reduce(table, Font.new(filename, name, []), fn k, acc ->
             acc |> Font.add_table!(k)
           end), name}
        end
    end
  end

  # root上に存在しないテーブルは削除処理。
  # root上に存在するがファイル上に存在しないテーブルはroot上から補完する

  def import(filename) do
    case import_json_data(filename) do
      {:error, msg} ->
        {:error, msg}

      {:ok, font, name} ->
        FontRegistry.init_font(font)

        set_precompile(name)
    end
  end

  defp import_table(name, global, struct) do
    table = DataTable.new(name, Map.get(struct, "global"), nil)

    table_altered =
      Enum.reduce_while(struct, table, fn {k, v}, ans ->
        if k == "columnList" do
          column =
            Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
              if Map.get(v_, "name") == nil or Map.get(v_, "type") == nil,
                do: {:halt, {:error, "name or type is undefined"}},
                else:
                  {:cont,
                   DataTable.add_column!(
                     ans_,
                     Map.get(v_, "name"),
                     Map.get(v_, "type") |> String.to_atom(),
                     Map.get(v_, "desc", ""),
                     Map.get(v_, "order", 0),
                     Map.get(v_, "subtype", "none") |> String.to_atom(),
                     Map.get(v_, "dev", false)
                   )}
            end)

          case column do
            {:error, _msg} -> {:halt, column}
            _ -> {:cont, column}
          end
        else
          if is_map(v) do
            # volatilityとなっている値は追加しません　→ subtypeから考えます
            column_volatility =
              DataTable.get_column(ans, fn %Column{type: type} -> type == :volatility end)
              |> Enum.map(fn %Column{name: name} -> name end)

            data =
              Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
                v_ =
                  Enum.reduce(column_volatility, v_, fn k, ans__ ->
                    ans__ |> Map.put(k, nil)
                  end)

                data_ = ans_ |> DataTable.add_data(v_, true)

                case data_ do
                  {:error, _msg} -> {:halt, data_}
                  {:ok, value} -> {:cont, value}
                  _ -> {:cont, data_}
                end
              end)

            case data do
              {:error, _msg} -> {:halt, data}
              _ -> {:cont, data}
            end
          else
            {:cont, ans}
          end
        end
      end)

    # |> DataTable.sort()

    case table_altered do
      {:error, _msg} -> table_altered
      _ -> {:ok, table_altered}
    end
  end

  def export(fonts) do
    # structs → json
    # デッドロックがどうとか馬鹿馬鹿しい！　いっそ分裂可能にして保存してしまう？
    # （編集終了までのアクセスが1つまでしかない場合は普通に上書きする）
    # （編集物が二つ以上現れた場合は分岐させて、権限持ちが統合or選択できるようにする）
    #
  end
end
