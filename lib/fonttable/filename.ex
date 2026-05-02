defmodule Thaqqa.Filename do
  # 具体的参照先はenvファイル側で指定する仕様としている。

  def root_file, do: System.get_env("ROOTFILE")
  def font_folder, do: System.get_env("FONTFOLDER")
  def font_file, do: System.get_env("FONTFILE")
end
