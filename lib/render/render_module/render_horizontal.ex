######
#
# 今後の課題　　見栄えが悪いだけで別に機能はするので後回しとする。
# タプル多用しすぎで可読性が終わってるので可能な限り使わない形に清書。moduleを多用してもいい。
# space系統を別枠処理にする（幅のみで演算）。Letter系のデータテーブルにIsSpaceを新設すること。
# Letter系のデータテーブルとして、禁則処理やisBreakable、isBreakableAsFinite,isBreakableAsInitialを追加
# （,や.、()といった記号の禁則処理判定用）
#
# Horizontal、Verticalでの共通処理の統合
#
#
######

defmodule Thaqqa.RenderHorizontal do
  alias Thaqqa.FontRegistryPrefab, as: Prefab

  alias Thaqqa.Render, as: Render
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.GposManager, as: GposManager
  alias Thaqqa.ConstRegexManager, as: ConstRegexManager
  use Thaqqa.DataTable.Const

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

  def concat_path_data_as_horizontal(glyph_list) when is_list(glyph_list) do
    Enum.map(glyph_list, fn glyph_and_kern ->
      %{x: x, y: y, glyph: %Glyph{offset: %{x: off_x, y: off_y}, path: path}} = glyph_and_kern
      SVG.Path.set_start_position(path, x + off_x, y + off_y) |> SVG.Path.export_as_string_mass!()
    end)
    |> Enum.join("")
  end

  defp calc_kerning_horizontal(
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
         prohibit_line_start: false,
         prohibit_line_end: false,
         box: %{
           top: 0,
           bottom: height * scale,
           left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
           right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
         },
         gap: %{
           top: gap_top * scale,
           left: x0_internal * scale + x1_ex_prev * prev_scale,
           right: x1_internal * scale + x0_ex_next * next_scale,
           center: y1_internal * scale
         },
         gap_when_newline: %{
           top: gap_top * scale,
           left: x0_internal * scale + x1_ex_prev_nl * prev_scale,
           right: x1_internal * scale + x0_ex_next_nl * next_scale,
           center: y1_internal * scale
         }
       }}
    else
      {:error, _} = err -> err
    end
  end

  defp parse_word(glyph_and_kern_list) do
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

  defp set_position_and_wrapped(sentence, %Render{} = render_config) do
    word_spacing = render_config.word_spacing
    letter_spacing = render_config.letter_spacing
    box_width = render_config.boundry.width
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last

    # TODO {[],0}のような部分をmapにする（可読性担保）
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
                        box: %{top: _top, bottom: bottom, left: left, right: right},
                        gap: %{
                          top: gap_top,
                          center: _gap_center,
                          left: gap_left,
                          right: gap_right
                        },
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
          {[word_list | acc_word_list] |> List.flatten(), acc_row + 1}
        end
      )

    sentence_alt
  end

  defp adjust_position_in_line(oneline, text_align, box_width) do
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
          case word_num do
            0 ->
              []

            1 ->
              [left_calc]

            _ ->
              gap = (left_calc + right_calc) / (word_num - 1)

              Enum.map(0..(word_num - 1), fn n ->
                left_calc + gap * n
              end)
          end
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
              |> Map.put(:x, glyph_and_kern.x + gap_from_left)
              |> Map.put(:border, %{
                left: glyph_and_kern.border.left + gap_from_left,
                right: glyph_and_kern.border.right + gap_from_left
              })
            end)

          [glyph_list_alt | acc_glyph_list] |> List.flatten()
        end
      )
  end

  defp adjust_position_x(sentence, %Render{} = render_config) do
    box_width = render_config.boundry.width
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last
    [last_line | rest_line] = Enum.reverse(sentence)

    #
    Enum.reduce(
      rest_line,
      [adjust_position_in_line(last_line, text_align_last, box_width)],
      fn oneline, acc_oneline_list ->
        oneline_alt = adjust_position_in_line(oneline, text_align, box_width)
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
          #

          {[oneline_alt | acc_oneline_list] |> List.flatten(), acc_y + max_height + max_gap_top}
        end
      )

    sentence_alt
  end

  defp adjust_position(sentence, %Render{} = render_config) do
    adjust_position_x(sentence, render_config) |> adjust_position_y()
  end

  defp alter_newline(word_list) do
    {sentence, _} =
      word_list
      |> Enum.reduce({[], 0}, fn {word, left, right, row}, {acc, acc_raw} ->
        {[{word, left, right, row != acc_raw} | acc], row}
      end)

    sentence =
      sentence
      |> Enum.chunk_while(
        [],
        fn {glyph_list, left, right, row} = word, acc_word ->
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

  defp set_position(sentence, %Render{} = render_config) do
    {word_list, _} = set_position_and_wrapped(sentence, render_config)
    alter_newline(word_list) |> adjust_position(render_config)
  end

  def alignment_path_data_as_horizontal(%Prefab{} = prefab, glyph_list, %Render{} = render)
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
        # px単位指定
        Enum.reverse(g_a_k_l) |> parse_word() |> set_position(render)
    end
  end
end
