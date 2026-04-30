defmodule Thaqqa.FontRegistry.IO do
  # jsonはファイルへのpath
  # ファイルについては↓を変更すること

  # import系統:jsonファイルを読み込み、FontやDataTableのMap構造体に変換したうえでFontRegistryに登録する。
  # export系統:FontRegitryのMap構造体をjson形式に変換した上で保存する。
  # jsonデータ⇔Map構造への変換はPrefabIO内にて行われる。
  #

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Filename, as: Filename

  def import_all() do
    dir_name =
      Path.wildcard(Filename.font_folder() <> "*")
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
    file_path = Filename.root_file()

    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, rootdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Prefab.import_as_root(prefab, rootdata),
         :ok <- FontRegistry.apply_prefab(prefab),
         :ok <- FontRegistry.commit() do
      :ok
    else
      {:error, _} = err ->
        FontRegistry.rollback()
        err
    end
  end

  def import_as_font(filename) do
    file_path = Filename.font_folder() <> filename <> Filename.font_file()

    with {:ok, prefab} <- FontRegistry.create_prefab(),
         {:ok, fontdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Prefab.import_as_font(prefab, fontdata, filename),
         :ok <- FontRegistry.apply_prefab(prefab),
         :ok <- FontRegistry.commit() do
      :ok
    else
      {:error, _} = err ->
        FontRegistry.rollback()
        err
    end
  end

  def export_as_root(opts), do: FontRegistry.export_as_root(opts)

  def export_as_font(fontname, opts), do: FontRegistry.export_as_font(fontname, opts)
end
