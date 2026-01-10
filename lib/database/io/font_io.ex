defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  @root_file "data/root.json"
  @font_folder "data/font/"

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
    # json → structs
    result_parsing_data = import_json_data()

    case result_parsing_data do
      {:error, _msg} ->
        result_parsing_data

      _ ->
        checker_ = ParserRegister.precompile_parser_all()

        case checker_ do
          # 削除or差し戻し処理をここに追加予定。
          {:error, _msg} ->
            checker_

          {:ok, data} ->
            data |> DataTable.update_fontregistry()
        end

        checker_ = GsubRegister.precompile_gsub_all()

        case checker_ do
          # 削除or差し戻し処理をここに追加予定。
          {:error, _msg} -> checker_
          {:ok, data} -> data |> DataTable.update_fontregistry()
        end
    end
  end

  defp import_json_data() do
    {:ok, json} = File.read(@root_file)
    {:ok, data} = Jason.decode(json)

    # 逆にArchtype表に存在しないテーブルの補完機能も実装する。
    Enum.reduce_while(data, nil, fn {k, v}, _acc ->
      table_ =
        if FontRegistry.get_static_table(k),
          do: import_table(k, false, v),
          else: {:error, "Archtype was not found"}

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

  def import(filename) do
    {:ok, json} = File.read(@font_folder <> filename <> ".json")
    {:ok, data} = Jason.decode(json)

    # reduce_whileに書き換える
    table =
      Enum.reduce_while(data, [], fn {k, v}, acc ->
        case import_table(k, false, v) do
          {:error, msg} -> {:halt, {:error, msg}}
          {:ok, value} -> {:cont, [value | acc]}
        end
      end)

    case table do
      {:error, _msg} ->
        table

      _ ->
        name = Map.get(data, "FONTDATA") |> Map.get("data") |> Map.get("0") |> Map.get("Fontname")

        if name == nil do
          {:error, "Cannot load font: Fontname is not found"}
        else
          font =
            table
            |> Enum.reduce(Font.new(filename, name, []), fn k, acc ->
              acc |> Font.add_table!(k)
            end)

          FontRegistry.init_font(font)

          checker_ = UniqueGsubRegister.precompile_unique_gsub_all(name)

          case checker_ do
            {:error, _msg} -> checker_
            {:ok, data} -> data |> DataTable.update_fontregistry()
          end

          checker_ = GlyphRegister.precompile_glyph_all(name)

          case checker_ do
            {:error, _msg} -> checker_
            {:ok, data} -> data |> DataTable.update_fontregistry()
          end

          checker_ = GposRegister.precompile_gpos_all(name)

          case checker_ do
            {:error, _msg} -> checker_
            {:ok, data} -> data |> DataTable.update_fontregistry()
          end
        end
    end
  end

  defp import_table(name, global, struct) do
    table = DataTable.new(name, Map.get(struct, "global"), nil)

    table_altered =
      Enum.reduce_while(struct, table, fn {k, v}, ans ->
        if k == "columnList" do
          column =
            Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
              # todo:name,typeに不備がある場合は即エラー処理にする
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
