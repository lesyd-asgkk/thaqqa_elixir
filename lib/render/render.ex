defmodule Thaqqa.Render do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.ParserManager, as: ParserManager
  alias Thaqqa.GsubManager, as: GsubManager
  alias Thaqqa.UniqueGsubManager, as: UniqueGsubManager
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  alias Thaqqa.Glyph, as: Glyph
  use Thaqqa.DataTable.Const

  # 合成方針（未実装部分）
  # horizontal、veritcal共に「3文字づつkerning用の値の処理」
  # ダミーデータとして「None()」に該当するGlyphを前後に挿入。
  # glyphs =[ None() |  glyphs ++ [None()]]
  # |> Stream.chunk_every(3, 1, :discard)
  # |> Stream.map(&calc_kerning/1)
  # のような形。ただし音節数が知れてる場合は素直にEnum.mapで処理。
  # %{glyph_height:float top_gap:float,bottom_gap: float,left_gap:float, bottom_gap:float ,
  # is_newline:false} 、のようなmapのlistを生成した上で、その情報を元にglyphのpath同士を合成。
  #
  def build_path_data(%Prefab{} = prefab, syllable_list, font, writing_direction)
      when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, {:ok, []}, fn syl, {:ok, acc} ->
      with {:ok, glyph} <- Glyph.new(prefab, font, syl, writing_direction) do
        # 現状set_pathにエラーを吐く要因はないが
        # 今後エラー処理が必要になった場合を鑑みてwith文とする
        {:cont, {:ok, [Glyph.set_path(glyph) | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      {:ok, glyph_list} -> Enum.reverse(glyph_list)
    end
  end

  def verficate_syllable(%Prefab{} = prefab, syllable_list) when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, nil, fn syl, _ ->
      case ConstRegexManager.whole_of_string_match_at_once?(prefab, "L()", syl) do
        {:error, reason} ->
          {:halt, {:error, reason}}

        {:ok, true} ->
          {:cont, nil}

        {:ok, _} ->
          case ConstRegexManager.whole_of_string_match?(prefab, "L()", syl) do
            {:error, reason} ->
              {:halt, {:error, reason}}

            {:ok, true} ->
              {:halt,
               {:error, "unparsed pattern found (it might be internal error occured): #{syl}"}}

            {:ok, otherwise} ->
              {:halt, {:error, "invalid pattern found: #{otherwise}"}}
          end
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, syllable_list}
    end
  end

  def split_by_syllable(%Prefab{} = prefab, string) do
    case ConstRegexManager.get_const(prefab, "(L())(L())") do
      {:error, reason} ->
        {:error, reason}

      {:ok, const} ->
        regex = const |> Thaqqa.Data.get_val(@precompile)
        {:ok, Regex.scan(regex, string) |> Enum.at(-1)}
    end
  end

  def convert_into_khhyl_letter(%Prefab{} = prefab, string, font, language, writing_direction)
      when language in [@khehyelu, @samlhta] and writing_direction in [@vertical, @horizontal] do
    with {:ok, parsed_string} <- ParserManager.parse(prefab, string, language),
         {:ok, gsub_string} <- GsubManager.gsub(prefab, parsed_string, writing_direction),
         {:ok, unique_gsub_string} <-
           UniqueGsubManager.unique_gsub(prefab, gsub_string, font, writing_direction) do
      {:ok, unique_gsub_string}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # prefabを持たない場合、FontRegistryから直接読み込む。
  def convert_into_khhyl_letter!(string, font, language, writing_direction) do
    case FontRegistry.create_prefab() do
      # {:error, reason} ->
      # {:error, reason}
      {:ok, prefab} ->
        convert_into_khhyl_letter(prefab, string, font, language, writing_direction)
    end
  end
end
