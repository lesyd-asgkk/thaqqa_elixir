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

  '''
    def import(filename, false) do
      {:ok, json} = File.read(@root_file <> filename)
      {:ok, data} = Jason.decode(json)

      Enum.map(data, fn {k, v} ->
        FontManager.add_font(import_table(k, v))
      end)
    end
  '''

  defp import_table(name, struct) do
    table = DataTable.new(name, nil)

    table_ =
      Enum.reduce(struct, table, fn {k, v}, ans ->
        if k == "columnList" do
          Enum.reduce(v, ans, fn {_, v_}, ans_ ->
            DataTable.add_column!(
              ans_,
              Map.get(v_, "name"),
              Map.get(v_, "type"),
              Map.get(v_, "desc", ""),
              Map.get(v_, "order"),
              Map.get(v_, "subtype"),
              Map.get(v_, "dev")
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
