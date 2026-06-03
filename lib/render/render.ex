defmodule Thaqqa.Render do
  alias Thaqqa.Bundle, as: Bundle
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.Bundle.ParserTable, as: ParserTable
  alias Thaqqa.Bundle.GsubTable, as: GsubTable
  alias Thaqqa.Bundle.UniqueGsubTable, as: UniqueGsubTable
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable

  alias Thaqqa.Render.Error, as: Error
  alias Thaqqa.Glyph, as: Glyph
  use Thaqqa.DataTable.Const

  defstruct boundry: %{width: 0, height: 0},
            line_break: :normal,
            line_height: 0,
            text_align: :left,
            text_align_last: :left,
            word_spacing: 0,
            letter_spacing: 0

  # 合成方針
  # horizontal、veritcal共に「3文字づつkerning用の値の処理」
  # ダミーデータとして「None()」に該当するGlyphを前後に挿入。
  # glyphs = glyphs ++ [None()]
  # glyphs = [ None() | glyphs]
  # |> Enum.zip(list, tl(list), tl(tl(list))) (Enum.chunk_every(list, 3, 1, :discard)と等価。高速なので採用）
  # |> Stream.map(&calc_kerning/1)
  # のような形。
  def build_render(
        width,
        height,
        # normal break_all keep_all break_word
        line_break \\ :normal,
        # px単位指定
        line_height \\ 0,
        # start end left right up down center justify
        text_align \\ :start,
        text_align_last \\ :start,
        word_spacing \\ 0,
        letter_spacing \\ 0
      ) do
    %__MODULE__{
      boundry: %{width: width, height: height},
      line_break: line_break,
      line_height: line_height,
      text_align: text_align,
      text_align_last: text_align_last,
      word_spacing: word_spacing,
      letter_spacing: letter_spacing
    }
  end

  def build_none() do
    %Glyph{
      offset: %{x: 0, y: 0},
      aligment: %{x: 0, y: 0},
      path: %SVG.Path{},
      children_glyph_list: [],
      font: nil,
      name: %{glyph: "", variant: nil, type: "None", form: nil},
      height: %{y0: 0, y1: 0, y2: 0, y3: 0}
    }
  end

  def alter_newline(word_list) do
    {sentence, _} =
      word_list
      |> Enum.reduce({[], 0}, fn {word, top, bottom, row}, {acc, acc_raw} ->
        {[{word, top, bottom, row != acc_raw} | acc], row}
      end)

    sentence =
      sentence
      |> Enum.chunk_while(
        [],
        fn {glyph_list, top, bottom, row} = word, acc_word ->
          cond do
            true ->
              if row,
                do: {:cont, Enum.reverse([word | acc_word]), []},
                else: {:cont, [word | acc_word]}
          end
        end,
        fn
          [] -> {:cont, []}
          acc_word -> {:cont, Enum.reverse(acc_word), []}
        end
      )

    [first_line | rest_line] = sentence
  end

  def parse_word(glyph_and_kern_list) do
    syd =
      Enum.chunk_while(
        glyph_and_kern_list,
        [],
        fn glyph, acc ->
          if glyph.new_line,
            do: {:cont, Enum.reverse([glyph | acc]), []},
            else: {:cont, [glyph | acc]}
        end,
        fn
          [] -> {:cont, []}
          acc -> {:cont, Enum.reverse(acc), []}
        end
      )

    syd |> Enum.map(fn l -> Enum.chunk_by(l, fn glyph -> glyph.word_breaker end) end)
  end

  def concat_path_data(glyph_list) when is_list(glyph_list) do
    Enum.map(glyph_list, fn glyph_and_kern ->
      %{x: x, y: y, glyph: %Glyph{offset: %{x: off_x, y: off_y}, path: path, name: name}} =
        glyph_and_kern

      SVG.Path.set_start_position(path, x + off_x, y + off_y) |> SVG.Path.export_as_string_mass!()
    end)
    |> Enum.join("")
  end

  # まず行単位、単語単位で切り分ける(java風に表現するならば[行座標][単語座標][文字の座標] の3重リストに)

  # ※line_breakが :break_word 以外の場合は別の処理を取る
  # →まずは単語毎に分割した位置情報を作成(単語中の文字の空白はletter_spacing、単語間の空白はword_spacingで追加)
  # →折り返し(wrap)が発生する場合は行を調整（raw_subにより制御）
  # 一旦[単語座標][文字の座標]のように整形したうえで、(raw,raw_sub)の組を基準に再び[行座標][単語座標][文字の座標]のような形式へと戻す

  # 次に行ごとの位置調整（text_alignに基づいて左寄せなり中央寄せなりjustifyにしたり。ここでは二層まで潜る）
  # 単語毎に纏めているのを解いて行ごとの高さの指定を行う
  # 最後に行ごとにまとめているのも解き、全部のglyphにoffsetを適応する

  def alignment_path_data_as_horizontal(%Bundle{} = prefab, glyph_list, %__MODULE__{} = render)
      when is_list(glyph_list),
      do: Thaqqa.RenderHorizontal.alignment_path_data_as_horizontal(prefab, glyph_list, render)

  def alignment_path_data_as_vertical(%Bundle{} = prefab, glyph_list, %__MODULE__{} = render)
      when is_list(glyph_list),
      do: Thaqqa.RenderVertical.alignment_path_data_as_vertical(prefab, glyph_list, render)

  # streamで処理する方式
  def build_path_data_stream(
        %Bundle{} = prefab,
        syllable_list,
        font,
        writing_direction,
        default_scale
      )
      when is_list(syllable_list) do
    Task.async_stream(
      syllable_list,
      fn syl ->
        with {:ok, glyph} <- Glyph.new(prefab, font, syl, writing_direction, default_scale) do
          {:ok, Glyph.set_path(glyph)}
        else
          {:error, _} = err -> err
        end
      end,
      ordered: true
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, str}}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:ok, {:error, _} = err}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      {:error, _} = err -> err
    end
  end

  def build_path_data(%Bundle{} = prefab, syllable_list, font, writing_direction, default_scale)
      when is_list(syllable_list) do
    # TODO Style()とマッチするSyllableだった場合は処理を変更する
    # _style_accはstyle適応の際の処理用。
    Enum.reduce_while(syllable_list, {:ok, {[], []}}, fn syl, {:ok, {_style_acc, acc}} ->
      with {:ok, glyph} <- Glyph.new(prefab, font, syl, writing_direction, default_scale) do
        # 現状set_pathにエラーを吐く要因はないが
        # 今後エラー処理が必要になった場合を鑑みてwith文とする
        {:cont, {:ok, {_style_acc, [Glyph.set_path(glyph) | acc]}}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      {:ok, {_, glyph_list}} -> Enum.reverse(glyph_list)
    end
  end

  def verficate_syllable(%Bundle{} = prefab, syllable_list) when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, nil, fn syl, _ ->
      case ConstRegexKhhylTable.whole_of_string_match_at_once?(prefab, "EverySingleLetter", syl) do
        {:error, _} = err ->
          {:halt, err}

        {:ok, true} ->
          {:cont, nil}

        {:ok, _} ->
          case ConstRegexKhhylTable.whole_of_string_match?(prefab, "EverySingleLetter", syl) do
            {:error, _} = err -> {:halt, err}
            {:ok, true} -> {:halt, Error.unparsed_syllable(syl)}
            {:ok, otherwise} -> {:halt, Error.invalid_syllable(otherwise)}
          end
      end
    end)
    |> case do
      {:error, _} = err -> err
      _ -> {:ok, syllable_list}
    end
  end

  def split_by_syllable(%Bundle{} = prefab, string) do
    case ConstRegexKhhylTable.get_const(prefab, "EveryDoubleLetter") do
      {:error, _} = err ->
        err

      {:ok, const} ->
        regex = const |> Thaqqa.Data.get_value(@precompile)

        string = Regex.replace(regex, string, "\\g{1}Sep()\\g{2}")
        string = Regex.replace(regex, string, "\\g{1}Sep()\\g{2}")

        {:ok, String.split(string, "Sep()")}
    end
  end

  def convert_into_khhyl_letter(%Bundle{} = prefab, string, font, language, writing_direction)
      when language in [@khehyelu, @samlhta] and writing_direction in [@vertical, @horizontal] do
    {:ok, p} = ParserTable.interpret(prefab, string, language)

    GsubTable.gsub(prefab, p, writing_direction)

    with {:ok, parsed_string} <- ParserTable.interpret(prefab, string, language),
         {:ok, gsub_string} <- GsubTable.gsub(prefab, parsed_string, writing_direction),
         {:ok, unique_gsub_string} <-
           UniqueGsubTable.unique_gsub(prefab, gsub_string, font, writing_direction) do
      {:ok, unique_gsub_string}
    else
      {:error, _} = err -> err
    end
  end

  # prefabを持たない場合、FontRegistryから直接読み込む。
  def convert_into_khhyl_letter!(string, font, language, writing_direction) do
    # FontRegistry落ちを想定し、try-catch文でのエラーを実装している
    try do
      {:ok, prefab} = FontRegistry.create_prefab()
      convert_into_khhyl_letter(prefab, string, font, language, writing_direction)
    catch
      :exit, {:noproc, _} -> {:error, :font_registry_restarting}
      :exit, {:timeout, _} -> {:error, :font_registry_timeout}
      :exit, reason -> {:error, {:font_registry_exit, reason}}
    end
  end
end
