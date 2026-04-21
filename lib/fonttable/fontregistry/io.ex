defmodule Thaqqa.FontRegistry.IO do
  # jsonはファイルへのpath
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

  def import_all() do
    dir_name =
      Path.wildcard(@font_folder <> "*")
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.basename/1)

    case import_as_root() do
      {:error, _} = err ->
        err

      {:ok, _} ->
        Enum.reduce_while(dir_name, {:ok, nil}, fn filename, {:ok, _} ->
          case import_as_font(filename) do
            {:error, _} = err -> {:halt, err}
            {:ok, _} -> {:cont, {:ok, nil}}
          end
        end)
    end
  end

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
