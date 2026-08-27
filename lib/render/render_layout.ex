# 処理で共通に出来るところを共通化していくぞ～ついでに見やすくする
defmodule Thaqqa.RenderLayout do
  alias Thaqqa.Bundle, as: Bundle

  alias Thaqqa.Render, as: Render
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.Bundle.GposTable, as: GposTable
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable

  alias Thaqqa.Render.Box, as: Box
  alias Thaqqa.Render.GlyphData, as: GlyphData
  alias %Thaqqa.Render.Coordinate{}, as: Coordinate

  use Thaqqa.DataTable.Const

  # 第一段階、kerningデータの計算
  defp calc_kerning([prev_glyph, glyph, next_glyph], %Bundle{} = prefab, direction)
       when direction in [@vertical, @horizontal] do
    newline_as_regex_khhyl = "P([_.IsNewline]_-*)"
    %Glyph{name: %{glyph: prev_glyph_name}} = prev_glyph
    %Glyph{name: %{glyph: glyph_name}, font: fontname} = glyph
    %Glyph{name: %{glyph: next_glyph_name}} = next_glyph

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

      box_h = %Box{
        top: 0,
        bottom: height * scale,
        left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
        right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
      }

      box_v = %Box{
        top: t,
        bottom: b,
        left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
        right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
      }

      gap_h = %Box{
        top: gap_top * scale,
        left: x0_internal * scale + x1_ex_prev * prev_scale,
        right: x1_internal * scale + x0_ex_next * next_scale,
        # center: y1_internal * scale,
        bottom: 0
      }

      gap_v = %Box{
        top: y0_internal * scale + y1_ex_prev * prev_scale,
        left: 0,
        right: 0,
        # center: 0,
        bottom: y1_internal * scale + y0_ex_next * next_scale
      }

      gap_wn_h = %Box{
        top: gap_top * scale,
        left: x0_internal * scale + x1_ex_prev_nl * prev_scale,
        right: x1_internal * scale + x0_ex_next_nl * next_scale,
        # center: y1_internal * scale,
        bottom: 0
      }

      gap_wn_v = %Box{
        top: y0_internal * scale + y1_ex_prev_nl * prev_scale,
        left: 0,
        right: 0,
        # center: 0,
        bottom: y1_internal * scale + y0_ex_next_nl * next_scale
      }

      {:ok,
       %GlyphData{
         glyph: if(direction == @horizontal, do: new_glyph_for_h, else: glyph),
         new_line: is_newline,
         word_breaker: is_wordbreaker,
         prohibit_line_start: false,
         prohibit_line_end: false,
         box: if(direction == @horizontal, do: box_h, else: box_v),
         gap: if(direction == @horizontal, do: gap_h, else: gap_v),
         gap_when_newline: if(direction == @horizontal, do: gap_wn_h, else: gap_wn_v),
         coordinate: %Coordinate{}
       }}
    else
      {:error, _} = err -> err
    end
  end

  # newline単位/word単位でparseする
  # [i行目の行][jつ目の単語]

  # ※Thaqqa.Render.Sentenceに代行してもらう。
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

  defp set_position_and_wrapped(sentence, %Render{} = render_config, direction)
       when direction in [@vertical, @horizontal] do
    word_spacing = render_config.word_spacing
    letter_spacing = render_config.letter_spacing
    box_width = render_config.boundry.width
    box_height = render_config.boundry.height

    #
    # 通常強制改行時の判定
    # 強制改行された場合、「最初と最後のスペース」を削除する。
    # 強制改行の判定
    # defp is_start_initial_space(i, j, k), do: j != 0 && render_config.line_break == :normal

    # [行（仮）][単語][単語の何文字めか]　…なんだけど、行が変動するので行(仮)としている。
    sentence_alt =
      Enum.reduce(
        sentence,
        %{word_list: [], i: 0},
        fn oneline, %{word_list: acc_word_list, i: i} ->
          oneline_alt =
            Enum.reduce(
              oneline,
              %{word: [], left: 0, right: 0, top: 0, bottom: 0, i: 0, j: 0},
              fn word,
                 %{
                   word: acc_word,
                   left: acc_left,
                   right: acc_right,
                   top: acc_top,
                   bottom: acc_bottom,
                   i: i,
                   j: j
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
                      is_wrapped: false,
                      wrapped_letter_list: [],
                      # 文字数カウンタ用
                      k: 0
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
                         is_wrapped: is_wrapped,
                         wrapped_letter_list: wrapped_letter_list,
                         k: k
                       } ->
                      %{
                        word_breaker: is_wordbreaker,
                        box: %{top: top, bottom: bottom, left: left, right: right},
                        gap: %{
                          top: gap_top,
                          bottom: gap_bottom,
                          center: gap_center,
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
                      # というか、「何文字目で強制改行を挟むことになったか」を記録することにする
                      # (その方が中折れするタイプの改行設定にした場合に都合が良い)
                      cond_wrap =
                        if direction == @horizontal,
                          do: acc_right > box_width,
                          else: acc_bottom > box_height

                      is_wrapped = cond_wrap || is_wrapped

                      wrapped_letter_list =
                        if cond_wrap, do: [k | wrapped_letter_list], else: wrapped_letter_list

                      acc_x = next_x
                      acc_y = next_y

                      %{
                        glyph_list: [glyph_and_kern | acc_glyph],
                        left: acc_left,
                        x: acc_x,
                        right: acc_right,
                        top: acc_top,
                        y: acc_y,
                        bottom: acc_bottom,
                        is_wrapped: is_wrapped,
                        wrapped_letter_list: wrapped_letter_list,
                        k: k + 1
                      }
                    end
                  )

                %{
                  glyph_list: glyph_list,
                  left: left,
                  right: right,
                  top: top,
                  bottom: bottom,
                  is_wrapped: is_wrapped,
                  wrapped_letter_list: wrapped_letter_list
                } = word_alt

                # 中折れ系のときは
                # wrapped_letter_listを参照して
                # ボキッ！とword自体が折れる処理をする
                # (要するにそもそも同一単語扱いしない)
                acc_row = if is_wrapped, do: i + 1, else: i
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
                  i: i,
                  j: j + 1
                }
              end
            )

          %{word: word_list, i: i} = oneline_alt
          %{word_list: [word_list | acc_word_list] |> List.flatten(), i: i + 1}
        end
      )

    # row情報は要らないのでwordlist部分だけ返す
    sentence_alt.word_list
  end

  def alter_newline(word_list) do
    {sentence, _} =
      word_list
      |> Enum.reduce({[], 0}, fn %{
                                   glyph_list: glyph_list,
                                   top: top,
                                   bottom: bottom,
                                   left: left,
                                   right: right,
                                   row: row
                                 },
                                 {acc, acc_raw} ->
        {[
           %{
             glyph_list: glyph_list,
             top: top,
             bottom: bottom,
             left: left,
             right: right,
             is_newline: row != acc_raw
           }
           | acc
         ], row}
      end)

    sentence
    |> Enum.chunk_while(
      [],
      fn %{is_newline: is_newline} = word, acc_word ->
        cond do
          true ->
            if is_newline,
              do: {:cont, Enum.reverse([word | acc_word]), []},
              else: {:cont, [word | acc_word]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc_word -> {:cont, Enum.reverse(acc_word), []}
      end
    )
  end

  defp adjust_position_in_line(oneline, text_align, box_boundery, direction) do
    left = Enum.map(oneline, fn %{left: left} -> left end) |> Enum.min()
    right = Enum.map(oneline, fn %{right: right} -> right end) |> Enum.max()
    top = Enum.map(oneline, fn %{top: top} -> top end) |> Enum.min()
    bottom = Enum.map(oneline, fn %{bottom: bottom} -> bottom end) |> Enum.max()

    left_calc = -left
    right_calc = box_boundery.width - right
    top_calc = -top
    bottom_calc = box_boundery.height - bottom

    # ここらへんに邪魔なspaceをどかす処理も（将来的には）入れる
    # 「isSpace」＋「強制改行によるものか」の２軸で判定。
    # 強制改行だったらisSpace依存で一つ（または全部）削除。
    # 強制改行じゃないなら削除判定を～と

    word_num = length(oneline)

    {enum_num, enum_list} =
      Enum.map(oneline, fn word ->
        %{glyph_list: glyph_list} = word
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
    |> Enum.map(fn {%{glyph_list: glyph_list, left: left, top: top}, gap} ->
      {glyph_list, if(direction == @horizontal, do: left + gap, else: top + gap)}
    end)
    |> Enum.reduce(
      [],
      fn {glyph_list, gap}, acc_glyph_list ->
        glyph_list_alt =
          Enum.map(glyph_list, fn glyph_and_kern ->
            if direction == @horizontal do
              glyph_and_kern
              |> Map.put(:x, glyph_and_kern.x + gap)
              |> Map.put(:border, %{
                left: glyph_and_kern.border.left + gap,
                right: glyph_and_kern.border.right + gap
              })
            else
              glyph_and_kern
              |> Map.put(:y, glyph_and_kern.y + gap)
              |> Map.put(:border, %{
                top: glyph_and_kern.border.top + gap,
                bottom: glyph_and_kern.border.bottom + gap
              })
            end
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
    {sentence_alt, _, _} =
      Enum.reduce(
        sentence,
        {[], width, line_height},
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
              @vertical ->
                Enum.map(oneline, fn g -> Map.put(g, :x, acc_x - right) end)

              @horizontal ->
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

  defp render_all_for_vertical(glyph_list, %Bundle{} = prefab, direction) do
    if direction == @horizontal do
      glyph_list
    else
      Enum.map(glyph_list, fn glyph_and_kern ->
        %{glyph: glyph, gap_top: gap_top, gap_bottom: gap_bottom} = glyph_and_kern
        {:ok, glyph_new} = Glyph.render_by_relative_height(prefab, glyph, gap_top, gap_bottom)

        %{glyph_and_kern | glyph: glyph_new}
      end)
    end
  end

  defp adjust_position(sentence, %Render{} = render_config, direction) do
    adjust_position_along(sentence, render_config, direction)
    |> adjust_position_normal(render_config.boundry.width, render_config.line_height, direction)
  end

  defp set_position(sentence, %Render{} = render_config, direction) do
    word_list = set_position_and_wrapped(sentence, render_config, direction)
    alter_newline(word_list) |> adjust_position(render_config, direction)
  end

  def alignment_path_data(%Bundle{} = prefab, glyph_list, %Render{} = render, direction)
      when is_list(glyph_list) do
    none = Render.build_none()

    glyph_and_kern_list =
      [none | glyph_list ++ [none]]
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(&calc_kerning(&1, prefab, direction))

    Enum.reduce_while(glyph_and_kern_list, {:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, g_a_k_l} ->
        # px単位指定
        Enum.reverse(g_a_k_l)
        |> parse_word()
        |> set_position(render, direction)
        |> render_all_for_vertical(prefab, direction)
    end
  end
end
