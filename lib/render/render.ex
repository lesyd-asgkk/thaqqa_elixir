defmodule Thaqqa.Render do
  alias Thaqqa.FontRegistryPrefab, as: Prefab
  alias Thaqqa.FontRegistry.Error, as: Error
  alias Thaqqa.FontRegistry, as: FontRegistry
  alias Thaqqa.ParserManager, as: ParserManager
  alias Thaqqa.GsubManager, as: GsubManager
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.UniqueGsubManager, as: UniqueGsubManager
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager

  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.Data, as: Data
  use Thaqqa.DataTable.Const

  defstruct boundry: %{width: 0, height: 0},
            line_break: :normal,
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
        # start end left right center justify
        text_align \\ :start,
        text_align_last \\ :start,
        word_spacing \\ 0,
        letter_spacing \\ 0
      ) do
    %__MODULE__{
      boundry: %{width: width, height: height},
      line_break: line_break,
      text_align: text_align,
      text_align_last: text_align_last,
      word_spacing: word_spacing,
      letter_spacing: letter_spacing
    }
  end

  defp build_none() do
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

  def calc_kerning_horizontal(
        [
          %Glyph{name: %{glyph: prev_glyph_name}} = prev_glyph,
          %Glyph{name: %{glyph: glyph_name}, font: fontname, path: path} = glyph,
          %Glyph{name: %{glyph: next_glyph_name}} = next_glyph
        ],
        %Prefab{} = prefab
      ) do
    newline_as_regex_khhyl = "P([_.IsNewline]_-*)"

    with {:ok, %{isWidthHRel: is_width_relative, WidthH: width, TopGapH: gap_top, Height: height}} <-
           Prefab.get_fontdata(prefab, fontname, ["isWidthHRel", "WidthH", "TopGapH", "Height"]),
         {:ok, %{x0: x0_internal, y0: y0_internal, x1: x1_internal, y1: y1_internal}} <-
           GposManager.gpos(prefab, fontname, glyph_name, @horizontal, @internal),
         {:ok, %{x0: x0_ex_prev, y0: y0_ex_prev, x1: x1_ex_prev, y1: y1_ex_prev}} <-
           GposManager.gpos(
             prefab,
             fontname,
             prev_glyph_name <> glyph_name,
             @horizontal,
             @external
           ),
         {:ok, %{x0: x0_ex_next, y0: y0_ex_next, x1: x1_ex_next, y1: y1_ex_next}} <-
           GposManager.gpos(
             prefab,
             fontname,
             glyph_name <> next_glyph_name,
             @horizontal,
             @external
           ),
         GposManager.gpos(prefab, fontname, glyph_name, @horizontal, @internal),
         {:ok, %{x0: x0_ex_prev_nl, y0: y0_ex_prev_nl, x1: x1_ex_prev_nl, y1: y1_ex_prev_nl}} <-
           GposManager.gpos(
             prefab,
             fontname,
             newline_as_regex_khhyl <> glyph_name,
             @horizontal,
             @external
           ),
         {:ok, %{x0: x0_ex_next_nl, y0: y0_ex_next_nl, x1: x1_ex_next_nl, y1: y1_ex_next_nl}} <-
           GposManager.gpos(
             prefab,
             fontname,
             glyph_name <> newline_as_regex_khhyl,
             @horizontal,
             @external
           ),
         {:ok, is_newline_raw} <-
           ConstRegexManager.whole_of_string_match_at_once?(prefab, "Newline", glyph_name),
         {:ok, is_wordbreaker_raw} <-
           ConstRegexManager.whole_of_string_match_at_once?(prefab, "WordBreaker", glyph_name),
         {:ok, new_glyph} <-
           Glyph.render_by_absolute_height(
             prefab,
             glyph,
             height * glyph.scale,
             (y1_internal + 0.5 * height) * glyph.scale
           ) do
      is_wordbreaker = is_wordbreaker_raw === true
      is_newline = is_newline_raw === true

      scale = glyph.scale
      prev_scale = prev_glyph.scale || glyph.scale
      next_scale = next_glyph.scale || glyph.scale

      %{top: t, bottom: b, left: l, right: r} = SVG.Path.get_border(new_glyph.path)

      {:ok,
       %{
         glyph: new_glyph,
         new_line: is_newline,
         word_breaker: is_wordbreaker,
         box: %{
           top: 0,
           bottom: height * scale,
           left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
           right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
         },
         gap: %{
           top: gap_top * scale,
           left: x0_internal * scale + x1_ex_prev * prev_scale,
           right: x1_internal * scale + x1_ex_next * next_scale,
           center: y1_internal * scale
         },
         gap_when_newline: %{
           top: gap_top * scale,
           left: x0_internal * scale + x1_ex_prev_nl * prev_scale,
           right: x1_internal * scale + x1_ex_next_nl * next_scale,
           center: y1_internal * scale
         }
       }}
    else
      {:error, _} = err -> err
    end
  end

  def concat_path_data_as_horizontal(glyph_list) do
    Enum.map(glyph_list, fn glyph_and_kern ->
      %{x: x, y: y, glyph: %Glyph{offset: %{x: off_x, y: off_y}, path: path}} = glyph_and_kern
      SVG.Path.set_start_position(path, x + off_x, y + off_y) |> SVG.Path.export_as_string_mass!()
    end)
    |> Enum.join("")
  end

  defp parse_word(glyph_and_kern_list) do
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
    |> Enum.map(fn l -> Enum.chunk_by(l, fn glyph -> glyph.word_breaker end) end)
  end

  # まず行単位、単語単位で切り分ける(java風に表現するならば[行座標][単語座標][文字の座標] の3重リストに)

  # ※line_breakが:break_word以外の場合は別の処理を取る
  # →まずは単語毎に分割した位置情報を作成(単語中の文字の空白はletter_spacing、単語間の空白はword_spacingで追加)
  # →折り返し(wrap)が発生する場合は行を調整（raw_subにより制御）
  # 一旦[単語座標][文字の座標]のように整形したうえで、(raw,raw_sub)の組を基準に再び[行座標][単語座標][文字の座標]のような形式へと戻す

  # normal break_all keep_all break_word
  # word_break \\ :normal,

  # start end left right center justify
  # text_align \\ :start,

  defp set_position_and_wrapped(sentence, %__MODULE__{} = render_config) do
    word_spacing = render_config.word_spacing
    letter_spacing = render_config.letter_spacing
    box_width = render_config.boundry.width

    sentence_alt =
      Enum.reduce(
        sentence,
        {[], 0},
        fn oneline, {acc_word_list, acc_row} ->
          oneline_alt =
            Enum.reduce(
              oneline,
              {[], 0, 0, acc_row},
              fn word, {acc_word, acc_left, acc_right, acc_row} ->
                acc_left_start = acc_left
                acc_right_start = acc_right

                word_alt =
                  Enum.reduce(
                    word,
                    {[], acc_right_start, acc_right_start, acc_right_start, false},
                    fn glyph_and_kern, {acc_glyph, acc_left, acc_x, acc_right, is_wrapped} ->
                      %{
                        glyph: glyph,
                        new_line: is_newline,
                        word_breaker: is_wordbreaker,
                        box: %{top: top, bottom: bottom, left: left, right: right},
                        gap: %{top: gap_top, center: gap_center, left: gap_left, right: gap_right},
                        gap_when_newline: %{
                          top: gap_top_nl,
                          center: gap_center_nl,
                          left: gap_left_nl,
                          right: gap_right_nl
                        }
                      } = glyph_and_kern

                      blank_space =
                        if is_wordbreaker,
                          do: word_spacing + letter_spacing,
                          else: letter_spacing

                      glyph_x = acc_x + gap_left + left + blank_space / 2

                      next_x = acc_x + gap_left + left + gap_right + right + blank_space

                      # スタート位置からの相対座標に換算
                      glyph_and_kern =
                        glyph_and_kern
                        |> Map.put(:x, glyph_x - acc_right_start)
                        |> Map.put(:gap_top, gap_top)
                        |> Map.put(:height, bottom)
                        |> Map.put(:border, %{
                          left: acc_x - acc_right_start,
                          right: next_x - acc_right_start
                        })

                      acc_left = min(acc_left, acc_x)
                      acc_right = max(acc_right, next_x)

                      # 改行処理部分。一回でも改行処理判定に引っかかったら以降はtrueになる
                      # TODO：,といった約物を改行判定から無視する
                      # ※is_wrappedの初期値はfalseなのでこれで一回でもtrueになったかは判定できる
                      cond_wrap = acc_right > box_width
                      is_wrapped = cond_wrap || is_wrapped

                      acc_x = next_x
                      {[glyph_and_kern | acc_glyph], acc_left, acc_x, acc_right, is_wrapped}
                    end
                  )

                {glyph_list, left, _, right, is_wrapped} = word_alt
                acc_row = if is_wrapped, do: acc_row + 1, else: acc_row
                acc_left = if is_wrapped, do: left - acc_right, else: left
                acc_right = if is_wrapped, do: right - acc_right, else: right

                word = {Enum.reverse(glyph_list), acc_left, acc_right, acc_row}
                {[word | acc_word], acc_left, acc_right, acc_row}
              end
            )

          {word_list, _, _, acc_row} = oneline_alt
          {acc_word_list ++ word_list, acc_row + 1}
        end
      )
  end

  defp adjust_position_sub(oneline, text_align, box_width) do
    word_num = length(oneline)

    left = Enum.map(oneline, fn {_, left, _, _} -> left end) |> Enum.min()
    right = Enum.map(oneline, fn {_, _, right, _} -> right end) |> Enum.max()

    left_calc = -left
    right_calc = box_width - right

    gap_list =
      case text_align do
        :start ->
          List.duplicate(left_calc, word_num)

        :left ->
          List.duplicate(left_calc, word_num)

        :end ->
          List.duplicate(right_calc, word_num)

        :right ->
          List.duplicate(right_calc, word_num)

        :center ->
          List.duplicate((left_calc + right_calc) / 2, word_num)

        :justify ->
          if word_num == 1,
            do: [0],
            else:
              Enum.map(0..(word_num - 1), fn n ->
                left_calc * (1 - word_num / (n - 1)) + right_calc * (word_num / (n - 1))
              end)
      end

    oneline_alt =
      Enum.zip(oneline, gap_list)
      |> Enum.map(fn {{word_list, left, _, _}, gap} ->
        {word_list, left + gap}
      end)
      |> Enum.reduce(
        [],
        fn {glyph_list, gap_from_left}, acc_glyph_list ->
          glyph_list_alt =
            Enum.map(glyph_list, fn glyph_and_kern ->
              glyph_and_kern
              |> Map.put(:x, glyph_and_kern.x + left)
              |> Map.put(:border, %{
                left: glyph_and_kern.border.left + gap_from_left,
                right: glyph_and_kern.border.right + gap_from_left
              })
            end)

          acc_glyph_list ++ glyph_list_alt
        end
      )
  end

  defp adjust_position_x(sentence, %__MODULE__{} = render_config) do
    box_width = render_config.boundry.width
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last

    [last_line | rest_line] = Enum.reverse(sentence)

    Enum.reduce(
      rest_line,
      [adjust_position_sub(last_line, text_align_last, box_width)],
      fn oneline, acc_oneline_list ->
        oneline_alt = adjust_position_sub(oneline, text_align, box_width)
        [oneline_alt | acc_oneline_list]
      end
    )
  end

  defp adjust_position_y(sentence) do
    {sentence_alt, _} =
      Enum.reduce(
        sentence,
        {[], 0},
        fn oneline, {acc_oneline_list, acc_y} ->
          Enum.map(oneline, fn glyph -> glyph.glyph.name.glyph end)
          |> IO.inspect()

          {max_height, max_gap_top} =
            Enum.reduce(oneline, {0, 0}, fn g, {acc_height, acc_gap_top} ->
              {max(acc_height, g.height), max(acc_gap_top, g.gap_top)}
            end)

          oneline_alt =
            Enum.map(oneline, fn g ->
              top_gap = max_height - g.height
              Map.put(g, :y, acc_y + max_gap_top + top_gap)
            end)

          Enum.reverse(oneline_alt)

          {acc_oneline_list ++ oneline_alt, acc_y + max_height + max_gap_top}
        end
      )

    sentence_alt
  end

  defp adjust_position(sentence, %__MODULE__{} = render_config) do
    adjust_position_x(sentence, render_config) |> adjust_position_y()
  end

  defp alter_newline(word_list) do
    {sentence, _} =
      word_list
      |> Enum.reduce({[], 0}, fn {word, left, right, row}, {acc, acc_raw} ->
        {[{word, left, right, row != acc_raw} | acc], row}
      end)

    sentence
    |> Enum.chunk_while(
      [],
      fn {_, left, right, row} = word, acc_word ->
        if row,
          do: {:cont, Enum.reverse([word | acc_word]), []},
          else: {:cont, [word | acc_word]}
      end,
      fn
        [] -> {:cont, []}
        acc_word -> {:cont, Enum.reverse(acc_word), []}
      end
    )
  end

  defp set_position(sentence, %__MODULE__{} = render_config) do
    {word_list, _} = set_position_and_wrapped(sentence, render_config)
    alter_newline(word_list) |> adjust_position(render_config)

    # 次に行ごとの位置調整（text_alignに基づいて左寄せなり中央寄せなりjustifyにしたり。ここでは二層まで潜る）
    # 単語毎に纏めているのを解いて行ごとの高さの指定を行う
    # 最後に行ごとにまとめているのも解き、全部のglyphにoffsetを適応する
  end

  def alignment_path_data_as_horizontal(%Prefab{} = prefab, glyph_list)
      when is_list(glyph_list) do
    none = build_none()

    glyph_and_kern_list =
      [none | glyph_list ++ [none]]
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(&calc_kerning_horizontal(&1, prefab))

    Enum.reduce_while(glyph_and_kern_list, {:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, g_a_k_l} ->
        Enum.reverse(g_a_k_l) |> parse_word() |> set_position(build_render(200, 600))
    end

    # {:ok, glyph_and_kern_list} = glyph_and_kern_list |> parse_word()

    # glyph_and_kern_list |> set_position(build_render(800, 600))
    # set_position_and_flag()

    # set_position_y(glyph_and_kern_list)
    # あとはglyphの棒を挿したりするだけ
    # prefab
  end

  # streamで処理する方式
  def build_path_data_stream(
        %Prefab{} = prefab,
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

  def build_path_data(%Prefab{} = prefab, syllable_list, font, writing_direction, default_scale)
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

  def verficate_syllable(%Prefab{} = prefab, syllable_list) when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, nil, fn syl, _ ->
      case ConstRegexManager.whole_of_string_match_at_once?(prefab, "EverySingleLetter", syl) do
        {:error, _} = err ->
          {:halt, err}

        {:ok, true} ->
          {:cont, nil}

        {:ok, _} ->
          case ConstRegexManager.whole_of_string_match?(prefab, "EverySingleLetter", syl) do
            {:error, _} = err ->
              {:halt, err}

            {:ok, true} ->
              {:halt, {:error, "unparsed pattern found: #{syl}"}}

            {:ok, otherwise} ->
              {:halt, {:error, "invalid pattern found: #{otherwise}"}}
          end
      end
    end)
    |> case do
      {:error, _} = err -> err
      _ -> {:ok, syllable_list}
    end
  end

  def split_by_syllable(%Prefab{} = prefab, string) do
    case ConstRegexManager.get_const(prefab, "EveryDoubleLetter") do
      {:error, _} = err ->
        err

      {:ok, const} ->
        regex = const |> Thaqqa.Data.get_value(@precompile)

        {:ok,
         Regex.scan(regex, string)
         |> Enum.reduce([], fn list, acc ->
           [_ | list] = list
           acc ++ list
         end)}
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

  defp set_position_and_flag(glyph_and_kern_list) do
    Enum.reduce_while(
      glyph_and_kern_list,
      {:ok, {[], %{x: 0}}},
      fn g_and_k, {:ok, {acc_glyph, acc_data}} ->
        case g_and_k do
          {:ok,
           %{
             glyph: glyph,
             new_line: is_newline,
             word_breaker: is_wordbreaker,
             box: %{top: top, bottom: bottom, left: left, right: right},
             gap: %{top: gap_top, center: gap_center, left: gap_left, right: gap_right},
             gap_when_newline: %{
               top: gap_top_nl,
               center: gap_center_nl,
               left: gap_left_nl,
               right: gap_right_nl
             }
           }} ->
            glyph_position = acc_data.x
            glyph_x = glyph_position + gap_left + left
            next_x = glyph_position + gap_left + left + gap_right + right

            # next_xの座標を参考に強制的に改行を挟む処理部分
            # render項目を付け加えた際、renderのパロメータに応じて処理する
            #
            cond_wrap = false

            acc_data_x =
              cond do
                is_newline == true -> 0
                cond_wrap == true -> 0
                true -> next_x
              end

            {glyph_x, next_x, is_newline} =
              if cond_wrap,
                do: {0 + gap_left_nl + left, 0 + gap_left_nl + left + gap_right_nl + right, true},
                else: {glyph_x, next_x, is_newline}

            internal_attribution =
              Map.put(glyph.internal_attribution, :gap_top, gap_top)
              |> Map.put(:gap_center, gap_center)
              |> Map.put(:is_wordbreaker, is_wordbreaker)
              |> Map.put(:is_newline, is_newline)
              |> Map.put(:left_width, glyph_position)
              |> Map.put(:center, glyph_x)
              |> Map.put(:right_width, next_x)
              |> Map.put(:height, bottom)

            glyph_new = %Glyph{glyph | internal_attribution: internal_attribution}

            acc_data = %{acc_data | x: acc_data_x}

            {:cont, {:ok, {[glyph_new | acc_glyph], acc_data}}}

          {:error, _} = err ->
            {:halt, err}
        end
      end
    )
    |> case do
      {:error, _} = err -> err
      {:ok, {acc_path, _acc_data}} -> {:ok, Enum.reverse(acc_path)}
    end
  end
end
