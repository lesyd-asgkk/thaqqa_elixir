defmodule Thaqqa.Filename do
  # 本ファイルを変更することによってデータ保存・参照先変えられる。
  # 将来的にはenvファイル側で指定する仕様とする。

  def root_file, do: System.get_env("ROOTFILE")
  def font_folder, do: System.get_env("FONTFOLDER")
  def font_file, do: System.get_env("FONTFILE")
end
