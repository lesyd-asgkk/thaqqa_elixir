defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable

  @root_file "data/root.json"
  @font_folder "data/font/"

  def import() do
    # json → structs
    {:ok, json} = File.read(@root_file)
    {:ok, data} = Jason.decode(json)

    Enum.map(data, fn {k, v} ->
      FontRegistry.add_static_table(import_table(k, v))
    end)

    # FontRegistry.add_static_table (%Thaqqa.DataTable{name: "TestFont", table_list: []})
  end

  def import(filename) do
    {:ok, json} = File.read(@font_folder <> filename <> ".json")
    {:ok, data} = Jason.decode(json)

    table =
      Enum.map(data, fn {k, v} ->
        import_table(k, v)
      end)

    name = Map.get(data, "FONTDATA") |> Map.get("data") |> Map.get("0") |> Map.get("Fontname")

    if name == nil,
      do: {:error, "Cannot load font: Fontname is not found"},
      else: FontRegistry.add_font(Font.new(filename, name, table))
  end

  defp import_table(name, struct) do
    table = DataTable.new(name, nil)

    table_ =
      Enum.reduce(struct, table, fn {k, v}, ans ->
        if k == "columnList" do
          Enum.reduce(v, ans, fn {_, v_}, ans_ ->
            # todo:name,typeに不備がある場合は即エラー処理にする
            DataTable.add_column!(
              ans_,
              Map.get(v_, "name"),
              Map.get(v_, "type") |> String.to_atom(),
              Map.get(v_, "desc", ""),
              Map.get(v_, "order", 0),
              Map.get(v_, "subtype", "none") |> String.to_atom(),
              Map.get(v_, "dev", false)
            )
          end)
        else
          if is_map(v) do
            Enum.reduce(v, ans, fn {_, v_}, ans_ ->
              DataTable.add_data(ans_, v_)
            end)
          else
            ans
          end
        end
      end)
  end

  def export(fonts) do
    # structs → json
  end
end
