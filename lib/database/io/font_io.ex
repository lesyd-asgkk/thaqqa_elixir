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

  def import_as_root() do
    file_path = @root_file

    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, rootdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Prefab.import_as_root(prefab, rootdata),
         {:ok, _} <- FontRegistry.apply_prefab(prefab),
         {:ok, val} <- FontRegistry.commit() do
      {:ok, val}
    else
      {:error, _} = err ->
        FontRegistry.rollback()
        err
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
      {:error, _} = err ->
        FontRegistry.rollback()
        err
    end
  end

  def export_as_root(opts), do: FontRegistry.export_as_root(opts)

  def export_as_font(fontname, opts), do: FontRegistry.export_as_font(fontname, opts)
end
