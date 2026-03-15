defmodule Thaqqa.Regex_Khhyl.Normalizer do
  alias Thaqqa.Regex_Khhyl.AST, as: AST
  alias Thaqqa.Regex_Khhyl.Error, as: Error

  # 文章全体→Syllable(というか「一文字」)→Glyph群→Glyphの順に分解。
  # 括弧は同じ階層の別にnormalize対象として扱う
  # *などの記号は階層毎によって処理を変えている
  # 都合の悪い記号を吐いたり括弧が閉じてなかったらエラー
  # todo:{}系統のエラーを作る (括弧が閉じていない、中身が不正etc)
  # 純粋な記号ミス等はどのみちtranslator段階でエラーを吐くのでこの段階では訂正しない

  @brancket_forward ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"]
  @brancket_backward [")"]

  @form_list ["init", "mid", "fin", "sol", "onset", "coda", "null"]

  @letter_list ["S", "V", "C", "Cd", "Vd", "P", "Pd", "Lx", "L", "R", "Sep", "Null"]
  @style_list [
    "Size",
    "Color",
    "Offset",
    "Rotate",
    "Scale",
    "Skew",
    "Font",
    "StrokeWidth",
    "StrokeColor",
    "StyStyle"
  ]

  def normalize!(list) when is_list(list) do
    case normalize(list) do
      {:ok, val} -> val
      {:error, reason} -> raise reason
    end
  end

  def normalize(list) when is_list(list) do
    t = normalize_sub(list, [], :sentence, 0)

    case t do
      {:error, _reason} -> t
      _ -> {:ok, t}
    end
  end

  defp normalize_sub(list, acum_all, current_layer),
    do: normalize_sub(list, acum_all, current_layer, nil, 0)

  def normalize_sub([], acum_all, _, _letter_number, _count_argument), do: Enum.reverse(acum_all)
  # 1層目。sentence部分。
  def normalize_sub(list, acum_all, :sentence = current_layer, letter_number, _count_argument)
      when is_list(list) do
    [head | tail] = list
    next_layer = :syllable

    case head do
      h when h in @letter_list ->
        normalize_letter(:"#{h}", nil, acum_all, tail, letter_number)

      # Rは別処理とする

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, 1)

      h when h in @brancket_backward ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      h when h in ["^", "$", "*", "+", "?", "|", "*?", "+?", "??"] ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer,
          letter_number
        )

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer,
              letter_number
            )

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer,
              letter_number
            )
        end
    end
  end

  # 2層目。syllable部分。

  def normalize_sub(list, acum_all, :syllable = current_layer, letter_number, count_argument \\ 0)
      when is_list(list) do
    [head | tail] = list

    _next_layer = :glyph_group

    case head do
      # 形状指定用
      h when h in @form_list ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer,
          letter_number,
          count_argument
        )

      "," ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer,
          letter_number,
          count_argument + 1
        )

      _ ->
        normalize_glyph_group(acum_all, list, [], letter_number, count_argument)
    end
  end

  # 3層目。glyph_group部分。
  def normalize_sub(list, acum_all, :glyph_group = current_layer, letter_number, _count_argument)
      when is_list(list) do
    [head | tail] = list

    next_layer = :glyph

    case head do
      # 形状指定用

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, 1)

      h when h in @brancket_backward ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "-" ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer,
          letter_number
        )

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer,
              letter_number
            )

          true ->
            # next_layer。(:glyphの場合は未実装)
            normalize_sub(
              list,
              [AST.new(:glyph, current_layer, head, nil) | acum_all],
              next_layer,
              letter_number
            )
        end
    end
  end

  # 4層目。glpyh部分。
  def normalize_sub(list, acum_all, :glyph = current_layer, letter_number, _count_argument)
      when is_list(list) do
    [head | tail] = list

    # next_layer = :glyph_eval

    case head do
      # 形状指定用
      h when h in ["-+", "-*", "-?", "-+?", "-*?", "-??"] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer,
          letter_number
        )

      h when h in ["*", "+", "?", "*?", "+?", "??", "_", "."] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer,
          letter_number
        )

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, 1)

      h when h in @brancket_backward ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "]" ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      _ ->
        cond do
          Regex.match?(~r/^\(\?<.*?>/, head) ->
            name = String.slice(head, 1..-1//1)

            normalize_branckets(
              :brancket,
              :"#{name}",
              acum_all,
              tail,
              current_layer,
              1
            )

          Regex.match?(~r/^\[.*?\]$/, head) ->
            script = String.slice(head, 1..-2//1)

            normalize_sub(
              tail,
              [AST.new(:script, current_layer, head, script) | acum_all],
              current_layer,
              letter_number
            )

          # ↑のように閉じていない場合の処置。
          Regex.match?(~r/^\[.*$/, head) ->
            Error.unclosed_brancket_forward(head)

          Regex.match?(~r/[A-Za-z]+/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer,
              letter_number
            )

          Regex.match?(~r/[0-9]+/, head) ->
            %{"valid" => value} = Regex.named_captures(~r/(?<valid>[0-9]|[1-9][0-9]+)/, head)

            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, value) | acum_all],
              current_layer,
              letter_number
            )

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer,
              letter_number
            )
        end
    end
  end

  defp normalize_letter(
         token,
         br_val,
         acum_all,
         list,
         letter_number,
         branket_nest \\ 0
       ),
       do:
         normalize_letter(
           token,
           br_val,
           acum_all,
           list,
           letter_number,
           branket_nest,
           []
         )

  defp normalize_letter(
         token,
         br_val,
         _acum_all,
         [],
         _letter_number,
         _branket_nest,
         acum
       ),
       do:
         Error.unclosed_brancket_forward(
           "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"
         )

  defp normalize_letter(
         token,
         br_val,
         acum_all,
         list,
         letter_number,
         branket_nest,
         acum
       )
       when is_list(list) do
    [head | tail] = list

    case head do
      h when h in @brancket_forward ->
        acum = if branket_nest == 0, do: acum, else: [head | acum]

        normalize_letter(
          token,
          br_val,
          acum_all,
          tail,
          letter_number,
          branket_nest + 1,
          acum
        )

      h when h in @brancket_backward ->
        if branket_nest == 1 do
          letter_number_next = if is_nil(letter_number), do: nil, else: letter_number + 1

          if token == :R do
            text = Enum.reverse(acum) |> Enum.join("")

            normalize_sub(
              tail,
              [AST.new(token, :sentence, "R(#{text})", text, [], letter_number) | acum_all],
              :sentence,
              letter_number_next
            )
          else
            children = normalize_sub(Enum.reverse(acum), [], :syllable, letter_number)
            text = "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"
            # AST.new(:style_filler, current_layer, head,letter_number)
            # if tail == []　で分岐
            normalize_sub(
              tail,
              [AST.new(token, :sentence, text, br_val, children, letter_number) | acum_all],
              :sentence,
              letter_number_next
            )
          end
        else
          normalize_letter(
            token,
            br_val,
            acum_all,
            tail,
            letter_number,
            branket_nest - 1,
            [
              head | acum
            ]
          )
        end

      _ ->
        normalize_letter(
          token,
          br_val,
          acum_all,
          tail,
          letter_number,
          branket_nest,
          [head | acum]
        )
    end
  end

  # 括弧内の処理。
  # 通常の()を一度でも通った場合、attribute補完部分にキャプチャグループを割り当てない

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         current_layer,
         branket_nest \\ 0
       ),
       do:
         normalize_branckets(
           token,
           br_val,
           acum_all,
           list,
           current_layer,
           branket_nest,
           []
         )

  defp normalize_branckets(token, br_val, _a_a, [], _c_l, _b_n, acum),
    do:
      "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"
      |> Error.unclosed_brancket_forward()

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         current_layer,
         branket_nest,
         acum
       )
       when is_list(list) do
    [head | tail] = list

    case head do
      h when h in @brancket_forward ->
        acum = if branket_nest == 0, do: acum, else: [head | acum]

        normalize_branckets(
          token,
          br_val,
          acum_all,
          tail,
          current_layer,
          branket_nest + 1,
          acum
        )

      h when h in @brancket_backward ->
        if branket_nest == 1 do
          if token == :R do
            text = Enum.reverse(acum) |> Enum.join("")

            normalize_sub(
              tail,
              [AST.new(token, current_layer, "R(#{text})", text, []) | acum_all],
              current_layer
            )
          else
            children = normalize_sub(Enum.reverse(acum), [], current_layer)
            text = "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"

            normalize_sub(
              tail,
              [AST.new(token, current_layer, text, br_val, children) | acum_all],
              current_layer
            )
          end
        else
          normalize_branckets(
            token,
            br_val,
            acum_all,
            tail,
            current_layer,
            branket_nest - 1,
            [
              head | acum
            ]
          )
        end

      _ ->
        normalize_branckets(
          token,
          br_val,
          acum_all,
          tail,
          current_layer,
          branket_nest,
          [head | acum]
        )
    end
  end

  defp normalize_glyph_group(
         acum_all,
         [],
         acum,
         letter_number,
         count_argument
       ) do
    children = normalize_sub(Enum.reverse(acum), [], :glyph_group, letter_number)
    text = Enum.reverse(acum) |> Enum.join("")

    # attribute_filterを設置する
    acum_all = [AST.new(:glyph_group, :syllable, text, nil, children, letter_number) | acum_all]

    acum_all =
      case count_argument do
        0 ->
          acum_all

        1 ->
          [AST.new(:attribute_filler, :syllable, nil, {nil, letter_number}) | acum_all]

        3 ->
          [AST.new(:attribute_filler, :syllable, nil, {count_argument, letter_number}) | acum_all]
      end

    normalize_sub([], acum_all, :syllable, letter_number)
  end

  defp normalize_glyph_group(acum_all, list, acum, letter_number, count_argument)
       when is_list(list) do
    [head | tail] = list

    case head do
      "," ->
        children = normalize_sub(Enum.reverse(acum), [], :glyph_group, letter_number)
        text = Enum.reverse(acum) |> Enum.join("")
        # ~r/(?<attr通し番号>);(?[A-Za-z]||[0-9]|[.=-:])+?/
        # AST.new(:attribute_filler, current_layer, head,letter_number)\
        acum_all = [
          AST.new(:glyph_group, :syllable, text, nil, children, letter_number) | acum_all
        ]

        acum_all =
          if count_argument == 0,
            do: acum_all,
            else: [
              AST.new(:attribute_filler, :syllable, nil, {count_argument, letter_number})
              | acum_all
            ]

        normalize_sub(list, acum_all, :syllable, letter_number, count_argument)

      _ ->
        normalize_glyph_group(
          acum_all,
          tail,
          [head | acum],
          letter_number,
          count_argument
        )
    end
  end
end
