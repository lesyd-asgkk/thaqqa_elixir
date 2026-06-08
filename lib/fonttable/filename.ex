defmodule Thaqqa.Filename do
  # 本ファイルを変更することによってデータ保存・参照先を変えられる。

  def root_folder, do: System.get_env("ROOTFOLDER")

  def bundle_folder(uuid),
    do: System.get_env("BUNDLEFOLDER") |> String.replace("{}", to_string(uuid))

  def bundle_path(uuid),
    do: root_folder() <> bundle_folder(uuid) <> font_file()

  def font_path(uuid, foldername),
    do: root_folder() <> bundle_folder(uuid) <> foldername <> "/" <> font_file()

  def root_file, do: System.get_env("ROOTFILE")
  def bundle_file, do: System.get_env("BUNDLEFILE")
  def font_file, do: System.get_env("FONTFILE")
end
