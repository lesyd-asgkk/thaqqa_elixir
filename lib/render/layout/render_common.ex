# 処理で共通に出来るところを共通化していくぞ～ついでに見やすくする
defmodule Thaqqa.RenderCommon do
  alias Thaqqa.Bundle, as: Bundle

  alias Thaqqa.Render, as: Render
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.Bundle.GposTable, as: GposTable
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable
  use Thaqqa.DataTable.Const

  # 第一段階、kerningデータの計算
  defp calc_kerning(
         [
           %Glyph{name: %{glyph: prev_glyph_name}} = prev_glyph,
           %Glyph{name: %{glyph: glyph_name}, font: fontname, path: path} = glyph,
           %Glyph{name: %{glyph: next_glyph_name}} = next_glyph
         ],
         %Bundle{} = prefab,
         direction
       )
       when direction in [@vertical, @horizontal] do
    newline_as_regex_khhyl = "P([_.IsNewline]_-*)"

    with {:ok,
          %{
            isWidthHRel: is_width_relative_h,
            isWidthVRel: is_width_relative_v,
            WidthH: width_h,
            WidthV: width_v,
            TopGapH: gap_top,
            Height: height
          }} <-
           Bundle.get_fontdata(prefab, fontname, [
             "isWidthHRel",
             "isWidthVRel",
             "WidthH",
             "WidthV",
             "TopGapH",
             "Height"
           ]),
         {:ok, %{x0: x0_internal, y0: y0_internal, x1: x1_internal, y1: y1_internal}} <-
           GposTable.gpos(prefab, fontname, glyph_name, direction, @internal),
         {:ok, %{x0: x0_ex_prev, y0: y0_ex_prev, x1: x1_ex_prev, y1: y1_ex_prev}} <-
           GposTable.gpos(
             prefab,
             fontname,
             prev_glyph_name <> glyph_name,
             direction,
             @external
           ),
         {:ok, %{x0: x0_ex_next, y0: y0_ex_next, x1: x1_ex_next, y1: y1_ex_next}} <-
           GposTable.gpos(
             prefab,
             fontname,
             glyph_name <> next_glyph_name,
             direction,
             @external
           ),
         GposTable.gpos(prefab, fontname, glyph_name, direction, @internal),
         {:ok, %{x0: x0_ex_prev_nl, y0: y0_ex_prev_nl, x1: x1_ex_prev_nl, y1: y1_ex_prev_nl}} <-
           GposTable.gpos(
             prefab,
             fontname,
             newline_as_regex_khhyl <> glyph_name,
             direction,
             @external
           ),
         {:ok, %{x0: x0_ex_next_nl, y0: y0_ex_next_nl, x1: x1_ex_next_nl, y1: y1_ex_next_nl}} <-
           GposTable.gpos(
             prefab,
             fontname,
             glyph_name <> newline_as_regex_khhyl,
             direction,
             @external
           ),
         {:ok, is_newline_raw} <-
           ConstRegexKhhylTable.whole_of_string_match_at_once?(prefab, "Newline", glyph_name),
         {:ok, is_wordbreaker_raw} <-
           ConstRegexKhhylTable.whole_of_string_match_at_once?(prefab, "WordBreaker", glyph_name),
         {:ok, new_glyph_for_h} <-
           Glyph.render_by_absolute_height(
             prefab,
             glyph,
             height * glyph.scale,
             (y1_internal + 0.5 * height) * glyph.scale
           ),
         {:ok, glyph_for_meassure_v} <-
           Glyph.render_by_relative_height(prefab, glyph, 0, 0) do
      is_wordbreaker = is_wordbreaker_raw === true
      is_newline = is_newline_raw === true

      is_width_relative =
        if(direction == @horizontal, do: is_width_relative_h, else: is_width_relative_v)

      width =
        if(direction == @horizontal, do: width_h, else: width_v)

      scale = glyph.scale
      prev_scale = prev_glyph.scale || glyph.scale
      next_scale = next_glyph.scale || glyph.scale

      glyph_for_meassure =
        if direction == @horizontal, do: new_glyph_for_h, else: glyph_for_meassure_v

      %{top: t, bottom: b, left: l, right: r} = SVG.Path.get_border(glyph_for_meassure.path)

      box_h = %{
        top: 0,
        bottom: height * scale,
        left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
        right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
      }

      box_v = %{
        top: t,
        bottom: b,
        left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
        right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
      }

      gap_h = %{
        top: gap_top * scale,
        left: x0_internal * scale + x1_ex_prev * prev_scale,
        right: x1_internal * scale + x0_ex_next * next_scale,
        center: y1_internal * scale
      }

      gap_v = %{
        top: y0_internal * scale + y1_ex_prev * prev_scale,
        left: 0,
        right: 0,
        bottom: y1_internal * scale + y0_ex_next * next_scale
      }

      gap_wn_h = %{
        top: gap_top * scale,
        left: x0_internal * scale + x1_ex_prev_nl * prev_scale,
        right: x1_internal * scale + x0_ex_next_nl * next_scale,
        center: y1_internal * scale
      }

      gap_wn_v = %{
        top: y0_internal * scale + y1_ex_prev_nl * prev_scale,
        left: 0,
        right: 0,
        bottom: y1_internal * scale + y0_ex_next_nl * next_scale
      }

      {:ok,
       %{
         glyph: if(direction == @horizontal, do: new_glyph_for_h, else: glyph),
         new_line: is_newline,
         word_breaker: is_wordbreaker,
         prohibit_line_start: false,
         prohibit_line_end: false,
         box: if(direction == @horizontal, do: box_h, else: box_v),
         gap: if(direction == @horizontal, do: gap_h, else: gap_v),
         gap_when_newline: if(direction == @horizontal, do: gap_wn_h, else: gap_wn_v)
       }}
    else
      {:error, _} = err -> err
    end
  end

  # newline単位/word単位でparseする
  # [i行目の行][jつ目の単語]
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

  # 条件依存で改行する

  def set_oneline() do
  end

  defp set_position_and_wrapped(sentence, %Render{} = render_config, direction)
       when direction in [@vertical, @horizontal] do
    word_spacing = render_config.word_spacing
    letter_spacing = render_config.letter_spacing
    box_width = render_config.boundry.width
    box_height = render_config.boundry.height

    # [行（仮）][単語][単語の何文字めか]　…なんだけど、行が変動するので行(仮)としている。
    sentence_alt =
      Enum.reduce(
        sentence,
        %{word_list: [], acc_row: 0},
        fn oneline, %{word_list: acc_word_list, row: acc_row} ->
          oneline_alt =
            Enum.reduce(
              oneline,
              %{
                word: [],
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                row: acc_row
              },
              fn word,
                 %{
                   word: acc_word,
                   left: acc_left,
                   right: acc_right,
                   top: acc_top,
                   bottom: acc_bottom,
                   row: acc_row
                 } ->
                # 右から書くのを実装する時に使う
                # acc_left_start = acc_left
                acc_right_start = acc_right
                # acc_top_start = acc_top
                acc_bottom_start = acc_bottom

                word_alt =
                  Enum.reduce(
                    word,
                    %{
                      glyph_list: [],
                      left: acc_right_start,
                      x: acc_right_start,
                      right: acc_right_start,
                      top: acc_bottom_start,
                      y: acc_bottom_start,
                      bottom: acc_bottom_start,
                      is_wrapped: false
                    },
                    fn glyph_and_kern,
                       %{
                         glyph_list: acc_glyph,
                         left: acc_left,
                         x: acc_x,
                         right: acc_right,
                         top: acc_top,
                         y: acc_y,
                         bottom: acc_bottom,
                         is_wrapped: is_wrapped
                       } ->
                      %{
                        word_breaker: is_wordbreaker,
                        box: %{top: top, bottom: bottom, left: left, right: right},
                        gap: %{
                          top: gap_top,
                          bottom: gap_bottom,
                          left: gap_left,
                          right: gap_right
                        },
                        gap_when_newline: %{
                          top: gap_top_nl,
                          bottom: gap_bottom_nl,
                          left: gap_left_nl,
                          right: gap_right_nl
                        }
                      } = glyph_and_kern

                      blank_space =
                        if is_wordbreaker,
                          do: word_spacing + letter_spacing,
                          else: letter_spacing

                      glyph_x = acc_x + gap_left + left + blank_space / 2

                      glyph_y = acc_y - top + blank_space / 2

                      next_x = acc_x + gap_left + left + gap_right + right + blank_space
                      next_y = acc_y + gap_top - top + gap_bottom + bottom + blank_space
                      # スタート位置からの相対座標に換算
                      gap_top_actual =
                        if direction == @horizontal, do: gap_top, else: +gap_top + blank_space / 2

                      glyph_and_kern =
                        glyph_and_kern
                        |> Map.put(:y, glyph_y - acc_bottom_start)
                        |> Map.put(:gap_top, gap_top_actual)
                        |> Map.put(:gap_bottom, gap_bottom + blank_space / 2)
                        |> Map.put(:x, glyph_x - acc_right_start)
                        |> Map.put(:height, bottom)
                        |> Map.put(:border, %{
                          left: acc_x - acc_right_start,
                          right: next_x - acc_right_start,
                          top: acc_y - acc_bottom_start,
                          bottom: next_y - acc_bottom_start
                        })

                      acc_left = min(acc_left, acc_x)
                      acc_right = max(acc_right, next_x)
                      acc_top = min(acc_top, acc_y)
                      acc_bottom = max(acc_bottom, next_y)

                      # 改行処理部分。一回でも改行処理判定に引っかかったら以降はtrueになる
                      # TODO：,といった約物を改行判定から無視する
                      # ※is_wrappedの初期値はfalseなのでこれで一回でもtrueになったかは判定できる
                      cond_wrap =
                        if direction == @horizontal,
                          do: acc_right > box_width,
                          else: acc_bottom > box_height

                      is_wrapped = cond_wrap || is_wrapped

                      acc_x = next_x

                      %{
                        glyph_list: [glyph_and_kern | acc_glyph],
                        left: acc_left,
                        x: acc_x,
                        right: acc_right,
                        top: acc_top,
                        y: acc_y,
                        bottom: acc_bottom,
                        is_wrapped: is_wrapped
                      }
                    end
                  )

                %{
                  glyph_list: glyph_list,
                  left: left,
                  right: right,
                  top: top,
                  bottom: bottom,
                  is_wrapped: is_wrapped
                } = word_alt

                acc_row = if is_wrapped, do: acc_row + 1, else: acc_row
                acc_left = if is_wrapped, do: left - acc_right, else: left
                acc_right = if is_wrapped, do: right - acc_right, else: right
                acc_top = if is_wrapped, do: top - acc_bottom, else: top
                acc_bottom = if is_wrapped, do: bottom - acc_bottom, else: bottom

                word = %{
                  glyph_list: Enum.reverse(glyph_list),
                  left: acc_left,
                  right: acc_right,
                  top: acc_top,
                  bottom: acc_bottom,
                  row: acc_row
                }

                %{
                  word: [word | acc_word],
                  left: acc_left,
                  right: acc_right,
                  top: acc_top,
                  bottom: acc_bottom,
                  row: acc_row
                }
              end
            )

          %{word_list: word_list, row: acc_row} = oneline_alt
          %{word_list: [word_list | acc_word_list] |> List.flatten(), row: acc_row + 1}
        end
      )

    # row情報は要らないのでwordlist部分だけ返す
    sentence_alt.word_list
  end

  def alter_newline(word_list) do
    {sentence, _} =
      word_list
      |> Enum.reduce({[], 0}, fn %{word: word, top: top, bottom: bottom, row: row},
                                 {acc, acc_raw} ->
        {[%{word: word, top: top, bottom: bottom, row: row != acc_raw} | acc], row}
      end)

    sentence =
      sentence
      |> Enum.chunk_while(
        [],
        fn %{glyph_list: glyph_list, top: top, bottom: bottom, row: row} = word, acc_word ->
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

  defp adjust_position_in_line(oneline, text_align, box_boundery, direction) do
    word_num = length(oneline)

    left = Enum.map(oneline, fn {_, left, _, _} -> left end) |> Enum.min()
    right = Enum.map(oneline, fn {_, _, right, _} -> right end) |> Enum.max()
    top = Enum.map(oneline, fn {_, top, _, _} -> top end) |> Enum.min()
    bottom = Enum.map(oneline, fn {_, _, bottom, _} -> bottom end) |> Enum.max()

    left_calc = -left
    right_calc = box_boundery.width - right
    top_calc = -top
    bottom_calc = box_boundery.height - bottom

    # ここらへんに邪魔なspaceをどかす処理も（将来的には）入れる
    # 「isSpace」＋「強制改行によるものか」の２軸で判定。
    # 強制改行だったらisSpace依存で一つ（または全部）削除。
    # 強制改行じゃないなら削除判定を～と

    {enum_num, enum_list} =
      Enum.map(oneline, fn {glyph_list, _, _, _} ->
        [glyph_top | _] = glyph_list
        length(glyph_list) == 1 and (glyph_top.new_line or glyph_top.word_breaker)
      end)
      |> Enum.reduce({0, []}, fn is_null, {acc_num, acc_list} ->
        if is_null do
          {acc_num, [acc_num | acc_list]}
        else
          {acc_num + 1, [acc_num | acc_list]}
        end
      end)

    enum_list = Enum.reverse(enum_list)

    start_calc = if direction == @horizontal, do: left_calc, else: top_calc
    end_calc = if direction == @horizontal, do: right_calc, else: bottom_calc

    gap_list =
      case text_align do
        k when k in [:start, :left, :up] ->
          List.duplicate(start_calc, word_num)

        k when k in [:end, :right, :down] ->
          List.duplicate(end_calc, word_num)

        :center ->
          List.duplicate((start_calc + end_calc) / 2, word_num)

        :justify ->
          case word_num do
            0 ->
              []

            1 ->
              [start_calc]

            _ ->
              gap = (start_calc + end_calc) / (enum_num - 1)

              Enum.map(enum_list, fn n ->
                start_calc + gap * n
              end)
          end
      end

    Enum.zip(oneline, gap_list)
    |> Enum.map(fn {%{word_list: word_list, left: left, top: top}, gap} ->
      {word_list, if(direction == @horizontal, do: left + gap, else: top + gap)}
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

  defp adjust_position_along(sentence, %Render{} = render_config, direction) do
    box_boundry = render_config.boundry
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last
    [last_line | rest_line] = Enum.reverse(sentence)

    #
    Enum.reduce(
      rest_line,
      [adjust_position_in_line(last_line, text_align_last, box_boundry, direction)],
      fn oneline, acc_oneline_list ->
        oneline_alt = adjust_position_in_line(oneline, text_align, box_boundry, direction)
        [oneline_alt | acc_oneline_list]
      end
    )
  end

  defp adjust_position_normal(sentence, width, line_height, direction) do
    {sentence_alt, _} =
      Enum.reduce(
        sentence,
        {[], line_height},
        fn oneline, {acc_oneline_list, acc_x, acc_y} ->
          {max_height, max_gap_top} =
            Enum.reduce(oneline, {0, 0}, fn g, {acc_height, acc_gap_top} ->
              {max(acc_height, g.height), max(acc_gap_top, g.gap_top)}
            end)

          {left, right} =
            Enum.reduce(oneline, {0, 0}, fn g, {acc_left, acc_right} ->
              {max(acc_left, g.box.left), max(acc_right, g.box.right)}
            end)

          left = left + line_height / 2
          right = right + line_height / 2

          oneline_alt =
            case direction do
              @horizontal ->
                Enum.map(oneline, fn g -> Map.put(g, :x, acc_x - right) end)

              @vertical ->
                Enum.map(oneline, fn g ->
                  top_gap = max_height - g.height
                  Map.put(g, :y, acc_y + max_gap_top + top_gap)
                end)
            end

          Enum.reverse(oneline_alt)
          #

          {[oneline_alt | acc_oneline_list] |> List.flatten(), acc_x - left - right,
           acc_y + max_height + max_gap_top + line_height}
        end
      )

    sentence_alt
  end
end
