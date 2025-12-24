defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath

  alias Thaqqa.FontManager, as: FontManager
  alias Thaqqa.Font, as: Font
  alias Thaqqa.DataTable, as: DataTable

  @root_file "data/root.json"
  @font_folder "data/font/"

  def import(true) do
    # json → structs
    {:ok, json} = File.read(@root_file)
    {:ok, data} = Jason.decode(json)

    Enum.map(data, fn {k, v} ->
      FontManager.add_static_table(import_table(k, v))
    end)

    # FontManager.add_static_table (%Thaqqa.DataTable{name: "TestFont", table_list: []})
  end

  defp import_table(name, struct) do
    table = DataTable.new(name, nil)

    Enum.map(struct, fn {k, v} ->
      if k == "columnList" do
        DataTable.add_column(
          table,
          Map.get(v, "name"),
          Map.get(v, "type"),
          Map.get(v, "desc", ""),
          Map.get(v, "order"),
          Map.get(v, "subtype"),
          Map.get(v, "dev")
        )
      else
        Enum.map(v, fn {_, v_} -> DataTable.add_data(table, v_) end)
      end
    end)
  end

  def import(json, false) do
  end

  def export(fonts) do
    # structs → json
  end
end
