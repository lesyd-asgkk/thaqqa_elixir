defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  @root_file "data/root.json"
  @font_folder "data/font/"

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Column, as: Column
  alias Thaqqa.DataTable, as: DataTable

  def import() do
    # json → structs
    {:ok, json} = File.read(@root_file)
    {:ok, data} = Jason.decode(json)

    checker =
      Enum.reduce_while(data, nil, fn {k, v}, _acc ->
        table_ = import_table(k, v)

        case table_ do
          {:error, _msg} ->
            {:halt, table_}

          {:ok, value} ->
            case FontRegistry.add_static_table(value) do
              :ok -> {:cont, nil}
              {:error, msg} -> {:halt, {:error, msg}}
            end
        end
      end)

    case checker do
      {:error, _msg} -> checker
      _ -> {:ok, nil}
    end
  end

  def import(filename) do
    {:ok, json} = File.read(@font_folder <> filename <> ".json")
    {:ok, data} = Jason.decode(json)

    # reduce_whileに書き換える
    table =
      Enum.reduce_while(data, [], fn {k, v}, acc ->
        table_ = import_table(k, v)

        case table_ do
          {:error, _msg} -> {:halt, table_}
          {:ok, value} -> {:cont, acc = [value | acc]}
        end
      end)

    case table do
      {:error, _msg} ->
        table

      _ ->
        name = Map.get(data, "FONTDATA") |> Map.get("data") |> Map.get("0") |> Map.get("Fontname")

        if name == nil,
          do: {:error, "Cannot load font: Fontname is not found"},
          else: FontRegistry.add_font(Font.new(filename, name, table))
    end
  end

  defp import_table(name, struct) do
    table = DataTable.new(name, nil)

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
            # volatilityとなっている値は追加しません
            column_volatility =
              DataTable.get_column(table, fn %Column{type: st} -> st == :volatility end)
              |> Enum.map(fn %Column{name: name} -> name end)

            data =
              Enum.reduce_while(v, ans, fn {_, v_}, ans_ ->
                data_ = ans_ |> Map.drop(column_volatility) |> DataTable.add_data(v_, true)

                case data_ do
                  {:error, _msg} -> {:halt, data_}
                  {:ok, value} -> {:cont, value}
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

    case table_altered do
      {:error, _msg} -> table_altered
      _ -> {:ok, table_altered}
    end
  end

  def export(fonts) do
    # structs → json
  end
end
