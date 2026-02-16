defmodule Thaqqa.FontIO do
  # jsonはファイルへのpath
  # ※impureな関数の塊
  # ファイルについては↓を変更すること

  # ※import系統がバグりうる（中途半端な状態で保存されかねない）ので原子化を行う
  # ※shadow_tableを更にshadowしたtable……のような構造体を作る
  # %import_plan{ fonts: :fonts_shadow_に対応する部分 ,tables: :static_tables_shadowに対応する部分}

  @root_file "data/main.json"
  @font_folder "data/"
  @font_file "/main.json"

  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.Font, as: Font
  alias Thaqqa.Column, as: Column
  alias Thaqqa.Regex_Khhyl, as: Regex_Khhyl
  alias Thaqqa.DataTable, as: DataTable
  alias Thaqqa.ParserRegister, as: ParserRegister
  alias Thaqqa.GsubRegister, as: GsubRegister
  alias Thaqqa.UniqueGsubRegister, as: UniqueGsubRegister
  alias Thaqqa.GlyphRegister, as: GlyphRegister
  alias Thaqqa.GposRegister, as: GposRegister

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

  defp extract_datatable_name(data), do: get_in(data, ["FONTDATA", "data", "0", "Fontname"])

  def import_as_root() do
    {:ok, prefab} = FontRegistry.create_prefab()
    file_path = @root_file

    case read_and_decode_json(file_path) do
      {:error, msg} ->
        {:error, msg}

      {:ok, rootdata} ->
        case Prefab.import_as_root(prefab, rootdata) do
          {:error, msg} -> {:error, msg}
          {:ok, prefab} -> FontRegistry.apply_prefab(prefab)
        end
    end
  end

  def import_as_font(filename) do
    {:ok, prefab} = FontRegistry.create_prefab()

    file_path = @font_folder <> filename <> @font_file

    case read_and_decode_json(file_path) do
      {:error, msg} ->
        {:error, msg}

      {:ok, rootdata} ->
        case Prefab.import_as_font(prefab, rootdata, filename) do
          {:error, msg} -> {:error, msg}
          {:ok, prefab} -> FontRegistry.apply_prefab(prefab)
        end
    end
  end
end
