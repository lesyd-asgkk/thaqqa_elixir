defmodule Thaqqa.RenderVertical do
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

  defp calc_kerning_vertical(
         [
           %Glyph{name: %{glyph: prev_glyph_name}} = prev_glyph,
           %Glyph{name: %{glyph: glyph_name}, font: fontname, path: path} = glyph,
           %Glyph{name: %{glyph: next_glyph_name}} = next_glyph
         ],
         %Prefab{} = prefab
       ) do
    newline_as_regex_khhyl = "P([_.IsNewline]_-*)"

    with {:ok, %{isWidthVRel: is_width_relative, WidthV: width, TopGapH: gap_top, Height: height}} <-
           Prefab.get_fontdata(prefab, fontname, ["isWidthVRel", "WidthV", "TopGapH", "Height"]),
         {:ok, %{x0: x0_internal, y0: y0_internal, x1: x1_internal, y1: y1_internal}} <-
           GposManager.gpos(prefab, fontname, glyph_name, @vertical, @internal),
         {:ok, %{x0: x0_ex_prev, y0: y0_ex_prev, x1: x1_ex_prev, y1: y1_ex_prev}} <-
           GposManager.gpos(
             prefab,
             fontname,
             prev_glyph_name <> glyph_name,
             @vertical,
             @external
           ),
         {:ok, %{x0: x0_ex_next, y0: y0_ex_next, x1: x1_ex_next, y1: y1_ex_next}} <-
           GposManager.gpos(
             prefab,
             fontname,
             glyph_name <> next_glyph_name,
             @vertical,
             @external
           ),
         GposManager.gpos(prefab, fontname, glyph_name, @vertical, @internal),
         {:ok, %{x0: x0_ex_prev_nl, y0: y0_ex_prev_nl, x1: x1_ex_prev_nl, y1: y1_ex_prev_nl}} <-
           GposManager.gpos(
             prefab,
             fontname,
             newline_as_regex_khhyl <> glyph_name,
             @vertical,
             @external
           ),
         {:ok, %{x0: x0_ex_next_nl, y0: y0_ex_next_nl, x1: x1_ex_next_nl, y1: y1_ex_next_nl}} <-
           GposManager.gpos(
             prefab,
             fontname,
             glyph_name <> newline_as_regex_khhyl,
             @vertical,
             @external
           ),
         {:ok, is_newline_raw} <-
           ConstRegexManager.whole_of_string_match_at_once?(prefab, "Newline", glyph_name),
         {:ok, is_wordbreaker_raw} <-
           ConstRegexManager.whole_of_string_match_at_once?(prefab, "WordBreaker", glyph_name),
         {:ok, glyph_for_meassure} <-
           Glyph.render_by_relative_height(prefab, glyph, 0, 0) do
      is_wordbreaker = is_wordbreaker_raw === true
      is_newline = is_newline_raw === true

      scale = glyph.scale
      prev_scale = prev_glyph.scale || glyph.scale
      next_scale = next_glyph.scale || glyph.scale

      %{top: t, bottom: b, left: l, right: r} = SVG.Path.get_border(glyph_for_meassure.path)

      {:ok,
       %{
         glyph: glyph,
         new_line: is_newline,
         word_breaker: is_wordbreaker,
         prohibit_line_start: false,
         prohibit_line_end: false,
         box: %{
           top: t,
           bottom: b,
           left: if(is_width_relative, do: -l + width / 2 * scale, else: width / 2 * scale),
           right: if(is_width_relative, do: r + width / 2 * scale, else: width / 2 * scale)
         },
         gap: %{
           top: y0_internal * scale + y1_ex_prev * prev_scale,
           left: 0,
           right: 0,
           bottom: y1_internal * scale + y0_ex_next * next_scale
         },
         gap_when_newline: %{
           top: y0_internal * scale + y1_ex_prev_nl * prev_scale,
           left: 0,
           right: 0,
           bottom: y1_internal * scale + y0_ex_next_nl * next_scale
         }
       }}
    else
      {:error, _} = err -> err
    end
  end

  def concat_path_data_as_vertical(glyph_list) when is_list(glyph_list) do
    Enum.map(glyph_list, fn glyph_and_kern ->
      %{x: x, y: y, glyph: %Glyph{offset: %{x: off_x, y: off_y}, path: path}} = glyph_and_kern
      SVG.Path.set_start_position(path, x + off_x, y + off_y) |> SVG.Path.export_as_string_mass!()
    end)
    |> Enum.join("")
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

  ###################################
  ## 以降はvertical用のチューニングがまだ
  ###################################

  defp set_position_and_wrapped(sentence, %Render{} = render_config) do
    word_spacing = render_config.word_spacing
    letter_spacing = render_config.letter_spacing
    box_height = render_config.boundry.height
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
              fn word, {acc_word, acc_top, acc_bottom, acc_row} ->
                acc_top_start = acc_top
                acc_bottom_start = acc_bottom

                word_alt =
                  Enum.reduce(
                    word,
                    {[], acc_bottom_start, acc_bottom_start, acc_bottom_start, false},
                    fn glyph_and_kern, {acc_glyph, acc_top, acc_y, acc_bottom, is_wrapped} ->
                      %{
                        glyph: glyph,
                        new_line: is_newline,
                        word_breaker: is_wordbreaker,
                        box: %{top: top, bottom: bottom, left: left, right: right},
                        gap: %{
                          top: gap_top,
                          bottom: gap_bottom
                        },
                        gap_when_newline: %{
                          top: gap_top_nl,
                          bottom: gap_bottom_nl
                        }
                      } = glyph_and_kern

                      blank_space =
                        if is_wordbreaker,
                          do: word_spacing + letter_spacing,
                          else: letter_spacing

                      # IO.inspect({gap_top, top, gap_bottom, bottom})
                      glyph_y = acc_y + gap_top - top + blank_space / 2

                      next_y = acc_y + gap_top - top + gap_bottom + bottom + blank_space

                      # スタート位置からの相対座標に換算
                      glyph_and_kern =
                        glyph_and_kern
                        |> Map.put(:y, glyph_y - acc_bottom_start)
                        |> Map.put(:gap_top, gap_top + blank_space / 2)
                        |> Map.put(:gap_bottom, gap_bottom + blank_space / 2)
                        |> Map.put(:border, %{
                          top: acc_y - acc_bottom_start,
                          bottom: next_y - acc_bottom_start
                        })

                      acc_top = min(acc_top, acc_y)
                      acc_bottom = max(acc_bottom, next_y)

                      # 改行処理部分。一回でも改行処理判定に引っかかったら以降はtrueになる
                      # TODO：,といった約物を改行判定から無視する
                      # ※is_wrappedの初期値はfalseなのでこれで一回でもtrueになったかは判定できる
                      cond_wrap = acc_bottom > box_height
                      is_wrapped = cond_wrap || is_wrapped

                      acc_y = next_y
                      {[glyph_and_kern | acc_glyph], acc_top, acc_y, acc_bottom, is_wrapped}
                    end
                  )

                {glyph_list, top, _, bottom, is_wrapped} = word_alt
                acc_row = if is_wrapped, do: acc_row + 1, else: acc_row
                acc_top = if is_wrapped, do: top - acc_bottom, else: top
                acc_bottom = if is_wrapped, do: bottom - acc_bottom, else: bottom

                word = {Enum.reverse(glyph_list), acc_top, acc_bottom, acc_row}
                {[word | acc_word], acc_top, acc_bottom, acc_row}
              end
            )

          {word_list, _, _, acc_row} = oneline_alt
          {[word_list | acc_word_list] |> List.flatten(), acc_row + 1}
        end
      )

    sentence_alt
  end

  defp adjust_position_in_line(oneline, text_align, box_height) do
    word_num = length(oneline)

    top = Enum.map(oneline, fn {_, top, _, _} -> top end) |> Enum.min()
    bottom = Enum.map(oneline, fn {_, _, bottom, _} -> bottom end) |> Enum.max()

    top_calc = -top
    bottom_calc = box_height - bottom

    gap_list =
      case text_align do
        :start ->
          List.duplicate(top_calc, word_num)

        :left ->
          List.duplicate(top_calc, word_num)

        :end ->
          List.duplicate(bottom_calc, word_num)

        :right ->
          List.duplicate(bottom_calc, word_num)

        :center ->
          List.duplicate((top_calc + bottom_calc) / 2, word_num)

        :justify ->
          case word_num do
            0 ->
              []

            1 ->
              [top_calc]

            _ ->
              gap = (top_calc + bottom_calc) / (word_num - 1)

              Enum.map(0..(word_num - 1), fn n ->
                top_calc + gap * n
              end)
          end
      end

    oneline_alt =
      Enum.zip(oneline, gap_list)
      |> Enum.map(fn {{word_list, top, _, _}, gap} ->
        {word_list, top + gap}
      end)
      |> Enum.reduce(
        [],
        fn {glyph_list, gap_from_top}, acc_glyph_list ->
          glyph_list_alt =
            Enum.map(glyph_list, fn glyph_and_kern ->
              glyph_and_kern
              |> Map.put(:y, glyph_and_kern.y + gap_from_top)
              |> Map.put(:border, %{
                top: glyph_and_kern.border.top + gap_from_top,
                bottom: glyph_and_kern.border.bottom + gap_from_top
              })
            end)

          [glyph_list_alt | acc_glyph_list] |> List.flatten()
        end
      )
  end

  defp adjust_position_y(sentence, %Render{} = render_config) do
    box_height = render_config.boundry.height
    text_align = render_config.text_align
    text_align_last = render_config.text_align_last
    [last_line | rest_line] = Enum.reverse(sentence)

    #
    Enum.reduce(
      rest_line,
      [adjust_position_in_line(last_line, text_align_last, box_height)],
      fn oneline, acc_oneline_list ->
        oneline_alt = adjust_position_in_line(oneline, text_align, box_height)
        [oneline_alt | acc_oneline_list]
      end
    )
  end

  defp adjust_position_x(sentence) do
    {sentence_alt, _} =
      Enum.reduce(
        sentence,
        {[], 0},
        fn oneline, {acc_oneline_list, acc_x} ->
          {left, right} =
            Enum.reduce(oneline, {0, 0}, fn g, {acc_left, acc_right} ->
              {max(acc_left, g.box.left), max(acc_right, g.box.right)}
            end)

          oneline_alt = Enum.map(oneline, fn g -> Map.put(g, :x, acc_x + left) end)

          Enum.reverse(oneline_alt)

          {[oneline_alt | acc_oneline_list] |> List.flatten(), acc_x + left + right}
        end
      )

    sentence_alt
  end

  defp adjust_position(sentence, %Render{} = render_config) do
    adjust_position_y(sentence, render_config) |> adjust_position_x()
  end

  defp alter_newline(word_list) do
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

  defp set_position(sentence, %Render{} = render_config) do
    {word_list, _} = set_position_and_wrapped(sentence, render_config)
    alter_newline(word_list) |> adjust_position(render_config)
  end

  defp render_all(glyph_list, %Prefab{} = prefab) do
    Enum.map(glyph_list, fn glyph_and_kern ->
      %{glyph: glyph, gap: gap} = glyph_and_kern
      {:ok, glyph_new} = Glyph.render_by_relative_height(prefab, glyph, gap.top, gap.bottom)

      %{glyph_and_kern | glyph: glyph_new}
    end)
  end

  def alignment_path_data_as_vertical(%Prefab{} = prefab, glyph_list, %Render{} = render)
      when is_list(glyph_list) do
    none = build_none()

    glyph_and_kern_list =
      [none | glyph_list ++ [none]]
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(&calc_kerning_vertical(&1, prefab))

    Enum.reduce_while(glyph_and_kern_list, {:ok, []}, fn
      {:ok, str}, {:ok, acc} -> {:cont, {:ok, [str | acc]}}
      {:error, _} = err, _acc -> {:halt, err}
    end)
    |> case do
      {:error, _} = err ->
        err

      {:ok, g_a_k_l} ->
        g_a_k_l
        # px単位指定
        Enum.reverse(g_a_k_l) |> parse_word() |> set_position(render) |> render_all(prefab)
    end
  end
end

# デバッグ用関数
#  sentence
#  |> Enum.map(fn oneline ->
#    Enum.map(oneline, fn word ->
#      Enum.map(word, fn glyph_list ->
#        glyph_list.glyph.name.glyph
#      end)
#    end)
#  end)
#  |> IO.inspect()
