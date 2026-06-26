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
  alias Thaqqa.FontRegistry.Error, as: Error

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
         {:ok, uuid} <- validation_check_for_bundle(rootdata, uuid),
         {:ok, consttable} <- FontRegistry.create_const_table(),
         bundle <- ConstTable.complement_bundle(consttable, bundle),
         {:ok, bundle} <- Bundle.set_precompile_all(bundle),
         {:ok, bundle} <- Bundle.init_const_table(bundle),
         :ok <- FontRegistry.apply_bundle(bundle, uuid) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  defp validation_check_for_bundle(data, uuid),
    do:
      if(uuid == get_in(data, ["BUNDLESYSDATA", "dataList", "0", "UUID"]),
        do: {:ok, uuid},
        else:
          Error.invalid_uuid(
            "BundleFile",
            get_in(data, ["BUNDLESYSDATA", "dataList", "0", "UUID"]),
            uuid
          )
      )

  defp validation_check_for_font(data, uuid),
    do:
      if(uuid == get_in(data, ["FONTSYSDATA", "dataList", "0", "UUID"]),
        do: {:ok, uuid},
        else:
          Error.invalid_uuid(
            "FontFile",
            get_in(data, ["FONTSYSDATA", "dataList", "0", "UUID"]),
            uuid
          )
      )

  defp import_as_font(uuid, folder_path) do
    file_path = Filename.font_path(uuid, folder_path)

    {uuid_for_font, _} = String.split(folder_path, "-") |> Enum.at(1) |> Integer.parse()

    with {:ok, prefab} <- FontRegistry.create_prefab(uuid),
         {:ok, fontdata} <- read_and_decode_json(file_path),
         {:ok, prefab} <- Bundle.import_as_font(prefab, fontdata),
         {:ok, _} <- validation_check_for_font(fontdata, uuid_for_font) do
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
