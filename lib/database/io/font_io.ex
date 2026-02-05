defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  # ※import系統がバグりうる（中途半端な状態で保存されかねない）ので原子化を行う
  # ※shadow_tableを更にshadowしたtable……のような構造体を作る
  # %import_plan{ fonts: :fonts_shadow_に対応する部分 ,tables: :static_tables_shadowに対応する部分}

  @root_file "data/main.json"
  @font_folder "data/"
  @font_file "/main.json"

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegisteryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.ParserRegister, as: ParserRegister
  alias Thaqqa.GsubRegister, as: GsubRegister
  alias Thaqqa.UniqueGsubRegister, as: UniqueGsubRegister
  alias Thaqqa.GlyphRegister, as: GlyphRegister
  alias Thaqqa.GposRegister, as: GposRegister

  # read_and_decode_jsonはfont_prefabの方にそっくり同じ関数を作る
  # set_precompileも同様

  # json→mapの部分。
  # ここはIOで処理。
  defp read_and_decode_json(file_path) do
    case File.read(file_path) do
      {:error, reason} -> {:error, reason}
      {:ok, json} -> Jason.decode(json)
    end
  end

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "data", "0", "Fontname"])

  def import_as_root() do
    {:ok, prefab} = FontRegistry.create_prefab()
    file_path = @root_file

    case read_and_decode_json(file_path) do
      {:error, msg} -> {:error, msg}
      {:ok, rootdata} -> Prefab.import_as_root(prefab, rootdata)
    end
  end

  ########## ↓は修正前。
  # json → struct
  def import() do
    {:ok, prefab} = FontRegistry.create_prefab()

    case import_json_data() do
      {:error, msg} -> {:error, msg}
      _ -> set_precompile()
    end
  end

  def import(filename) do
    case import_json_data(filename) do
      {:error, msg} ->
        {:error, msg}

      {:ok, font, name} ->
        # Prefabの方でinit_fontを行うよう変更（予定）
        FontRegistry.init_font(font)
        set_precompile(name)
    end
  end

  defp import_json_data() do
    file_path = @root_file

    case read_and_decode_json(file_path) do
      {:error, reason} ->
        {:error, reason}

      {:ok, data} ->
        {:ok, prefab} = FontRegistry.create_prefab()
        {:ok, prefab} = Prefab.import_as_root(prefab, data)

        # local用のテーブルが増減した場合にfont側のテーブルも変更させる処理も後日付け足す。
        # (local用テーブルが消えた場合にfont側のその名前のテーブルも削除する機能や逆に補完する機能)
        Enum.reduce_while(data, nil, fn {k, v}, _acc ->
          table_ = import_table(k, false, v)

          case table_ do
            {:error, _msg} ->
              {:halt, table_}

            # ここらへんもPrefabの方でinit_fontを行うよう変更（予定）
            {:ok, value} ->
              case FontRegistry.add_static_table(value) do
                {:ok, _} -> {:cont, nil}
                {:error, msg} -> {:halt, {:error, msg}}
              end
          end
        end)
    end
    |> case do
      {:error, msg} -> {:error, msg}
      _ -> complement_local_table()
    end
  end

  defp import_json_data(filename) do
    filename_path = @font_folder <> filename <> @font_file

    case read_and_decode_json(filename_path) do
      {:error, reason} ->
        {:error, reason}

      {:ok, data} ->
        {:ok, roottable} = FontRegistry.get_static_table_local()
        # rootのlocal状態のテーブルを参照して
        # 存在しないテーブルはそもそも読み込まなかったり、存在すべきテーブルを補完したりする
        # （補完はlocalテーブルの情報をそのままコピペする）
        Enum.reduce_while(roottable, [], fn {k, v}, acc ->
          table_ =
            case Map.get(data, k) do
              nil -> {:ok, k}
              value -> import_table(k, false, value)
            end

          case table_ do
            {:error, msg} -> {:halt, {:error, msg}}
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
  end

  # tableの補完処理。
  defp complement_local_table() do
    # ここもPrefabの方で行うよう変更（予定）
    {:ok, local_table_list} = FontRegistry.get_static_table_local()
    {:ok, font_list} = FontRegistry.get_font_all()

    Enum.reduce(font_list, nil, fn {font_name, font}, _acc ->
      # font_listのtableがlocal_table_listに存在しなくなったら削除
      Enum.each(font |> Font.get_table_all(), fn table ->
        if Enum.find(local_table_list, fn {k, _v} -> k == table.name end) == nil do
          # ここも変更（予定）
          Font.delete_table!(font, table.name) |> Font.update_fontregistry()
        end
      end)

      # 逆に、local_table_listに存在するようになったtableがfont_listに存在しなかったら補完
      # こもPrefabの方で行うよう変更（予定）
      Enum.each(local_table_list, fn {table_name, table} ->
        if font |> Font.get_table(table_name) == nil do
          Font.add_table!(font, table) |> Font.update_fontregistry()
        end
      end)
    end)

    nil
  end

  defp set_precompile() do
    precompiled_tables = [
      ParserRegister.precompile_parser_all(),
      GsubRegister.precompile_gsub_all()
    ]

    Enum.reduce_while(precompiled_tables, nil, fn table, acc ->
      # ここらへんもPrefabの方でinit_fontを行うよう変更（予定）
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

  defp import_table(name, _global, struct) do
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
                     Column.new(
                       Map.get(v_, "name"),
                       Map.get(v_, "type") |> String.to_atom(),
                       Map.get(v_, "desc", ""),
                       Map.get(v_, "order", 0),
                       Map.get(v_, "subtype", "none") |> String.to_atom(),
                       Map.get(v_, "dev", false)
                     )
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

                data_ = ans_ |> DataTable.init_data(v_)

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
