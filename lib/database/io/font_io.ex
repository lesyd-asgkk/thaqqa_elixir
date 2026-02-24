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

  defp extract_datatable_name(data) do
    with data_0_list when is_list(data_0_list) <- get_in(data, ["FONTDATA", "data"]),
         data_0 when is_binary(data_0) <- Enum.at(data_0_list, 0) do
      Map.get(data_0, "Fontname")
    else
      value -> value
    end
  end

  def import_as_root() do
    file_path = @root_file

    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, rootdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Prefab.import_as_root(prefab, rootdata),
         {:ok, _} <- FontRegistry.apply_prefab(prefab),
         {:ok, val} <- FontRegistry.commit() do
      {:ok, val}
    else
      {:error, msg} ->
        FontRegistry.rollback()
        {:error, msg}
    end
  end

  def import_as_font(filename) do
    file_path = @font_folder <> filename <> @font_file

    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, fontdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Prefab.import_as_font(prefab, fontdata, filename),
         {:ok, _} <- FontRegistry.apply_prefab(prefab),
         {:ok, val} <- FontRegistry.commit() do
      {:ok, val}
    else
      {:error, msg} ->
        FontRegistry.rollback()
        {:error, msg}
    end
  end

  def export_as_root() do
  end

  def export_as_font(fontname) do
  end
end
