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

  def build_path_data(%Prefab{} = prefab, syllable_list, font, writing_direction)
      when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, {:ok, []}, fn syl, {:ok, acc} ->
      with {:ok, glyph} <- Glyph.new(prefab, font, syl, writing_direction) do
        # 現状set_pathにエラーを吐く要因はないが
        # 今後エラー処理が必要になった場合を鑑みてwith文とする
        {:cont, {:ok, [Glyph.set_path(glyph) | acc]}}
      else
        {:error, msg} -> {:halt, {:error, msg}}
      end
    end)
  end

  def verficate_syllable(%Prefab{} = prefab, syllable_list) when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, nil, fn syl, acc ->
      case ConstRegexManager.whole_of_string_match_at_once?(prefab, "L()", syl) do
        {:error, msg} ->
          {:halt, {:error, msg}}

        {:ok, true} ->
          {:cont, nil}

        {:ok, otherwise} ->
          case ConstRegexManager.whole_of_string_match?(prefab, "L()", syl) do
            {:error, msg} ->
              {:halt, {:error, msg}}

            {:ok, true} ->
              {:halt,
               {:error, "unparsed pattern found (it might be internal error occured): #{syl}"}}

            {:ok, otherwise} ->
              {:halt, {:error, "invalid pattern found: #{otherwise}"}}
          end
      end
    end)
    |> case do
      {:error, msg} -> {:error, msg}
      _ -> {:ok, syllable_list}
    end
  end

  def split_by_syllable(%Prefab{} = prefab, string) do
    case ConstRegexManager.get_const(prefab, "(L())(L())") do
      {:error, msg} ->
        {:error, msg}

      {:ok, const} ->
        regex = const |> Thaqqa.Data.get_val(@precompile)
        # Sep()を付け加える
        string = Regex.replace(regex, string, "\\g{1}Sep()\\g{2}")
        string = Regex.replace(regex, string, "\\g{1}Sep()\\g{2}")
        # Sep()を音節間に付け足してSep()を基準に分けているだけなので
        # ここでエラーが起きる＝fatalと判断（即終了）
        {:ok, String.split(string, "Sep()")}
    end
  end

  def convert_into_khhyl_letter(%Prefab{} = prefab, string, font, language, writing_direction)
      when language in [@khehyelu, @samlhta] and writing_direction in [@vertical, @horizontal] do
    IO.inspect(Thaqqa.ParserManager.parse(prefab, string, language))

    with {:ok, parsed_string} <- Thaqqa.ParserManager.parse(prefab, string, language),
         {:ok, gsub_string} <- Thaqqa.GsubManager.gsub(prefab, parsed_string, writing_direction),
         {:ok, unique_gsub_string} <-
           Thaqqa.UniqueGsubManager.unique_gsub(prefab, gsub_string, font, writing_direction) do
      {:ok, unique_gsub_string}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  # prefabを持たない場合、FontRegistryから直接読み込む。
  def convert_into_khhyl_letter!(string, font, language, writing_direction) do
    case Thaqqa.FontRegistry.create_prefab() do
      {:ok, prefab} ->
        convert_into_khhyl_letter(prefab, string, font, language, writing_direction)

      {:error, msg} ->
        {:error, msg}
    end

    # prefab
    # |> Thaqqa.UniqueGposManager.gpos("Default", "S(mid,t0,e0,t0)", "vertical", "internal")
    # |> IO.inspect()
  end
end
