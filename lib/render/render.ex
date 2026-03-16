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
        line_break \\ :normal,
        text_align \\ :left,
        text_align_last \\ :left,
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

  defp build_none(font) do
    %Glyph{
      offset: %{x: 0, y: 0},
      aligment: %{x: 0, y: 0},
      path: %SVG.Path{},
      children_glyph_list: [],
      font: font,
      name: %{glyph: "", variant: nil, type: "None", form: nil},
      height: %{y0: 0, y1: 0, y2: 0, y3: 0}
    }
  end

  def calc_kerning_horizontal(
        [
          %Glyph{name: %{glyph: prev_glyph_name}} = prev_glyph,
          %Glyph{name: %{glyph: glyph_name}, path: path} = glyph,
          %Glyph{name: %{glyph: next_glyph_name}} = next_glyph
        ],
        %Prefab{} = prefab,
        fontname,
        %{is_width_relative: is_width_relative, width: width, gap_top: gap_top, height: height}
      ) do
    newline_as_regex_khhyl = "P([_.IsNewline]_-*)"
    start = System.monotonic_time()

    with {:ok, %{x0: x0_internal, y0: y0_internal, x1: x1_internal, y1: y1_internal}} <-
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
         {:ok, is_wordbreaker} <-
           ConstRegexManager.whole_of_string_match_at_once?(prefab, "WordBreaker", glyph_name),
         {:ok, new_glyph} <-
           Glyph.render_by_absolute_height(
             prefab,
             glyph,
             height * glyph.scale,
             (y1_internal + 0.5) * height * glyph.scale
           ) do
      is_wordbreaker = is_newline_raw === true
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

  # 縦ver
  def concat_path_data_as_vertical(%Prefab{} = prefab, glyph_list, %{font: fontname})
      when is_list(glyph_list) do
    none = build_none(fontname)

    kern_list =
      [none | glyph_list ++ [none]]
      |> Enum.chunk_every(3, 1, :discard)

    # |> Enum.map(&calc_kerning_vertical(&1, prefab, fontname, size))

    # あとはglyphの棒を挿したりするだけ
    # prefab
  end

  def concat_path_data_as_horizontal(%Prefab{} = prefab, glyph_list) do
  end

  defp set_position_y(glyph_list) do
    {glyph_list, _} =
      Enum.chunk_while(
        glyph_list,
        [],
        fn glyph, acc ->
          if glyph.internal_attribution.is_newline do
            {:cont, Enum.reverse([glyph | acc]), []}
          else
            {:cont, [glyph | acc]}
          end
        end,
        fn
          [] -> {:cont, []}
          acc -> {:cont, Enum.reverse(acc), []}
        end
      )
      |> Enum.reduce({[], 0}, fn g_list, {acc, acc_y} ->
        {max_height, max_gap_top} =
          Enum.reduce(g_list, {0, 0}, fn g, {acc_height, acc_gap_top} ->
            glyph_height = g.internal_attribution.height
            {max(acc_height, glyph_height), max(acc_gap_top, g.internal_attribution.gap_top)}
          end)

        g_alt =
          Enum.map(g_list, fn g ->
            top_gap = max_height - g.internal_attribution.height

            internal_attribution =
              Map.put(g.internal_attribution, :y, acc_y + max_gap_top + top_gap)

            # %Glyph{g | internal_attribution: internal_attribution}
            {internal_attribution.x, internal_attribution.y, g.name.glyph}
          end)

        {[g_alt | acc], acc_y + max_height + max_gap_top}
      end)

    Enum.reverse(glyph_list)
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
              |> Map.put(:x, glyph_x)
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

  def alignment_path_data_as_horizontal(%Prefab{} = prefab, glyph_list, %{
        font: fontname,
        wrap: wrap
      })
      when is_list(glyph_list) do
    with {:data, %Data{} = data} <-
           {:data, Prefab.get_single_data(prefab, fontname, "FONTDATA")},
         {:is_width_relative, is_width_relative} when is_boolean(is_width_relative) <-
           {:is_width_relative, Data.get_val(data, "isWidthHRel")},
         {:width, width} when is_number(width) <- {:width, Data.get_val(data, "WidthV")},
         {:gap_top, gap_top} when is_number(gap_top) <- {:gap_top, Data.get_val(data, "TopGapH")},
         {:height, height} when is_number(height) <- {:height, Data.get_val(data, "Height")} do
      none = build_none(fontname)

      temp_struct_for_argument = %{
        is_width_relative: is_width_relative,
        width: width,
        gap_top: gap_top,
        height: height
      }

      {:ok, glyph_and_kern_list} =
        [none | glyph_list ++ [none]]
        |> Enum.chunk_every(3, 1, :discard)
        |> Enum.map(&calc_kerning_horizontal(&1, prefab, fontname, temp_struct_for_argument))
        |> set_position_and_flag()

      set_position_y(glyph_and_kern_list)
      # あとはglyphの棒を挿したりするだけ
      # prefab
    else
      {:data, nil} -> {:error, "（仮）Data not found in FONTDATA"}
      {:height, nil} -> {:error, "（仮）Height not found in FONTDATA"}
      {:is_width_relative, nil} -> {:error, "（仮）isWidthHRel not found in FONTDATA"}
      {:width, nil} -> {:error, "（仮）WidthV not found in FONTDATA"}
      {:gap_top, nil} -> {:error, "（仮）TopGapH not found in FONTDATA"}
    end
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
      {:ok, {:ok, str}}, {:ok, acc} ->
        {:cont, {:ok, [str | acc]}}

      {:ok, {:error, _} = err}, _acc ->
        {:halt, err}

      {:exit, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      {:error, _} = err -> err
    end
  end

  def build_path_data(%Prefab{} = prefab, syllable_list, font, writing_direction, default_scale)
      when is_list(syllable_list) do
    Enum.reduce_while(syllable_list, {:ok, []}, fn syl, {:ok, acc} ->
      with {:ok, glyph} <- Glyph.new(prefab, font, syl, writing_direction, default_scale) do
        # 現状set_pathにエラーを吐く要因はないが
        # 今後エラー処理が必要になった場合を鑑みてwith文とする
        {:cont, {:ok, [Glyph.set_path(glyph) | acc]}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      {:ok, glyph_list} -> Enum.reverse(glyph_list)
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
              {:halt,
               {:error, "unparsed pattern found (it might be internal error occured): #{syl}"}}

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
        regex = const |> Thaqqa.Data.get_val(@precompile)

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
end
