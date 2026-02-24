defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  # import系統:jsonファイルを読み込み、FontやDataTableのMap構造体に変換したうえでFontRegistryに登録する。
  # export系統:FontRegitryのMap構造体をjson形式に変換した上で保存する。
  # jsonデータ⇔Map構造への変換はPrefabIO内にて行われる。
  #

  @root_file "data/main.json"
  @font_folder "data/"
  @font_file "/main.json"

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable

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
      {:error, msg} ->
        {:error, msg}

      {:ok, rootdata} ->
        case Prefab.import_as_root(prefab, rootdata) do
          {:error, msg} -> {:error, msg}
          {:ok, prefab} -> FontRegistry.apply_prefab(prefab)
        end
    end
  end

  def import_as_font(filename) do
    {:ok, prefab} = FontRegistry.create_prefab()

    file_path = @font_folder <> filename <> @font_file

    case read_and_decode_json(file_path) do
      {:error, msg} ->
        {:error, msg}

      {:ok, rootdata} ->
        case Prefab.import_as_font(prefab, rootdata, filename) do
          {:error, msg} -> {:error, msg}
          {:ok, prefab} -> FontRegistry.apply_prefab(prefab)
        end
    end
  end

  def export_as_root() do
  end

  def export_as_font(fontname) do
  end
end
