defmodule Thaqqa.Regex_Khhyl.AST do
  defstruct type: nil, value: nil, layer: nil, children: []

  def new(type, layer, value \\ nil, children \\ []) do
    %__MODULE__{type: type, value: value, layer: layer, children: children}
  end

  def has_astarisk_for_form?(%__MODULE__{value: val, children: children}) do
    if children == [], do: val == "*", else: Enum.any?(children, &has_astarisk_for_form?/1)
  end
end

defmodule Thaqqa.Regex_Khhyl do
  alias Thaqqa.Regex_Khhyl.AST, as: AST

  def convert(string) when is_binary(string) do
    string
    |> tokenize()
    |> normalize()
    |> translate()
  end

  def translate(ast) when is_list(ast), do: Enum.map_join(ast, "", &translate_sub/1)

  def translate(%AST{} = ast), do: translate_sub(ast)

  def translate_sub(%AST{type: :finite, value: val}), do: val

  def translate_sub(%AST{type: :brancket, value: val, children: children}),
    do: "(" <> val <> Enum.map_join(children, "", &translate_sub/1) <> ")"

  def translate_sub(%AST{type: :script, value: val}),
    # 暫定的な処置。todo:scriptパーサ (テーブル実装後になります)
    do: "[" <> val <> "]"

  # S(*), C(*)のようなvariantをこっちで実装する。
  # *を取り出す方法……？

  def translate_sub(%AST{type: :S, children: children} = ast) when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("S((?:init|mid|fin|sol|null),*,*,*)")
    else
      raise "S() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: :S, children: children}) when length(children) == 3 do
    if AST.has_astarisk_for_form?(Enum.at(children, 2)) do
      tail = [Enum.at(children, 1), Enum.at(children, 2)]

      translate_sub(%AST{
        type: :S,
        children: children ++ tail ++ tail
      })
    else
      raise "S() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: :V, children: children} = ast) when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("V((?:init|mid|fin|sol|null),*)")
    else
      raise "V() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: :Vd, children: children} = ast) when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("Vd((?:init|mid|fin|sol|null),*)")
    else
      raise "Vd() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: :C, children: children} = ast) when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("C((?:onset|coda|null),*)")
    else
      raise "C() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: :Cd, children: children} = ast) when length(children) == 1 do
    if AST.has_astarisk_for_form?(ast) do
      convert("Cd((?:onset|coda|null),*)")
    else
      raise "Cd() with no variant '*' is not supported."
    end
  end

  def translate_sub(%AST{type: t, children: children})
      when t in [:S, :V, :Vd] do
    if AST.has_astarisk_for_form?(Enum.at(children, 0)) do
      [_, tail] = children
      translate_brancket_sub("#{Atom.to_string(t)}\\((?:init|mid|fin|sol|null)", tail)
    end

    translate_brancket_sub("#{Atom.to_string(t)}\\(", children)
  end

  def translate_sub(%AST{type: t, children: children})
      when t in [:C, :Cd] do
    if AST.has_astarisk_for_form?(Enum.at(children, 0)) do
      [_, tail] = children
      translate_brancket_sub("#{Atom.to_string(t)}\\((?:onset|coda|null)", tail)
    end

    translate_brancket_sub("#{Atom.to_string(t)}\\(", children)
  end

  def translate_sub(%AST{type: :L, children: children}),
    do: convert("(:?S(*)|V(*)|C(*)|P(*)|Vd(*)|Cd(*)|Pd(*))")

  def translate_sub(%AST{type: :R, value: val}),
    do: "R\\(#{val}\\)"

  def translate_sub(%AST{type: t, children: children})
      when t in [:P, :Pd, :X],
      do: translate_brancket_sub("#{Atom.to_string(t)}\\(", children)

  def translate_brancket_sub(val, children),
    do: val <> Enum.map_join(children, "", &translate_sub/1) <> "\\)"

  # 処理がやや複雑
  def translate_sub(%AST{type: :token, value: val, layer: :glyph}) do
    case val do
      # 全てのvariant
      "_" -> "(?:\\d+)"
      # 任意のglyph
      "." -> "(?:[A-Za-z]+\\d+)"
      # 0グリフ以上
      "*" -> "(?:|(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*))"
      # 1グリフ以上
      "+" -> "(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*)"
      # 0 or 1グリフ
      "?" -> "(?:(?:[A-Za-z]+\\d+)?)"
      # 0グリフ以上
      "*?" -> "(?:|(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*?))"
      # 1グリフ以上
      "+?" -> "(?:(?:[A-Za-z]+\\d+)(?:\-[A-Za-z]+\\d+)*?)"
      # 0 or 1グリフ
      "??" -> "(?:(?:[A-Za-z]+\\d+)??)"
      # 0グリフ以上
      "-*" -> "(?:(?:\-[A-Za-z]+\\d+)*)"
      # 1グリフ以上
      "-+" -> "(?:(?:\-[A-Za-z]+\\d+)+)"
      # 0 or 1グリフ
      "-?" -> "(?:(?:\-[A-Za-z]+\\d+)?)"
      # 0グリフ以上
      "-*?" -> "(?:(?:\-[A-Za-z]+\\d+)*?)"
      # 1グリフ以上
      "-+?" -> "(?:(?:\-[A-Za-z]+\\d+)+?)"
      # 0 or 1グリフ
      "-??" -> "(?:(?:\-[A-Za-z]+\\d+)??)"
    end
  end

  def translate_sub(%AST{children: children}),
    do: Enum.map_join(children, "", &translate_sub/1)

  def normalize(list) when is_list(list), do: normalize_sub(list, [], :sentence)

  def normalize_sub([], acum_all, _), do: Enum.reverse(acum_all)

  # S()系統→Glyph群→Glyphの順に分解。

  # 1層目
  def normalize_sub(list, acum_all, :sentence = current_layer) when is_list(list) do
    [head | tail] = list
    next_layer = :syllable

    case head do
      # S(*),S(form,*) のようなものも実装したい

      h when h in ["S", "V", "C", "Cd", "Vd", "P", "Pd", "L", "X", "R"] ->
        normalize_branckets(:"#{h}", nil, acum_all, tail, next_layer, current_layer)

      # Rは別処理とする

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

      h when h in ["^", "$", "*", "+", "?", "|", "*?", "+?", "??"] ->
        normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)

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
            normalize_sub(tail, [AST.new(:finite, head) | acum_all], current_layer)

          true ->
            normalize_sub(tail, [AST.new(:finite, head) | acum_all], current_layer)
        end
    end
  end

  # 2層目
  def normalize_sub(list, acum_all, :syllable = current_layer) when is_list(list) do
    [head | tail] = list

    _next_layer = :glyph_group

    case head do
      # 形状指定用
      h when h in ["init", "mid", "fin", "sol", "onset", "coda", "null"] ->
        normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

      "," ->
        normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)

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
            raise "Quantifier {...} is not supported in glyph group layer."

          true ->
            # next_layer。(:glyphの場合は未実装)
            # normalize_glpyh_groupを作る。,か末端までをグループとして扱う。
            normalize_glyph_group(
              acum_all,
              list
            )
        end
    end
  end

  # 3層目
  def normalize_sub(list, acum_all, :glyph_group = current_layer) when is_list(list) do
    [head | tail] = list

    next_layer = :glyph

    case head do
      # 形状指定用

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

      "-" ->
        normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)

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
            normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)

          true ->
            # next_layer。(:glyphの場合は未実装)
            normalize_sub(list, [AST.new(:glyph, current_layer, nil) | acum_all], next_layer)
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
          [AST.new(:token, current_layer, head) | acum_all],
          current_layer
        )

      h when h in ["*", "+", "?", "*?", "+?", "??", "_", "."] ->
        normalize_sub(
          tail,
          [AST.new(:token, current_layer, head) | acum_all],
          current_layer
        )

      h when h in ["(?:", "(", "(?=", "(?<=", "(?!", "(?<!"] ->
        name = String.slice(head, 1..-1//1)
        normalize_branckets(:brancket, name, acum_all, tail, current_layer, current_layer, 1)

      ")" ->
        raise "unclosed Branket found: )"

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
            script = String.slice(head, 1..-1//1)

            normalize_sub(
              tail,
              [AST.new(:script, current_layer, script) | acum_all],
              current_layer
            )

          true ->
            normalize_sub(tail, [AST.new(:finite, current_layer, head) | acum_all], current_layer)
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
         acum_all,
         list,
         next_layer,
         current_layer,
         branket_nest,
         acum
       )
       when is_list(list) do
    if list == [], do: raise("unclosed Branket found: (")

    [head | tail] = list

    case head do
      "(" ->
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

      ")" ->
        if branket_nest == 1 do
          if token == :R do
            text = Enum.reverse(acum) |> Enum.join("")

            normalize_sub(
              tail,
              [AST.new(token, current_layer, text, []) | acum_all],
              current_layer
            )
          else
            children = normalize_sub(Enum.reverse(acum), [], next_layer)

            normalize_sub(
              tail,
              [AST.new(token, current_layer, br_val, children) | acum_all],
              current_layer
            )
          end

          children = normalize_sub(Enum.reverse(acum), [], next_layer)

          normalize_sub(
            tail,
            [AST.new(token, current_layer, br_val, children) | acum_all],
            current_layer
          )
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
         [] = _list,
         acum
       ) do
    children = normalize_sub(Enum.reverse(acum), [], :glyph_group)

    normalize_sub(
      [],
      [AST.new(:glyph_group, :syllable, :glyph_group, children) | acum_all],
      :syllable
    )
  end

  defp normalize_glyph_group(
         acum_all,
         list,
         acum \\ []
       )
       when is_list(list) do
    [head | tail] = list

    case head do
      "," ->
        children = normalize_sub(Enum.reverse(acum), [], :glyph_group)

        normalize_sub(
          list,
          [AST.new(:glyph_group, :syllable, :glyph_group, children) | acum_all],
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

  def tokenize(string) when is_binary(string) do
    String.split(
      string,
      ~r/(\[.*?\]|(\(\?<?[=!])|(\(\?(:|<.*?>))|
      ((\{\\d+(,(\\d+)?)?\})\??)|(\-?(\+|\*|\?)\??)|[\(\)\-\,\|])/,
      include_captures: true
    )
    |> Enum.filter(fn x -> x != "" end)
  end
end
