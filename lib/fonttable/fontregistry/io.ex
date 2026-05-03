defmodule Thaqqa.FontRegistry.IO do
  # jsonはファイルへのpath
  # ファイルについては↓を変更すること

  # import系統:jsonファイルを読み込み、FontやDataTableのMap構造体に変換したうえでFontRegistryに登録する。
  # export系統:FontRegitryのMap構造体をjson形式に変換した上で保存する。
  # jsonデータ⇔Map構造への変換はPrefabIO内にて行われる。
  #

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistryPrefab, as: Prefab

  # json→mapの部分。
  # ここはIOで処理。

  def import_from_internal_folder(uuid_list) when is_list(uuid_list) do
    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, prefab} <- Prefab.import_from_internal_folder(prefab, uuid_list),
         :ok <- FontRegistry.apply_prefab(prefab),
         :ok <- FontRegistry.commit() do
      :ok
    else
      {:error, _} = err ->
        FontRegistry.rollback()
        err
    end
  end

  def export_to_internal_folder(uuid_list, opts) when is_list(uuid_list) do
  end

  def export_as_root(opts), do: FontRegistry.export_as_root(opts)

  def export_as_font(fontname, opts), do: FontRegistry.export_as_font(fontname, opts)
end
