# 処理で共通に出来るところを共通化していくぞ～ついでに見やすくする
defmodule Thaqqa.RenderLayout do
  alias Thaqqa.Bundle, as: Bundle

  alias Thaqqa.Render, as: Render
  alias Thaqqa.Glyph, as: Glyph
  alias Thaqqa.Bundle.GposTable, as: GposTable
  alias Thaqqa.Bundle.ConstRegexKhhylTable, as: ConstRegexKhhylTable

  alias Thaqqa.Render.Box, as: Box
  alias Thaqqa.Render.GlyphData, as: GlyphData
  alias Thaqqa.Render.Word, as: Word
  alias Thaqqa.Render.Oneline, as: Oneline
  alias Thaqqa.Render.Sentence, as: Sentence
  alias Thaqqa.Render.Coordinate, as: Coordinate

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

  defp set_position_and_wrapped(%Sentence{} = sentence, %Render{} = render_config, direction)
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

    # ※便宜上、Sentence内部のoneline_list[0]に全部ぶち込むこととした。

    %{sentence: sentence_alt} =
      Enum.reduce(
        sentence.oneline_list,
        %{sentence: %Sentence{oneline_list: [%Oneline{word_list: []}]}, i: 0},
        fn oneline,
           %{sentence: %Sentence{oneline_list: [%Oneline{word_list: acc_word_list}]}, i: i} ->
          oneline_alt =
            Enum.reduce(
              oneline.word_list,
              %{word: [], box: %Box{left: 0, right: 0, top: 0, bottom: 0}, i: i, j: 0},
              fn word,
                 %{
                   word: acc_word,
                   box: %Box{left: acc_left, right: acc_right, top: acc_top, bottom: acc_bottom},
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
                    word.glyph_list,
                    %{
                      word: %Word{glyph_list: []},
                      box: %Box{
                        left: acc_right_start,
                        right: acc_right_start,
                        top: acc_bottom_start,
                        bottom: acc_bottom_start
                      },
                      coordinate: %Coordinate{x: acc_right_start, y: acc_bottom_start},
                      is_wrapped: false,
                      wrapped_letter_list: [],
                      # 文字数カウンタ用
                      k: 0
                    },
                    fn glyph,
                       %{
                         word: %Word{glyph_list: acc_glyph} = acc_word,
                         box: %Box{
                           left: acc_left,
                           right: acc_right,
                           top: acc_top,
                           bottom: acc_bottom
                         },
                         coordinate: %Coordinate{x: acc_x, y: acc_y},
                         is_wrapped: is_wrapped,
                         wrapped_letter_list: wrapped_letter_list,
                         k: k
                       } ->
                      %GlyphData{
                        word_breaker: is_wordbreaker,
                        box: %Box{top: top, bottom: bottom, left: left, right: right} = box,
                        gap: %Box{} = gap,
                        gap_when_newline: %Box{} = gap_with_newline
                      } = glyph

                      %Box{top: gap_top, bottom: gap_bottom, left: gap_left, right: gap_right} =
                        gap

                      blank_space =
                        if is_wordbreaker,
                          do: word_spacing + letter_spacing,
                          else: letter_spacing

                      # ※どの道もう片方の情報は以降で使わないのでcoordinate,boxで代用していい。
                      glyph_x = acc_x + gap_left + left + blank_space / 2
                      glyph_y = acc_y - top + blank_space / 2

                      next_x = acc_x + gap_left + left + gap_right + right + blank_space
                      next_y = acc_y + gap_top - top + gap_bottom + bottom + blank_space
                      # スタート位置からの相対座標に換算
                      gap_top_actual =
                        if direction == @horizontal, do: gap_top, else: +gap_top + blank_space / 2

                      # ↓は相対座標で保持
                      # todo:絶対座標に変換

                      box_v = %Box{
                        left: left,
                        right: right,
                        top: acc_y - acc_bottom_start,
                        bottom: next_y - acc_bottom_start
                      }

                      box_h = %Box{
                        left: acc_x - acc_right_start,
                        right: next_x - acc_right_start,
                        top: top,
                        bottom: bottom
                      }

                      glyph =
                        %GlyphData{
                          glyph
                          | coordinate: %Coordinate{
                              x: glyph_x - acc_right_start,
                              y: glyph_y - acc_bottom_start
                            },
                            box: if(direction == @horizontal, do: box_h, else: box_v),
                            gap_top: gap_top_actual,
                            gap_bottom: gap_bottom + blank_space / 2,
                            height: bottom
                        }

                      # |> Map.put(:gap_top, gap_top_actual)
                      #  |> Map.put(:gap_bottom, gap_bottom + blank_space / 2)

                      # |> Map.put(:height, bottom)

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
                        word: %Word{acc_word | glyph_list: [glyph | acc_glyph]},
                        box: %Box{
                          left: acc_left,
                          right: acc_right,
                          top: acc_top,
                          bottom: acc_bottom
                        },
                        coordinate: %Coordinate{x: acc_x, y: acc_y},
                        is_wrapped: is_wrapped,
                        wrapped_letter_list: wrapped_letter_list,
                        k: k + 1
                      }
                    end
                  )

                %{
                  word: %Word{glyph_list: glyph_list},
                  box: %Box{left: left, right: right, top: top, bottom: bottom},
                  is_wrapped: is_wrapped,
                  wrapped_letter_list: wrapped_letter_list
                } = word_alt

                # 条件依存で改行する為に一応用意
                #  boundaries = [0 | wrapped_letter_list] ++ [length(list)]

                #  boundaries
                #  |> Enum.chunk_every(2, 1, :discard)
                #  |> Enum.map(fn [start, finish] ->
                #    Enum.slice(list, start, finish - start)
                #  end)

                # 中折れ系のときは
                # wrapped_letter_listを参照して
                # ボキッ！とword自体が折れる処理をする
                # (要するにそもそも同一単語扱いしない)
                # 要は改行するときは「最初の文字の位置」へと補正している
                # （改行処理は後でやるので）

                # leftとかそういう奴もWordじゃなくてGlyphの方で判定
                acc_row = if is_wrapped, do: i + 1, else: i
                acc_left = if is_wrapped, do: left - acc_right, else: left
                acc_right = if is_wrapped, do: right - acc_right, else: right
                acc_top = if is_wrapped, do: top - acc_bottom, else: top
                acc_bottom = if is_wrapped, do: bottom - acc_bottom, else: bottom
                acc_box = %Box{left: acc_left, right: acc_right, top: acc_top, bottom: acc_bottom}

                word = %Word{
                  glyph_list: Enum.reverse(glyph_list),
                  box: acc_box,
                  row: acc_row
                }

                %{
                  word: [word | acc_word],
                  box: %Box{left: acc_left, right: acc_right, top: acc_top, bottom: acc_bottom},
                  i: i,
                  j: j + 1
                }
              end
            )

          # %{sentence: %Sentence{oneline_list: [%Oneline{word_list: []}]}, i: 0}
          %{word: word_list, i: i} = oneline_alt

          %{
            sentence: %Sentence{
              oneline_list: [%Oneline{word_list: [word_list | acc_word_list] |> List.flatten()}]
            },
            i: i + 1
          }
        end
      )

    # row情報は要らないのでwordlist部分だけ返す
    sentence_alt
  end

  def alter_newline(%Sentence{oneline_list: [%Oneline{word_list: word_list}]} = sentence_alt) do
    {word_list, _} =
      word_list
      |> Enum.reduce({[], 0}, fn %Word{row: row} = word, {acc, acc_raw} ->
        {[%{word: word, is_newline: row != acc_raw} | acc], row}
      end)

    oneline_list =
      word_list
      |> Enum.chunk_while(
        [],
        fn %{word: word, is_newline: is_newline}, acc_word ->
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
      |> Enum.map(fn wordlist_oneliner -> %Oneline{word_list: wordlist_oneliner} end)

    %Sentence{oneline_list: oneline_list}
  end

  defp adjust_position_in_line(
         %Oneline{word_list: word_list} = oneline,
         text_align,
         box_boundery,
         direction
       ) do
    left = Enum.map(word_list, fn %{box: %Box{left: left}} -> left end) |> Enum.min()
    right = Enum.map(word_list, fn %{box: %Box{right: right}} -> right end) |> Enum.max()
    top = Enum.map(word_list, fn %{box: %Box{top: top}} -> top end) |> Enum.min()
    bottom = Enum.map(word_list, fn %{box: %Box{bottom: bottom}} -> bottom end) |> Enum.max()

    left_calc = -left
    right_calc = box_boundery.width - right
    top_calc = -top
    bottom_calc = box_boundery.height - bottom

    # ここらへんに邪魔なspaceをどかす処理も（将来的には）入れる
    # 「isSpace」＋「強制改行によるものか」の２軸で判定。
    # 強制改行だったらisSpace依存で一つ（または全部）削除。
    # 強制改行じゃないなら削除判定を～と

    word_num = length(word_list)

    {enum_num, enum_list} =
      Enum.map(word_list, fn word ->
        %Word{glyph_list: glyph_list} = word
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

    word_list_alt =
      Enum.zip(oneline.word_list, gap_list)
      |> Enum.map(fn {%Word{box: %Box{left: left, top: top}} = word, gap} ->
        {word, if(direction == @horizontal, do: left + gap, else: top + gap)}
      end)
      |> Enum.reduce(
        [],
        fn {word, gap}, acc_word_list ->
          glyph_list_alt =
            Enum.map(word.glyph_list, fn %GlyphData{} = glyphdata ->
              if direction == @horizontal do
                %GlyphData{
                  glyphdata
                  | coordinate: %Coordinate{
                      glyphdata.coordinate
                      | x: glyphdata.coordinate.x + gap
                    },
                    box: %Box{
                      glyphdata.box
                      | left: glyphdata.box.left + gap,
                        right: glyphdata.box.right + gap
                    }
                }
              else
                %GlyphData{
                  glyphdata
                  | coordinate: %Coordinate{
                      glyphdata.coordinate
                      | y: glyphdata.coordinate.y + gap
                    },
                    box: %Box{
                      glyphdata.box
                      | top: glyphdata.box.top + gap,
                        bottom: glyphdata.box.bottom + gap
                    }
                }
              end
            end)

          [%Word{word | glyph_list: glyph_list_alt} | acc_word_list]
        end
      )

    %Oneline{oneline | word_list: word_list_alt}
  end

  defp adjust_position_along(
         %Sentence{oneline_list: oneline_list} = sentence,
         %Render{} = render_config,
         direction
       ) do
    box_boundry = render_config.boundry
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last
    [%Oneline{} = last_line | rest_line] = Enum.reverse(oneline_list)

    #
    oneline_list_alt =
      Enum.reduce(
        rest_line,
        [adjust_position_in_line(last_line, text_align_last, box_boundry, direction)],
        fn %Oneline{} = oneline, acc_oneline_list ->
          oneline_alt = adjust_position_in_line(oneline, text_align, box_boundry, direction)
          [oneline_alt | acc_oneline_list]
        end
      )

    %Sentence{sentence | oneline_list: oneline_list_alt}
  end

  defp adjust_position_normal(
         %Sentence{oneline_list: oneline_list} = sentence,
         width,
         line_height,
         direction
       ) do
    {oneline_list_alt, _, _} =
      Enum.reduce(
        oneline_list,
        {[], width, line_height},
        fn %Oneline{} = oneline, {acc_glyph_list_alt, acc_x, acc_y} ->
          glyph_list =
            Enum.reduce(oneline.word_list, [], fn %Word{glyph_list: glyph_list}, acc_glyph_list ->
              IO.inspect(glyph_list |> length())
              glyph_list ++ acc_glyph_list
            end)

          [glyph_list_first | glyph_list_rest] = glyph_list

          {max_height, max_gap_top} =
            Enum.reduce(
              glyph_list_rest,
              {glyph_list_first.height, glyph_list_first.gap_top},
              fn %GlyphData{} = g, {acc_height, acc_gap_top} ->
                # IO.inspect(g.glyph.name.glyph)
                # IO.inspect(g.box)
                {max(acc_height, g.height), max(acc_gap_top, g.gap_top)}
              end
            )

          {left, right} =
            Enum.reduce(
              glyph_list_rest,
              {glyph_list_first.box.left, glyph_list_first.box.right},
              fn %GlyphData{} = g, {acc_left, acc_right} ->
                {max(acc_left, g.box.left), max(acc_right, g.box.right)}
              end
            )

          row_width = right + left
          IO.inspect(row_width)

          glyph_list_alt =
            case direction do
              @vertical ->
                Enum.map(glyph_list, fn %GlyphData{} = g ->
                  %GlyphData{
                    g
                    | coordinate: %Coordinate{g.coordinate | x: acc_x - line_height / 2 - right}
                  }
                end)

              @horizontal ->
                Enum.map(glyph_list, fn %GlyphData{} = g ->
                  top_gap = max_height - g.height

                  %GlyphData{
                    g
                    | coordinate: %Coordinate{g.coordinate | y: acc_y + max_gap_top + top_gap}
                  }
                end)
            end

          Enum.reverse(glyph_list_alt)
          #

          {[glyph_list_alt | acc_glyph_list_alt] |> List.flatten(),
           acc_x - row_width - line_height, acc_y + max_height + max_gap_top + line_height}
        end
      )

    oneline_list_alt
  end

  defp render_all(glyph_list, %Bundle{} = prefab, direction) do
    if direction == @horizontal do
      glyph_list
    else
      Enum.map(glyph_list, fn %GlyphData{} = glyphdata ->
        %GlyphData{glyph: glyph, gap_top: gap_top, gap_bottom: gap_bottom} = glyphdata
        {:ok, glyph_new} = Glyph.render_by_relative_height(prefab, glyph, gap_top, gap_bottom)

        %GlyphData{glyphdata | glyph: glyph_new}
      end)
    end
  end

  defp adjust_position(%Sentence{} = sentence, %Render{} = render_config, direction) do
    adjust_position_along(sentence, render_config, direction)
    |> adjust_position_normal(render_config.boundry.width, render_config.line_height, direction)
  end

  defp set_position(%Sentence{} = sentence, %Render{} = render_config, direction) do
    sentence_alt = set_position_and_wrapped(sentence, render_config, direction)
    alter_newline(sentence_alt) |> adjust_position(render_config, direction)
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
        |> Sentence.parse_sentence()
        |> set_position(render, direction)
        |> render_all(prefab, direction)
    end
  end
end
