defmodule Thaqqa.FontRegistry.IO do
  # jsonはファイルへのpath
  # ファイルについては↓を変更すること

  # import系統:jsonファイルを読み込み、FontやDataTableのMap構造体に変換したうえでFontRegistryに登録する。
  # export系統:FontRegitryのMap構造体をjson形式に変換した上で保存する。
  # jsonデータ ⇔ Map構造への変換は Bundle.IO内にて行われる。
  #

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.ConstTable, as: ConstTable
  alias Thaqqa.Filename, as: Filename

  defp read_and_decode_json(file_path) do
    case File.read(file_path) do
      {:error, reason} -> {:error, reason}
      {:ok, json} -> Jason.decode(json)
    end
  end

  def import_bundle(uuid) do
    dir_name =
      Path.wildcard(Filename.root_folder() <> Filename.bundle_folder(uuid) <> "*")
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.basename/1)

    with :ok <- import_as_root(uuid),
         :ok <-
           Enum.reduce_while(dir_name, :ok, fn filename, :ok ->
             case import_as_font(uuid, filename) do
               {:error, _} = err -> {:halt, err}
               :ok -> {:cont, :ok}
             end
           end) do
      FontRegistry.commit_bundle(uuid)
      :ok
    else
      {:error, _} = err ->
        FontRegistry.rollback_bundle(uuid)
        err
    end
  end

  defp import_as_root(uuid) do
    file_path = Filename.bundle_path(uuid)

    with {:ok, bundle} <- FontRegistry.create_prefab(uuid),
         {:ok, rootdata} <- read_and_decode_json(file_path),
         {:ok, bundle} <- Bundle.import_as_root(bundle, rootdata),
         {:ok, consttable} <- FontRegistry.create_const_table(),
         bundle <- ConstTable.complement_bundle(consttable, bundle),
         :ok <-
           FontRegistry.apply_bundle(bundle, bundle.uuid) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  defp import_as_font(uuid, foldername) do
    file_path = Filename.font_path(uuid, foldername)

    with {:ok, prefab} <- FontRegistry.create_prefab(uuid),
         {:ok, fontdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Bundle.import_as_font(prefab, fontdata, foldername) do
      uuid = prefab.uuid

      with :ok <- FontRegistry.apply_bundle(prefab, uuid),
           :ok <- FontRegistry.commit_bundle(uuid) do
        :ok
      else
        {:error, _} = err -> err
      end
    else
      {:error, _} = err -> err
    end
  end

  # json→mapに変換する処理。
  defp read_and_decode_json(file_path) do
    case File.read(file_path) do
      {:error, reason} -> {:error, reason}
      {:ok, json} -> Jason.decode(json)
    end
  end

  def import_const() do
    file_path = Filename.root_folder() <> "/" <> Filename.root_file()

    with {:ok, consttable} <- FontRegistry.create_const_table(),
         {:ok, constdata} <- read_and_decode_json(file_path),
         {:ok, consttable} <- ConstTable.import_as_const(consttable, constdata),
         :ok <- FontRegistry.apply_const(consttable),
         :ok <- FontRegistry.commit_const() do
      :ok
    else
      {:error, _} = err ->
        FontRegistry.rollback_const()
        err
    end
  end

  def export_as_root(opts), do: FontRegistry.export_as_root(opts)

  def export_as_font(fontname, opts), do: FontRegistry.export_as_font(fontname, opts)
end
