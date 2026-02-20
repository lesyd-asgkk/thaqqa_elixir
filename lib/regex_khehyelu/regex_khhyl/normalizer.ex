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

  def normalize!(list) when is_list(list) do
    case normalize(list) do
      {:ok, val} -> val
      {:error, msg} -> raise msg
    end
  end

  def normalize(list) when is_list(list) do
    t = normalize_sub(list, [], :sentence)

    case t do
      {:error, _msg} -> t
      _ -> {:ok, t}
    end
  end

  def normalize_sub([], acum_all, _), do: Enum.reverse(acum_all)

  # 1層目
  def normalize_sub(list, acum_all, :sentence = current_layer) when is_list(list) do
    [head | tail] = list
    next_layer = :syllable

    case head do
      # S(*),S(form,*) のようなものも実装したい

      h when h in ["S", "V", "C", "Cd", "Vd", "P", "Pd", "L", "X", "R", "Sep", "Null"] ->
        normalize_branckets(:"#{h}", nil, acum_all, tail, next_layer, current_layer)

      # Rは別処理とする

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      h when h in @brancket_backward ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      h when h in ["^", "$", "*", "+", "?", "|", "*?", "+?", "??"] ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
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
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )
        end
    end
  end

  # 2層目
  def normalize_sub(list, acum_all, :syllable = current_layer) when is_list(list) do
    [head | tail] = list

    _next_layer = :glyph_group

    case head do
      # 形状指定用
      h when h in @form_list ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      "," ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
        )

      _ ->
        normalize_glyph_group(acum_all, list, [])
    end
  end

  # 3層目
  def normalize_sub(list, acum_all, :glyph_group = current_layer) when is_list(list) do
    [head | tail] = list

    next_layer = :glyph

    case head do
      # 形状指定用

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      h when h in @brancket_backward ->
        Error.unclosed_brancket_backward("#{Enum.join(list, "")}")

      "-" ->
        normalize_sub(
          tail,
          [AST.new(:finite, current_layer, head, head) | acum_all],
          current_layer
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
              current_layer,
              1
            )

          Regex.match?(~r/\{.*?}/, head) ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )

          true ->
            # next_layer。(:glyphの場合は未実装)
            normalize_sub(
              list,
              [AST.new(:glyph, current_layer, head, nil) | acum_all],
              next_layer
            )
        end
    end
  end

  # 4層目
  def normalize_sub(list, acum_all, :glyph = current_layer) when is_list(list) do
    [head | tail] = list

    # next_layer = :glyph_eval

    case head do
      # 形状指定用
      h when h in ["-+", "-*", "-?", "-+?", "-*?", "-??"] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer
        )

      h when h in ["*", "+", "?", "*?", "+?", "??", "_", "."] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head, head) | acum_all],
          current_layer
        )

      h when h in @brancket_forward ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

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
              current_layer,
              1
            )

          Regex.match?(~r/^\[.*?\]$/, head) ->
            script = String.slice(head, 1..-2//1)

            normalize_sub(
              tail,
              [AST.new(:script, current_layer, head, script) | acum_all],
              current_layer
            )

          # ↑のように閉じていない場合の処置。
          Regex.match?(~r/^\[.*$/, head) ->
            Error.unclosed_brancket_forward(head)

          true ->
            normalize_sub(
              tail,
              [AST.new(:finite, current_layer, head, head) | acum_all],
              current_layer
            )
        end
    end
  end

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         next_layer,
         current_layer,
         branket_nest \\ 0
       ),
       do:
         normalize_branckets(
           token,
           br_val,
           acum_all,
           list,
           next_layer,
           current_layer,
           branket_nest,
           []
         )

  defp normalize_branckets(
         token,
         br_val,
         _acum_all,
         [],
         _next_layer,
         _current_layer,
         _branket_nest,
         acum
       ),
       do:
         Error.unclosed_brancket_forward(
           "#{Atom.to_string(token)}(#{br_val} #{Enum.reverse(acum) |> Enum.join("")} )"
         )

  defp normalize_branckets(
         token,
         br_val,
         acum_all,
         list,
         next_layer,
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
          next_layer,
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
            children = normalize_sub(Enum.reverse(acum), [], next_layer)
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
            next_layer,
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
          next_layer,
          current_layer,
          branket_nest,
          [head | acum]
        )
    end
  end

  defp normalize_glyph_group(
         acum_all,
         [],
         acum
       ) do
    children = normalize_sub(Enum.reverse(acum), [], :glyph_group)
    text = Enum.reverse(acum) |> Enum.join("")

    normalize_sub(
      [],
      [AST.new(:glyph_group, :syllable, text, nil, children) | acum_all],
      :syllable
    )
  end

  defp normalize_glyph_group(acum_all, list, acum) when is_list(list) do
    [head | tail] = list

    case head do
      "," ->
        children = normalize_sub(Enum.reverse(acum), [], :glyph_group)
        text = Enum.reverse(acum) |> Enum.join("")

        normalize_sub(
          list,
          [AST.new(:glyph_group, :syllable, text, nil, children) | acum_all],
          :syllable
        )

      _ ->
        normalize_glyph_group(
          acum_all,
          tail,
          [head | acum]
        )
    end
  end
end
